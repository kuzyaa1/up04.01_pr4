import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_studio_portal/models/client.dart';
import 'package:photo_studio_portal/models/studio_hall.dart';
import 'package:photo_studio_portal/models/hall_query.dart';
import 'package:photo_studio_portal/repositories/in_memory_hall_repository.dart';
import 'package:photo_studio_portal/repositories/in_memory_photographer_repository.dart';
import 'package:photo_studio_portal/screens/client_form_screen.dart';
import 'package:photo_studio_portal/screens/hall_form_screen.dart';
import 'package:photo_studio_portal/state/catalog_notifier.dart';
import 'package:photo_studio_portal/repositories/booking_repository.dart';
import 'package:photo_studio_portal/repositories/hall_repository.dart';
import 'package:photo_studio_portal/repositories/photographer_repository.dart';
import 'package:photo_studio_portal/repositories/persistent_booking_repository.dart';
import 'package:photo_studio_portal/repositories/client_repository.dart';
import 'package:photo_studio_portal/repositories/in_memory_client_repository.dart';
import 'package:photo_studio_portal/repositories/equipment_repository.dart';
import 'package:photo_studio_portal/repositories/in_memory_equipment_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> harness(WidgetTester tester, Widget child,
      {required ClientRepository clients,
      required HallRepository halls,
      required PhotographerRepository photographers,
      required EquipmentRepository equipment,
      required BookingRepository bookings}) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ClientRepository>.value(value: clients),
        Provider<HallRepository>.value(value: halls),
        Provider<PhotographerRepository>.value(value: photographers),
        Provider<EquipmentRepository>.value(value: equipment),
        Provider<BookingRepository>.value(value: bookings),
        ChangeNotifierProvider<CatalogNotifier>(
          create: (_) => CatalogNotifier(
            halls: halls,
            photographers: photographers,
            clients: clients,
            bookings: bookings,
            equipment: equipment,
          )..load(),
        ),
      ],
      child: MaterialApp(home: child),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('форма зала показывает ошибки под полями, а не общим текстом',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final halls = InMemoryHallRepository(prefs);
    await harness(tester, const HallFormScreen(),
        clients: ClientRepositoryImpl(prefs),
        halls: halls,
        photographers: InMemoryPhotographerRepository(prefs),
        equipment: EquipmentRepositoryImpl(prefs),
        bookings: PersistentBookingRepository(prefs));
    await tester.tap(find.text('Создать зал'));
    await tester.pumpAndSettle();
    expect(find.text('Поле обязательно'), findsWidgets);
    expect(find.text('Поле обязательно'), findsNWidgets(3));
  });
  testWidgets('пустое обязательное поле блокирует сохранение', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final halls = InMemoryHallRepository(prefs);
    await harness(tester, const HallFormScreen(),
        clients: ClientRepositoryImpl(prefs),
        halls: halls,
        photographers: InMemoryPhotographerRepository(prefs),
        equipment: EquipmentRepositoryImpl(prefs),
        bookings: PersistentBookingRepository(prefs));
    final before = (await halls.find(const HallQuery(size: 50))).total;
    await tester.tap(find.text('Создать зал'));
    await tester.pumpAndSettle();
    final after = (await halls.find(const HallQuery(size: 50))).total;
    expect(after, before);
  });
  testWidgets(
      'ограничение длины строки срабатывает на слишком длинном значении',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await harness(tester, const HallFormScreen(),
        clients: ClientRepositoryImpl(prefs),
        halls: InMemoryHallRepository(prefs),
        photographers: InMemoryPhotographerRepository(prefs),
        equipment: EquipmentRepositoryImpl(prefs),
        bookings: PersistentBookingRepository(prefs));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Название зала'), 'A' * 200);
    await tester.pumpAndSettle();
    expect(find.text('Максимум символов: 80'), findsOneWidget);
  });
  testWidgets('форма клиента выводит ошибку уникальности под полем почты',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final clients = ClientRepositoryImpl(prefs);
    await clients.save(const Client(
      id: 0,
      name: 'Занятый клиент',
      email: 'busy@mail.ru',
      phone: '+7 900 111-22-33',
      cardNumber: 'CARD-9',
      cardIssuedAt: '2026-01-01',
    ));
    await harness(tester, const ClientFormScreen(),
        clients: clients,
        halls: InMemoryHallRepository(prefs),
        photographers: InMemoryPhotographerRepository(prefs),
        equipment: EquipmentRepositoryImpl(prefs),
        bookings: PersistentBookingRepository(prefs));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Имя клиента'), 'Новый клиент');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email для связи'), 'busy@mail.ru');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Телефон'), '+7 900 555-66-77');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Номер абонемента'), 'AB-0010');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Дата выдачи (ГГГГ-ММ-ДД)'),
        '2026-03-03');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Создать клиента'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать клиента'));
    await tester.pumpAndSettle();
    expect(find.text('Клиент с таким адресом почты уже есть'), findsOneWidget);
  });
  testWidgets('форма клиента содержит вложенную группу абонемента',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await harness(tester, const ClientFormScreen(),
        clients: ClientRepositoryImpl(prefs),
        halls: InMemoryHallRepository(prefs),
        photographers: InMemoryPhotographerRepository(prefs),
        equipment: EquipmentRepositoryImpl(prefs),
        bookings: PersistentBookingRepository(prefs));
    expect(find.text('Абонемент'), findsOneWidget);
    expect(
        find.widgetWithText(TextFormField, 'Номер абонемента'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Дата выдачи (ГГГГ-ММ-ДД)'),
        findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Действует до (ГГГГ-ММ-ДД)'),
        findsOneWidget);
  });
  testWidgets('поле «Компания» появляется только для корпоративных клиентов',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await harness(tester, const ClientFormScreen(),
        clients: ClientRepositoryImpl(prefs),
        halls: InMemoryHallRepository(prefs),
        photographers: InMemoryPhotographerRepository(prefs),
        equipment: EquipmentRepositoryImpl(prefs),
        bookings: PersistentBookingRepository(prefs));
    expect(find.widgetWithText(TextFormField, 'Компания'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Корпоративный').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Компания'), findsOneWidget);
  });
  testWidgets('форма зала показывает подсказку со стилями из репозитория',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await harness(tester, const HallFormScreen(),
        clients: ClientRepositoryImpl(prefs),
        halls: InMemoryHallRepository(prefs),
        photographers: InMemoryPhotographerRepository(prefs),
        equipment: EquipmentRepositoryImpl(prefs),
        bookings: PersistentBookingRepository(prefs));
    final hall = StudioHall.fromJson(const {});
    expect(hall.bookingIds, isEmpty);
    expect(find.text('Стиль съёмки'), findsOneWidget);
  });
}
