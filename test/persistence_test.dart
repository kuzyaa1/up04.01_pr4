import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_studio_portal/models/hall_query.dart';
import 'package:photo_studio_portal/models/photographer_query.dart';
import 'package:photo_studio_portal/repositories/in_memory_hall_repository.dart';
import 'package:photo_studio_portal/repositories/in_memory_photographer_repository.dart';
import 'package:photo_studio_portal/repositories/persistent_booking_repository.dart';
import 'package:photo_studio_portal/models/booking_query.dart';
import 'package:photo_studio_portal/models/booking.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('залы: правка переживает «перезагрузку»', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = InMemoryHallRepository(prefs);
    final hall = (await first.find(const HallQuery(size: 50))).items.first;
    await first.save(hall.copyWith(name: 'Изменённый зал'));
    final second = InMemoryHallRepository(prefs);
    final restored = await second.findById(hall.id);
    expect(restored, isNotNull);
    expect(restored!.name, 'Изменённый зал');
  });
  test('фотографы: правка переживает «перезагрузку»', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = InMemoryPhotographerRepository(prefs);
    final person =
        (await first.find(const PhotographerQuery(size: 50))).items.first;
    await first.save(person.copyWith(hourlyRate: 9999));
    final second = InMemoryPhotographerRepository(prefs);
    final restored = await second.findById(person.id);
    expect(restored!.hourlyRate, 9999);
  });
  test('бронирования: правка и удаление переживают «перезагрузку»', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = PersistentBookingRepository(prefs);
    final booking =
        (await first.find(const BookingQuery(size: 50))).items.first;
    await first.save(booking.copyWith(comment: 'Правка сохранилась'));
    final second = PersistentBookingRepository(prefs);
    final restored = await second.findById(booking.id);
    expect(restored!.comment, 'Правка сохранилась');
    await second.softDelete(booking.id);
    final third = PersistentBookingRepository(prefs);
    expect((await third.findById(booking.id))!.isDeleted, isTrue);
    expect(
        (await third.find(const BookingQuery(size: 50)))
            .items
            .any((row) => row.id == booking.id),
        isFalse);
  });
  test('новое бронирование сохраняется и читается после «перезагрузки»',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = PersistentBookingRepository(prefs);
    final saved = await first.save(Booking(
      id: 0,
      clientName: 'Тестовый клиент',
      email: 't@mail.ru',
      accessCode: 'SAVE-TEST-1',
      hallId: 1,
      date: DateTime(2026, 9, 1),
      durationHours: 2,
      participants: 2,
      shootingType: 'Портретная',
    ));
    final second = PersistentBookingRepository(prefs);
    final restored = await second.findById(saved.id);
    expect(restored, isNotNull);
    expect(restored!.accessCode, 'SAVE-TEST-1');
    expect(restored.clientName, 'Тестовый клиент');
  });
  test('все коллекции пишутся в хранилище при первом запуске', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    InMemoryHallRepository(prefs);
    InMemoryPhotographerRepository(prefs);
    PersistentBookingRepository(prefs);
    final stored = prefs.getKeys().where((key) => key.contains('focus_frame'));
    expect(stored.length, greaterThanOrEqualTo(3));
    for (final key in stored) {
      expect(jsonDecode(prefs.getString(key)!), isA<List<dynamic>>());
    }
  });
}
