import 'package:provider/provider.dart';
import 'package:photo_studio_portal/state/session.dart';
import 'package:photo_studio_portal/state/catalog_notifier.dart';
import 'package:photo_studio_portal/state/catalog_notifiers.dart';
import 'package:photo_studio_portal/state/list_notifiers.dart';
import 'package:photo_studio_portal/repositories/hall_repository.dart';
import 'package:photo_studio_portal/repositories/photographer_repository.dart';
import 'package:photo_studio_portal/repositories/booking_repository.dart';
import 'package:photo_studio_portal/repositories/client_repository.dart';
import 'package:photo_studio_portal/repositories/equipment_repository.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_studio_portal/core/errors.dart';
import 'package:photo_studio_portal/core/router.dart' as routing;
import 'package:photo_studio_portal/core/storage.dart';
import 'package:photo_studio_portal/core/validators.dart';
import 'package:photo_studio_portal/main.dart' as app;
import 'package:photo_studio_portal/models/booking.dart';
import 'package:photo_studio_portal/models/client.dart';
import 'package:photo_studio_portal/models/equipment.dart';
import 'package:photo_studio_portal/models/photographer.dart';
import 'package:photo_studio_portal/models/studio_hall.dart';
import 'package:photo_studio_portal/repositories/in_memory_hall_repository.dart';
import 'package:photo_studio_portal/repositories/in_memory_photographer_repository.dart';
import 'package:photo_studio_portal/repositories/persistent_booking_repository.dart';
import 'package:photo_studio_portal/repositories/photo_studio_repositories.dart';
import 'package:photo_studio_portal/widgets/dirty_guard.dart';
import 'package:photo_studio_portal/widgets/entity_form.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<SharedPreferences> prefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  test('дата должна существовать и точно соответствовать ГГГГ-ММ-ДД', () {
    for (final text in [
      '2026-02-30',
      '2026-13-01',
      '20260201',
      '2026-02-01T12:00:00',
      '0000-01-01'
    ]) {
      expect(V.date()(text), isNotNull, reason: text);
    }
    expect(V.date()('2028-02-29'), isNull);
  });
  test('начальные бронирования согласованы с залами и фотографами', () async {
    final r = PhotoStudioRepositories(await prefs());
    for (final booking in r.bookings.items) {
      await r.bookings.saveGuard!(booking);
    }
  });
  test('все пять моделей читают отсутствующие и null-поля', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {'id': null, 'deletedAt': null}
    ]) {
      final rows = [
        Booking.fromJson(json).toJson(),
        Client.fromJson(json).toJson(),
        Equipment.fromJson(json).toJson(),
        Photographer.fromJson(json).toJson(),
        StudioHall.fromJson(json).toJson()
      ];
      expect(rows.every((row) => row['id'] == 0 && row['deletedAt'] == null),
          isTrue);
    }
  });
  test('массовое удаление связанных залов запрещено до первой мутации',
      () async {
    final repositories = PhotoStudioRepositories(await prefs());
    final empty = await repositories.halls.save(const StudioHall(
        id: 0,
        name: 'Свободный',
        code: 'FREE',
        style: 'Лофт',
        capacity: 10,
        hourlyRate: 2000));
    await expectLater(
        repositories.halls.softDeleteMany([empty.id, 1]),
        throwsA(isA<LinkedRecordsException>()
            .having((e) => e.count, 'count', greaterThan(0))));
    expect((await repositories.halls.findById(empty.id))!.isDeleted, isFalse);
    await expectLater(repositories.halls.hardDeleteMany([empty.id, 1]),
        throwsA(isA<LinkedRecordsException>()));
    expect(await repositories.halls.findById(empty.id), isNotNull);
  });
  test('физическое удаление учитывает и логически удалённые бронирования',
      () async {
    final r = PhotoStudioRepositories(await prefs());
    final booking = r.bookings.items.first;
    for (final b
        in r.bookings.items.where((b) => b.clientId == booking.clientId)) {
      await r.bookings.softDelete(b.id);
    }
    await expectLater(r.clients.hardDeleteMany([booking.clientId]),
        throwsA(isA<LinkedRecordsException>()));
  });
  test('обратные ссылки брони сохраняются даже вне контейнера приложения',
      () async {
    final storage = await prefs();
    final halls = InMemoryHallRepository(storage);
    final photographers = InMemoryPhotographerRepository(storage);
    final bookings = PersistentBookingRepository(storage,
        halls: halls, photographers: photographers);
    final saved = await bookings.save(Booking(
        id: 0,
        clientName: 'Тест',
        email: 'test@mail.ru',
        accessCode: 'LINK-TEST',
        hallId: 1,
        photographerIds: [1],
        date: DateTime(2027),
        durationHours: 2,
        participants: 1,
        shootingType: 'Портретная'));
    expect((await InMemoryHallRepository(storage).findById(1))!.bookingIds,
        contains(saved.id));
    expect(
        (await InMemoryPhotographerRepository(storage).findById(1))!.bookingIds,
        contains(saved.id));
    await bookings.hardDelete(saved.id);
    expect((await InMemoryHallRepository(storage).findById(1))!.bookingIds,
        isNot(contains(saved.id)));
  });
  test('перенос оборудования обновляет обе стороны связи после перезагрузки',
      () async {
    final storage = await prefs();
    final r = PhotoStudioRepositories(storage);
    await r.synchronizeLinks();
    final source = r.equipment.items.first;
    final target = r.halls.items.firstWhere((h) => h.id != source.hallId);
    await r.equipment.save(source.copyWith(hallId: target.id));
    final reopened = InMemoryHallRepository(storage);
    expect((await reopened.findById(source.hallId))!.equipmentIds,
        isNot(contains(source.id)));
    expect((await reopened.findById(target.id))!.equipmentIds,
        contains(source.id));
  });
  test('восстановление не создаёт дубликат уникального кода', () async {
    final r = InMemoryHallRepository(await prefs());
    final old = r.items.first;
    await r.softDelete(old.id);
    await r.save(StudioHall(
        id: 0,
        name: 'Новый',
        code: old.code,
        style: old.style,
        capacity: 5,
        hourlyRate: 1000));
    await expectLater(
        r.restore(old.id), throwsA(isA<FieldValidationException>()));
    expect((await r.findById(old.id))!.isDeleted, isTrue);
  });
  testWidgets('множественный выбор и каскадный сброс участвуют в validate',
      (tester) async {
    final formKey = GlobalKey<FormState>();
    final entityKey = GlobalKey<EntityFormState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EntityForm(
                key: entityKey,
                formKey: formKey,
                fields: [
                  FieldSpec(
                      name: 'ids',
                      label: 'Фотографы',
                      type: FieldType.multiselect,
                      options: const [DropdownEntry(1, 'Анна')],
                      validators: [V.notEmptySelection()])
                ],
                onSubmit: () {},
                onCancel: () {}))));
    expect(formKey.currentState!.validate(), isFalse);
    await tester.tap(find.text('Анна'));
    await tester.pumpAndSettle();
    expect(formKey.currentState!.validate(), isTrue);
    entityKey.currentState!.setValue('ids', <int>[]);
    await tester.pump();
    expect(formKey.currentState!.validate(), isFalse);
  });
  testWidgets('исправление уникального значения снимает ошибку поля',
      (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EntityForm(
                formKey: formKey,
                fields: [
                  FieldSpec(
                      name: 'email',
                      label: 'Email',
                      initialValue: 'busy@mail.ru',
                      serverError: 'Почта занята',
                      validators: [V.email()])
                ],
                onSubmit: () {},
                onCancel: () {}))));
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Почта занята'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'free@mail.ru');
    await tester.pumpAndSettle();
    expect(formKey.currentState!.validate(), isTrue);
    expect(find.text('Почта занята'), findsNothing);
  });
  testWidgets('Отмена и переход GoRouter предупреждают о потере ввода',
      (tester) async {
    var dirty = false;
    final router = GoRouter(initialLocation: '/form', routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: Text('Список'))),
      GoRoute(
          path: '/form',
          onExit: (_, __) => DirtyGuard.mayLeave(),
          builder: (context, _) => StatefulBuilder(
              builder: (context, setState) => DirtyGuard(
                  isDirty: () => dirty,
                  fallbackLocation: '/',
                  child: Scaffold(
                      body: Column(children: [
                    TextField(onChanged: (_) => setState(() => dirty = true)),
                    TextButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Отмена')),
                  ]))))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(find.byType(TextField), 'Несохранённое');
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Есть несохранённые изменения'), findsOneWidget);
    await tester.tap(find.text('Остаться'));
    await tester.pumpAndSettle();
    expect(find.text('Несохранённое'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти без сохранения'));
    await tester.pumpAndSettle();
    expect(find.text('Список'), findsOneWidget);
  });
  testWidgets('миграция при запуске сразу показывает уведомление',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'focus_frame_halls_v1': jsonEncode([
        {'id': 1, 'name': 'Старый зал'}
      ])
    });
    final preferences = await SharedPreferences.getInstance();
    final repos = PhotoStudioRepositories(preferences);
    final session = SessionStore()
      ..setUser(const AppUser(
          id: 1,
          username: 'admin',
          fullName: 'Администратор',
          email: '',
          role: 'admin'));
    final router = routing.createRouter(session);
    addTearDown(router.dispose);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: session),
          Provider<HallRepository>.value(value: repos.halls),
          Provider<PhotographerRepository>.value(value: repos.photographers),
          Provider<BookingRepository>.value(value: repos.bookings),
          Provider<ClientRepository>.value(value: repos.clients),
          Provider<EquipmentRepository>.value(value: repos.equipment),
          ChangeNotifierProvider(create: (_) => HallListNotifier(repos.halls)),
          ChangeNotifierProvider(
              create: (_) => PhotographerListNotifier(repos.photographers)),
          ChangeNotifierProvider(
              create: (_) => BookingListNotifier(repos.bookings)),
          ChangeNotifierProvider(
              create: (_) => ClientListNotifier(repos.clients)),
          ChangeNotifierProvider(
              create: (_) => EquipmentListNotifier(repos.equipment)),
          ChangeNotifierProvider(
              create: (_) => CatalogNotifier(
                  halls: repos.halls,
                  photographers: repos.photographers,
                  clients: repos.clients,
                  bookings: repos.bookings,
                  equipment: repos.equipment)
                ..load()),
        ],
        child: app.PhotoStudioApp(
            router: router, notice: VersionedStore.takeNotice(preferences))));
    await tester.pumpAndSettle();
    expect(find.textContaining('обновлены с версии 1'), findsOneWidget);
    expect(VersionedStore.currentVersion, 3);
    // Exercise the actual router, providers, lists, forms and detail pages.
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetDevicePixelRatio());
    addTearDown(() => tester.view.resetPhysicalSize());
    for (final collection in [
      'halls',
      'photographers',
      'clients',
      'equipment',
      'bookings'
    ]) {
      for (final suffix in [
        '',
        '/new',
        '/1/edit',
        '/1',
        '/999999/edit',
        '/999999'
      ]) {
        router.go('/$collection$suffix');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '/$collection$suffix');
      }
    }
    router.go('/halls?style=unknown');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    router.go('/clients?sort=cardExpiresAt,asc');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
