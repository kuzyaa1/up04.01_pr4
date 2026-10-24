import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/errors.dart';
import '../data/seed_data.dart';
import '../models/booking.dart';
import '../models/booking_query.dart';
import '../models/page_result.dart';
import 'hall_repository.dart';
import 'photographer_repository.dart';
import 'booking_repository.dart';
import 'in_memory_hall_repository.dart';
import 'in_memory_photographer_repository.dart';
import 'in_memory_repository.dart';

class PersistentBookingRepository extends InMemoryRepository<Booking>
    implements BookingRepository {
  PersistentBookingRepository(
    SharedPreferences prefs, {
    HallRepository? halls,
    PhotographerRepository? photographers,
  })  : _halls = halls,
        _photographers = photographers,
        super(
          prefs: prefs,
          name: 'bookings',
          parse: Booking.fromJson,
          encode: (booking) => booking.toJson(),
          seed: seedBookings.map((item) => item.toJson()).toList(),
        );
  final HallRepository? _halls;
  final PhotographerRepository? _photographers;
  @override
  void onAfterPut(Booking item, Booking? previous) {
    if (previous != null) _detachBacklinks(previous);
    _attachBacklinks(item);
  }

  @override
  void onBeforeRemove(Booking item) => _detachBacklinks(item);
  void _attachBacklinks(Booking item) {
    final halls = _halls;
    if (halls is InMemoryHallRepository) {
      final hall =
          halls.items.where((row) => row.id == item.hallId).firstOrNull;
      if (hall != null && !hall.bookingIds.contains(item.id)) {
        halls.replace(hall.copyWith(bookingIds: [...hall.bookingIds, item.id]));
      }
    }
    final photographers = _photographers;
    if (photographers is InMemoryPhotographerRepository) {
      for (final id in item.photographerIds) {
        final person =
            photographers.items.where((row) => row.id == id).firstOrNull;
        if (person == null || person.bookingIds.contains(item.id)) continue;
        photographers.replace(
            person.copyWith(bookingIds: [...person.bookingIds, item.id]));
      }
    }
  }

  void _detachBacklinks(Booking item) {
    final halls = _halls;
    if (halls is InMemoryHallRepository) {
      final hall =
          halls.items.where((row) => row.id == item.hallId).firstOrNull;
      if (hall != null && hall.bookingIds.contains(item.id)) {
        halls.replace(hall.copyWith(
          bookingIds: hall.bookingIds.where((id) => id != item.id).toList(),
        ));
      }
    }
    final photographers = _photographers;
    if (photographers is InMemoryPhotographerRepository) {
      for (final id in item.photographerIds) {
        final person =
            photographers.items.where((row) => row.id == id).firstOrNull;
        if (person == null || !person.bookingIds.contains(item.id)) continue;
        photographers.replace(person.copyWith(
          bookingIds:
              person.bookingIds.where((value) => value != item.id).toList(),
        ));
      }
    }
  }

  @override
  int rowId(Booking item) => item.id;
  @override
  bool rowDeleted(Booking item) => item.isDeleted;
  @override
  Map<String, dynamic> rowJson(Booking item) => item.toJson();
  @override
  Booking rowWithDeletedAt(Booking item, DateTime? deletedAt) =>
      deletedAt == null
          ? item.copyWith(clearDeletedAt: true)
          : item.copyWith(deletedAt: deletedAt);
  @override
  Future<PageResult<Booking>> find(
    BookingQuery query, {
    CancelToken? cancelToken,
  }) async {
    if (query.participantsFrom != null &&
        query.participantsTo != null &&
        query.participantsFrom! > query.participantsTo!) {
      throw ArgumentError('Участников «от» больше, чем «до»');
    }
    if (query.durationFrom != null &&
        query.durationTo != null &&
        query.durationFrom! > query.durationTo!) {
      throw ArgumentError('Длительность «от» больше длительности «до»');
    }
    final dateFrom = query.dateFrom == null || query.dateFrom!.isEmpty
        ? null
        : DateTime.tryParse(query.dateFrom!);
    final dateTo = query.dateTo == null || query.dateTo!.isEmpty
        ? null
        : DateTime.tryParse(query.dateTo!);
    return page(
      pageNumber: query.page,
      pageSize: query.size,
      filter: (rows) {
        var result =
            rows.where((x) => query.includeDeleted || !x.isDeleted).toList();
        final search = query.search.trim().toLowerCase();
        if (search.isNotEmpty) {
          result = result
              .where((x) =>
                  x.clientName.toLowerCase().contains(search) ||
                  x.email.toLowerCase().contains(search) ||
                  x.accessCode.toLowerCase().contains(search) ||
                  x.shootingType.toLowerCase().contains(search) ||
                  x.comment.toLowerCase().contains(search))
              .toList();
        }
        if (query.hallId != null) {
          result = result.where((x) => x.hallId == query.hallId).toList();
        }
        if (query.clientId != null) {
          result = result.where((x) => x.clientId == query.clientId).toList();
        }
        if (query.photographerId != null) {
          result = result
              .where((x) => x.photographerIds.contains(query.photographerId))
              .toList();
        }
        if (query.shootingType != null) {
          result = result
              .where((x) => x.shootingType == query.shootingType)
              .toList();
        }
        if (query.participantsFrom != null) {
          result = result
              .where((x) => x.participants >= query.participantsFrom!)
              .toList();
        }
        if (query.participantsTo != null) {
          result = result
              .where((x) => x.participants <= query.participantsTo!)
              .toList();
        }
        if (query.durationFrom != null) {
          result = result
              .where((x) => x.durationHours >= query.durationFrom!)
              .toList();
        }
        if (query.durationTo != null) {
          result = result
              .where((x) => x.durationHours <= query.durationTo!)
              .toList();
        }
        if (dateFrom != null) {
          result = result.where((x) => !x.date.isBefore(dateFrom)).toList();
        }
        if (dateTo != null) {
          result = result.where((x) => !x.date.isAfter(dateTo)).toList();
        }
        result.sort((a, b) {
          final compared = switch (query.sortField) {
            'clientName' => a.clientName.compareTo(b.clientName),
            'shootingType' => a.shootingType.compareTo(b.shootingType),
            'durationHours' => a.durationHours.compareTo(b.durationHours),
            'participants' => a.participants.compareTo(b.participants),
            'total' => a.durationHours.compareTo(b.durationHours),
            _ => a.date.compareTo(b.date),
          };
          return query.sortAscending ? compared : -compared;
        });
        return result;
      },
    );
  }

  @override
  Future<Booking> save(Booking booking) async {
    final code = booking.accessCode.trim().toUpperCase();
    final duplicate = items.any((x) =>
        x.id != booking.id &&
        !x.isDeleted &&
        x.accessCode.trim().toUpperCase() == code);
    if (duplicate) {
      throw const FieldValidationException(
          'accessCode', 'Бронирование с таким кодом уже существует');
    }
    final saved = booking.id == 0
        ? Booking(
            id: nextId(),
            clientName: booking.clientName.trim(),
            clientId: booking.clientId,
            email: booking.email.trim(),
            accessCode: code,
            hallId: booking.hallId,
            photographerIds: booking.photographerIds,
            date: booking.date,
            durationHours: booking.durationHours,
            participants: booking.participants,
            shootingType: booking.shootingType,
            comment: booking.comment.trim())
        : booking.copyWith(
            clientName: booking.clientName.trim(),
            email: booking.email.trim(),
            accessCode: code,
            comment: booking.comment.trim(),
          );
    put(saved);
    await persist();
    return saved;
  }

  @override
  Future<void> softDelete(int id) async {
    markDeleted(id);
    await persist();
  }

  @override
  Future<void> hardDelete(int id) async {
    remove(id);
    await persist();
  }

  @override
  Future<void> restore(int id) async {
    markRestored(id);
    await persist();
  }

  @override
  Future<int> softDeleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final exists = items.any((x) => x.id == id && !x.isDeleted);
      if (!exists) continue;
      markDeleted(id);
      count++;
    }
    await persist();
    return count;
  }

  @override
  Future<int> hardDeleteMany(List<int> ids) async {
    final before = items.length;
    for (final id in ids) {
      remove(id);
    }
    await persist();
    return before - items.length;
  }

  @override
  Future<int> countForHall(int hallId) async =>
      items.where((x) => x.hallId == hallId && !x.isDeleted).length;
  @override
  Future<int> countForClient(int clientId) async =>
      items.where((x) => x.clientId == clientId && !x.isDeleted).length;
  @override
  Future<int> countForPhotographer(int photographerId) async => items
      .where((x) => x.photographerIds.contains(photographerId) && !x.isDeleted)
      .length;
  @override
  Future<List<String>> shootingTypes() async {
    final values = items
        .where((x) => !x.isDeleted && x.shootingType.trim().isNotEmpty)
        .map((x) => x.shootingType.trim())
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  /// Отменяет бронирование.
  ///
  /// Реализация на данных в памяти отменяет его без обращения к серверу.
  @override
  Future<Booking> cancel(int id) async {
    final booking = items.where((x) => x.id == id).firstOrNull;
    if (booking == null) throw StateError('Бронирование #$id не найдено');
    if (booking.status != 'active') {
      throw const FieldValidationException(
        'status',
        'Отменить можно только активное бронирование',
      );
    }
    final saved = booking.copyWith(status: 'cancelled');
    replace(saved);
    await persist();
    return saved;
  }

  /// Завершает бронирование.
  @override
  Future<Booking> complete(int id) async {
    final booking = items.where((x) => x.id == id).firstOrNull;
    if (booking == null) throw StateError('Бронирование #$id не найдено');
    if (booking.status != 'active') {
      throw const FieldValidationException(
        'status',
        'Завершить можно только активное бронирование',
      );
    }
    final saved = booking.copyWith(status: 'completed');
    replace(saved);
    await persist();
    return saved;
  }
}
