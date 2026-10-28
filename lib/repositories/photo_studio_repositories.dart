import 'package:shared_preferences/shared_preferences.dart';
import '../core/errors.dart';
import 'in_memory_client_repository.dart';
import 'in_memory_equipment_repository.dart';
import 'in_memory_hall_repository.dart';
import 'in_memory_photographer_repository.dart';
import 'persistent_booking_repository.dart';

/// The same integrity rules apply to individual and bulk operations.
class PhotoStudioRepositories {
  final InMemoryHallRepository halls;
  final InMemoryPhotographerRepository photographers;
  final ClientRepositoryImpl clients;
  final EquipmentRepositoryImpl equipment;
  late final PersistentBookingRepository bookings;

  PhotoStudioRepositories(SharedPreferences prefs)
      : halls = InMemoryHallRepository(prefs),
        photographers = InMemoryPhotographerRepository(prefs),
        clients = ClientRepositoryImpl(prefs),
        equipment = EquipmentRepositoryImpl(prefs) {
    bookings = PersistentBookingRepository(prefs,
        halls: halls, photographers: photographers);
    halls.deletionGuard = (ids, hard) async {
      final bookingCount = bookings.items
          .where((b) => ids.contains(b.hallId) && (hard || !b.isDeleted))
          .length;
      final equipmentCount = equipment.items
          .where((e) => ids.contains(e.hallId) && (hard || !e.isDeleted))
          .length;
      final photographerCount = photographers.items
          .where((p) => p.hallIds.any(ids.contains) && (hard || !p.isDeleted))
          .length;
      final count = bookingCount + equipmentCount + photographerCount;
      if (count > 0) {
        throw LinkedRecordsException(
            'Нельзя удалить зал: связанных бронирований — $bookingCount, оборудования — $equipmentCount, фотографов — $photographerCount',
            count);
      }
    };
    clients.deletionGuard = (ids, hard) async {
      final count = bookings.items
          .where((b) => ids.contains(b.clientId) && (hard || !b.isDeleted))
          .length;
      if (count > 0) {
        throw LinkedRecordsException(
            'Нельзя удалить клиента: связанных бронирований — $count', count);
      }
    };
    photographers.deletionGuard = (ids, hard) async {
      final count = bookings.items
          .where((b) =>
              b.photographerIds.any(ids.contains) && (hard || !b.isDeleted))
          .length;
      if (count > 0) {
        throw LinkedRecordsException(
            'Нельзя удалить фотографа: связанных бронирований — $count', count);
      }
    };
    bookings.saveGuard = (booking) async {
      final hall = await halls.findById(booking.hallId);
      if (hall == null || hall.isDeleted) {
        throw const FieldValidationException(
            'hallId', 'Выберите существующий активный зал');
      }
      final client = await clients.findById(booking.clientId);
      if (client == null || client.isDeleted) {
        throw const FieldValidationException(
            'clientId', 'Выберите существующего активного клиента');
      }
      if (booking.participants > hall.capacity) {
        throw FieldValidationException('participants',
            'Вместимость выбранного зала — ${hall.capacity} чел.');
      }
      if (booking.photographerIds.isEmpty) {
        throw const FieldValidationException(
            'photographerIds', 'Выберите хотя бы одного фотографа');
      }
      for (final id in booking.photographerIds) {
        final person = await photographers.findById(id);
        if (person == null ||
            person.isDeleted ||
            (person.hallIds.isNotEmpty && !person.hallIds.contains(hall.id))) {
          throw const FieldValidationException(
              'photographerIds', 'Фотограф недоступен в выбранном зале');
        }
      }
    };
    equipment.saveGuard = (item) async {
      final hall = await halls.findById(item.hallId);
      if (hall == null || hall.isDeleted) {
        throw const FieldValidationException(
            'hallId', 'Выберите существующий активный зал');
      }
    };
    photographers.saveGuard = (person) async {
      for (final id in person.hallIds) {
        final hall = await halls.findById(id);
        if (hall == null || hall.isDeleted) {
          throw const FieldValidationException(
              'hallIds', 'Выберите существующие активные залы');
        }
      }
      final invalid = bookings.items.any((b) =>
          !b.isDeleted &&
          b.photographerIds.contains(person.id) &&
          !person.hallIds.contains(b.hallId));
      if (invalid) {
        throw const FieldValidationException('hallIds',
            'Нельзя убрать зал с действующими бронированиями фотографа');
      }
    };
    bookings.afterChange = synchronizeLinks;
    equipment.afterChange = synchronizeLinks;
  }

  Future<void> synchronizeLinks() async {
    for (final hall in halls.items) {
      halls.replace(hall.copyWith(
        bookingIds: bookings.items
            .where((b) => b.hallId == hall.id)
            .map((b) => b.id)
            .toList(),
        equipmentIds: equipment.items
            .where((e) => e.hallId == hall.id)
            .map((e) => e.id)
            .toList(),
      ));
    }
    for (final person in photographers.items) {
      photographers.replace(person.copyWith(
        bookingIds: bookings.items
            .where((b) => b.photographerIds.contains(person.id))
            .map((b) => b.id)
            .toList(),
      ));
    }
    await halls.persist();
    await photographers.persist();
  }
}
