import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_studio_portal/core/errors.dart';
import 'package:photo_studio_portal/core/storage.dart';
import 'package:photo_studio_portal/core/validators.dart';
import 'package:photo_studio_portal/models/booking.dart';
import 'package:photo_studio_portal/models/booking_query.dart';
import 'package:photo_studio_portal/models/client.dart';
import 'package:photo_studio_portal/models/client_query.dart';
import 'package:photo_studio_portal/models/equipment_query.dart';
import 'package:photo_studio_portal/models/hall_query.dart';
import 'package:photo_studio_portal/models/photographer_query.dart';
import 'package:photo_studio_portal/models/studio_hall.dart';
import 'package:photo_studio_portal/repositories/in_memory_client_repository.dart';
import 'package:photo_studio_portal/repositories/in_memory_equipment_repository.dart';
import 'package:photo_studio_portal/repositories/in_memory_hall_repository.dart';
import 'package:photo_studio_portal/repositories/in_memory_photographer_repository.dart';
import 'package:photo_studio_portal/repositories/persistent_booking_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  group('залы', () {
    test('выборка разбивается на страницы', () async {
      final result =
          await InMemoryHallRepository(await _prefs()).find(const HallQuery());
      expect(result.items, hasLength(10));
      expect(result.total, greaterThanOrEqualTo(20));
      expect(result.totalPages, greaterThan(1));
    });
    test('фильтр по стилю возвращает только подходящие залы', () async {
      final result = await InMemoryHallRepository(await _prefs())
          .find(const HallQuery(style: 'Лофт', size: 50));
      expect(result.items, isNotEmpty);
      expect(result.items.every((hall) => hall.style == 'Лофт'), isTrue);
    });
    test('логическое удаление скрывает зал, физическое убирает', () async {
      final repository = InMemoryHallRepository(await _prefs());
      final id =
          (await repository.find(const HallQuery(size: 50))).items.first.id;
      await repository.softDelete(id);
      expect(
          (await repository.find(const HallQuery(size: 50)))
              .items
              .any((hall) => hall.id == id),
          isFalse);
      expect(
          (await repository
                  .find(const HallQuery(size: 50, includeDeleted: true)))
              .items
              .any((hall) => hall.id == id),
          isTrue);
      await repository.restore(id);
      expect(
          (await repository.find(const HallQuery(size: 50)))
              .items
              .any((hall) => hall.id == id),
          isTrue);
      await repository.hardDelete(id);
      expect(
          (await repository
                  .find(const HallQuery(size: 50, includeDeleted: true)))
              .items
              .any((hall) => hall.id == id),
          isFalse);
    });
    test('повторяющийся код зала отклоняется с ошибкой поля', () async {
      final repository = InMemoryHallRepository(await _prefs());
      final halls = (await repository.find(const HallQuery(size: 50))).items;
      expect(
          () => repository.save(StudioHall(
                id: 0,
                name: 'Дубль кода',
                code: halls.first.code,
                style: 'Лофт',
                capacity: 4,
                hourlyRate: 1000,
              )),
          throwsA(isA<FieldValidationException>()
              .having((e) => e.field, 'field', 'code')));
    });
  });
  group('фотографы', () {
    test('поиск выполняется по специализации без учёта регистра', () async {
      final result = await InMemoryPhotographerRepository(await _prefs())
          .find(const PhotographerQuery(search: 'fashion'));
      expect(result.items, isNotEmpty);
      expect(
          result.items.every((person) =>
              person.specialization.toLowerCase().contains('fashion')),
          isTrue);
    });
    test('фильтр по залу ограничивает выборку', () async {
      final repository = InMemoryPhotographerRepository(await _prefs());
      final all =
          (await repository.find(const PhotographerQuery(size: 100))).items;
      final withHalls = all.where((item) => item.hallIds.isNotEmpty).toList();
      expect(withHalls, isNotEmpty);
      final hallId = withHalls.first.hallIds.first;
      final filtered =
          (await repository.find(PhotographerQuery(hallId: hallId, size: 100)))
              .items;
      expect(filtered.every((item) => item.hallIds.contains(hallId)), isTrue);
    });
  });
  group('бронирования', () {
    test('поиск по коду и фильтр по залу работают', () async {
      final repository = PersistentBookingRepository(await _prefs());
      final all = (await repository.find(const BookingQuery(size: 100))).items;
      expect(all, isNotEmpty);
      final byCode = (await repository
              .find(BookingQuery(search: all.first.accessCode, size: 100)))
          .items;
      expect(byCode, isNotEmpty);
      final hallId = all.first.hallId;
      final byHall =
          (await repository.find(BookingQuery(hallId: hallId, size: 100)))
              .items;
      expect(byHall.every((item) => item.hallId == hallId), isTrue);
    });
    test('повторяющийся код брони отклоняется с ошибкой поля', () async {
      final repository = PersistentBookingRepository(await _prefs());
      final existing =
          (await repository.find(const BookingQuery(size: 100))).items.first;
      expect(
          () => repository.save(Booking(
                id: 0,
                clientName: 'Дубль кода',
                email: 'test@mail.ru',
                accessCode: existing.accessCode,
                hallId: existing.hallId,
                date: DateTime(2026, 6, 1),
                durationHours: 2,
                participants: 1,
                shootingType: 'Портретная',
              )),
          throwsA(isA<FieldValidationException>()
              .having((e) => e.field, 'field', 'accessCode')));
    });
    test('сохранение брони связывает его с залом и фотографом', () async {
      final halls = InMemoryHallRepository(await _prefs());
      final photographers = InMemoryPhotographerRepository(await _prefs());
      final repository = PersistentBookingRepository(
        await _prefs(),
        halls: halls,
        photographers: photographers,
      );
      final hall = (await halls.find(const HallQuery(size: 50))).items.first;
      final person =
          (await photographers.find(const PhotographerQuery(size: 50)))
              .items
              .first;
      final saved = await repository.save(Booking(
        id: 0,
        clientName: 'Новое бронирование',
        email: 'new@mail.ru',
        accessCode: 'NEW-CODE-01',
        hallId: hall.id,
        photographerIds: [person.id],
        date: DateTime(2026, 8, 1),
        durationHours: 2,
        participants: 2,
        shootingType: 'Портретная',
      ));
      final updatedHall = await halls.findById(hall.id);
      expect(updatedHall!.bookingIds, contains(saved.id));
      final updatedPerson = await photographers.findById(person.id);
      expect(updatedPerson!.bookingIds, contains(saved.id));
    });
    test('удаление брони освобождает ссылки на зал и фотографа', () async {
      final halls = InMemoryHallRepository(await _prefs());
      final photographers = InMemoryPhotographerRepository(await _prefs());
      final repository = PersistentBookingRepository(
        await _prefs(),
        halls: halls,
        photographers: photographers,
      );
      final existing =
          (await repository.find(const BookingQuery(size: 100))).items.first;
      expect(halls.findById(existing.hallId).then((h) => h!.bookingIds),
          completion(contains(existing.id)));
      await repository.hardDelete(existing.id);
      final hall = await halls.findById(existing.hallId);
      expect(hall!.bookingIds.contains(existing.id), isFalse);
      for (final id in existing.photographerIds) {
        final person = await photographers.findById(id);
        expect(person!.bookingIds.contains(existing.id), isFalse);
      }
    });
  });
  group('клиенты', () {
    test('повторяющийся адрес почты отклоняется с ошибкой поля', () async {
      final repository = ClientRepositoryImpl(await _prefs());
      await repository.save(const Client(
        id: 0,
        name: 'Первый клиент',
        email: 'unique@mail.ru',
        phone: '+7 900 000-00-01',
        cardNumber: 'CARD-1',
        cardIssuedAt: '2026-01-15',
      ));
      expect(
          () => repository.save(const Client(
                id: 0,
                name: 'Второй клиент',
                email: 'UNIQUE@mail.ru',
                phone: '+7 900 000-00-02',
                cardNumber: 'CARD-2',
                cardIssuedAt: '2026-02-20',
              )),
          throwsA(isA<FieldValidationException>()
              .having((e) => e.field, 'field', 'email')));
    });
    test('фильтр по типу клиента ограничивает выборку', () async {
      final repository = ClientRepositoryImpl(await _prefs());
      await repository.save(const Client(
        id: 0,
        name: 'Частный клиент',
        email: 'private@mail.ru',
        phone: '+7 900 000-00-11',
        clientType: 'Частный',
        cardNumber: 'AB-1',
        cardIssuedAt: '2026-01-10',
      ));
      await repository.save(const Client(
        id: 0,
        name: 'Корпоративный клиент',
        email: 'corp@mail.ru',
        phone: '+7 900 000-00-12',
        clientType: 'Корпоративный',
        company: 'ООО Ромашка',
        cardNumber: 'AB-2',
        cardIssuedAt: '2026-02-10',
      ));
      final corporate = (await repository
              .find(const ClientQuery(clientType: 'Корпоративный')))
          .items;
      expect(corporate, isNotEmpty);
      expect(corporate.every((item) => item.clientType == 'Корпоративный'),
          isTrue);
    });
    test('компания клиента сохраняется и читается обратно', () async {
      final repository = ClientRepositoryImpl(await _prefs());
      final saved = await repository.save(const Client(
        id: 0,
        name: 'Фирменный клиент',
        email: 'firm@mail.ru',
        phone: '+7 900 000-00-13',
        clientType: 'Корпоративный',
        company: 'ООО Ромашка',
        cardNumber: 'AB-3',
        cardIssuedAt: '2026-03-01',
        cardExpiresAt: '2027-03-01',
        notes: 'Съёмки каталога раз в квартал',
      ));
      final restored = await repository.findById(saved.id);
      expect(restored!.company, 'ООО Ромашка');
      expect(restored.notes, 'Съёмки каталога раз в квартал');
      expect(restored.cardExpiresAt, '2027-03-01');
    });
    test('абонемент хранится в cardNumber и участвует в поиске', () async {
      final repository = ClientRepositoryImpl(await _prefs());
      await repository.save(const Client(
        id: 0,
        name: 'Клиент с абонементом',
        email: 'sub@mail.ru',
        phone: '+7 900 000-00-14',
        cardNumber: 'AB-NEW-0001',
        cardIssuedAt: '2026-04-01',
      ));
      final found = (await repository
              .find(const ClientQuery(search: 'AB-NEW-0001', size: 50)))
          .items;
      expect(found, isNotEmpty);
      expect(found.first.email, 'sub@mail.ru');
    });
    test('поле «абонемент» используется как фильтр', () async {
      final repository = ClientRepositoryImpl(await _prefs());
      await repository.save(const Client(
        id: 0,
        name: 'С абонементом',
        email: 'a@mail.ru',
        phone: '+7 900 000-00-15',
        cardNumber: 'AB-100',
        cardIssuedAt: '2026-05-01',
      ));
      final withCard =
          (await repository.find(const ClientQuery(hasCard: true))).items;
      final withoutCard =
          (await repository.find(const ClientQuery(hasCard: false))).items;
      expect(withCard.length + withoutCard.length, greaterThanOrEqualTo(1));
      expect(withCard.every((item) => item.cardNumber.isNotEmpty), isTrue);
    });
    test('сортировка по сроку абонемента работает', () async {
      final repository = ClientRepositoryImpl(await _prefs());
      await repository.save(const Client(
        id: 0,
        name: 'Поздний',
        email: 'late@mail.ru',
        phone: '+7 900 000-00-16',
        cardNumber: 'AB-200',
        cardIssuedAt: '2026-01-01',
        cardExpiresAt: '2027-12-31',
      ));
      await repository.save(const Client(
        id: 0,
        name: 'Ранний',
        email: 'early@mail.ru',
        phone: '+7 900 000-00-17',
        cardNumber: 'AB-201',
        cardIssuedAt: '2026-01-01',
        cardExpiresAt: '2026-06-30',
      ));
      final result = await repository.find(
          const ClientQuery(sortField: 'cardExpiresAt', sortAscending: true));
      expect(result.items.first.name, 'Ранний');
    });
  });
  group('оборудование', () {
    test('фильтр по залу возвращает только его оборудование', () async {
      final repository = EquipmentRepositoryImpl(await _prefs());
      final all =
          (await repository.find(const EquipmentQuery(size: 100))).items;
      expect(all, isNotEmpty);
      final hallId = all.first.hallId;
      final filtered =
          (await repository.find(EquipmentQuery(hallId: hallId, size: 100)))
              .items;
      expect(filtered.every((item) => item.hallId == hallId), isTrue);
    });
  });
  group('сохранение между перезагрузками', () {
    test('начальный набор записывается в хранилище сразу', () async {
      final prefs = await _prefs();
      expect(
          prefs
              .getString('focus_frame_halls_v${VersionedStore.currentVersion}'),
          isNull);
      InMemoryHallRepository(prefs);
      expect(
          prefs
              .getString('focus_frame_halls_v${VersionedStore.currentVersion}'),
          isNotNull);
    });
    test('изменения переживают создание нового репозитория', () async {
      final prefs = await _prefs();
      final repository = InMemoryHallRepository(prefs);
      final hall =
          (await repository.find(const HallQuery(size: 50))).items.first;
      await repository.save(hall.copyWith(name: 'Переименованный зал'));
      final reopened = InMemoryHallRepository(prefs);
      final restored = await reopened.findById(hall.id);
      expect(restored!.name, 'Переименованный зал');
    });
    test('старый формат данных мигрируется без падения', () async {
      SharedPreferences.setMockInitialValues({
        'focus_frame_halls_v1': jsonEncode([
          {
            'id': 1,
            'name': 'Старый зал',
            'code': 'OLD-1',
            'style': 'Лофт',
            'capacity': 5,
            'hourlyRate': 1000,
            'equipmentIds': [1],
          }
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = InMemoryHallRepository(prefs);
      final hall = await repository.findById(1);
      expect(hall, isNotNull);
      expect(hall!.name, 'Старый зал');
      expect(hall.bookingIds, isEmpty);
      expect(VersionedStore.takeNotice(prefs), isNotNull);
      expect(VersionedStore.takeNotice(prefs), isNull);
    });
    test('после миграции данные лежат под ключом текущей версии', () async {
      SharedPreferences.setMockInitialValues({
        'focus_frame_halls_v1': jsonEncode([
          {'id': 1, 'name': 'Старый зал', 'code': 'OLD-1'},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      const currentVersion = VersionedStore.currentVersion;
      InMemoryHallRepository(prefs);
      expect(prefs.getString('focus_frame_halls_v1'), isNull);
      final current = prefs.getString('focus_frame_halls_v$currentVersion');
      expect(current, isNotNull);
      final decoded = jsonDecode(current!);
      expect(decoded, isA<List<dynamic>>());
      expect((decoded as List).length, 1);
      expect((decoded.first as Map)['name'], 'Старый зал');
      expect((decoded.first as Map).containsKey('bookingIds'), isTrue);
    });
    test('данные не перезаписываются при каждом запуске', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = InMemoryHallRepository(prefs);
      final hall = (await first.find(const HallQuery(size: 50))).items.first;
      await first.save(hall.copyWith(name: 'Правка сохранилась'));
      final second = InMemoryHallRepository(prefs);
      final restored = await second.findById(hall.id);
      expect(restored!.name, 'Правка сохранилась');
    });
    test('повреждённые данные не приводят к падению приложения', () async {
      SharedPreferences.setMockInitialValues({
        'focus_frame_halls_v${VersionedStore.currentVersion}': 'не json вовсе',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = InMemoryHallRepository(prefs);
      final result = await repository.find(const HallQuery(size: 50));
      expect(result.items, isNotEmpty);
    });
  });
  group('устойчивость моделей', () {
    test('fromJson не падает на отсутствующих и null-значениях', () {
      final hall = StudioHall.fromJson({'id': 1});
      expect(hall.name, '');
      expect(hall.capacity, 0);
      expect(hall.bookingIds, isEmpty);
      expect(hall.isDeleted, isFalse);
      final booking = Booking.fromJson({'id': null, 'date': null});
      expect(booking.accessCode, '');
      expect(booking.durationHours, 1);
      expect(booking.isDeleted, isFalse);
    });
    test('toJson и fromJson образуют полный круг', () {
      final source = Booking(
        id: 3,
        clientName: 'Тест',
        clientId: 2,
        email: 't@mail.ru',
        accessCode: 'CODE-1',
        hallId: 4,
        photographerIds: [1, 2],
        date: DateTime(2026, 7, 1),
        durationHours: 3,
        participants: 5,
        shootingType: 'Портретная',
        comment: 'Заметка',
      );
      final restored = Booking.fromJson(source.toJson());
      expect(restored.id, source.id);
      expect(restored.photographerIds, source.photographerIds);
      expect(restored.date, source.date);
      expect(restored.comment, source.comment);
    });
  });
  group('валидаторы', () {
    test('обязательность и длина строки', () {
      expect(V.required()(''), isNotNull);
      expect(V.length(min: 2, max: 4)('ab'), isNull);
      expect(V.length(min: 2, max: 4)('a'), isNotNull);
      expect(V.length(min: 2, max: 4)('abcde'), isNotNull);
    });
    test('положительность количества', () {
      expect(V.positive()('0'), isNotNull);
      expect(V.positive()('-3'), isNotNull);
      expect(V.positive()('7'), isNull);
    });
    test('формат почты и диапазон чисел', () {
      expect(V.email()('client@mail.ru'), isNull);
      expect(V.email()('не почта'), isNotNull);
      expect(V.integer(min: 1, max: 10)('11'), isNotNull);
      expect(V.integer(min: 1, max: 10)('5'), isNull);
    });
    test('код бронирования проверяет формат и длину', () {
      expect(V.accessCode()('BR-2026-0001'), isNull);
      expect(V.accessCode()('short'), isNotNull);
      expect(V.accessCode()('плохой код'), isNotNull);
    });
  });
}
