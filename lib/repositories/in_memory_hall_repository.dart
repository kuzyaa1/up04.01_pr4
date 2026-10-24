import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/errors.dart';
import '../data/seed_data.dart';
import '../models/hall_query.dart';
import '../models/page_result.dart';
import '../models/studio_hall.dart';
import 'hall_repository.dart';
import 'in_memory_repository.dart';

class InMemoryHallRepository extends InMemoryRepository<StudioHall>
    implements HallRepository {
  InMemoryHallRepository(SharedPreferences prefs)
      : super(
          prefs: prefs,
          name: 'halls',
          parse: StudioHall.fromJson,
          encode: (hall) => hall.toJson(),
          seed: seedHalls.map((hall) => hall.toJson()).toList(),
        );
  @override
  int rowId(StudioHall item) => item.id;
  @override
  bool rowDeleted(StudioHall item) => item.isDeleted;
  @override
  Map<String, dynamic> rowJson(StudioHall item) => item.toJson();
  @override
  StudioHall rowWithDeletedAt(StudioHall item, DateTime? deletedAt) =>
      deletedAt == null
          ? item.copyWith(clearDeletedAt: true)
          : item.copyWith(deletedAt: deletedAt);
  @override
  Future<PageResult<StudioHall>> find(
    HallQuery query, {
    CancelToken? cancelToken,
  }) async {
    if (query.capacityFrom != null &&
        query.capacityTo != null &&
        query.capacityFrom! > query.capacityTo!) {
      throw ArgumentError('Вместимость «от» больше вместимости «до»');
    }
    if (query.priceFrom != null &&
        query.priceTo != null &&
        query.priceFrom! > query.priceTo!) {
      throw ArgumentError('Цена «от» больше цены «до»');
    }
    return page(
      pageNumber: query.page,
      pageSize: query.size,
      filter: (rows) {
        var result = rows.where((x) => query.includeDeleted || !x.isDeleted);
        final search = query.search.trim().toLowerCase();
        if (search.isNotEmpty) {
          result = result
              .where((x) =>
                  x.name.toLowerCase().contains(search) ||
                  x.code.toLowerCase().contains(search) ||
                  x.style.toLowerCase().contains(search))
              .toList();
        }
        if (query.style != null) {
          result = result.where((x) => x.style == query.style).toList();
        }
        if (query.capacityFrom != null) {
          result =
              result.where((x) => x.capacity >= query.capacityFrom!).toList();
        }
        if (query.capacityTo != null) {
          result =
              result.where((x) => x.capacity <= query.capacityTo!).toList();
        }
        if (query.priceFrom != null) {
          result =
              result.where((x) => x.hourlyRate >= query.priceFrom!).toList();
        }
        if (query.priceTo != null) {
          result = result.where((x) => x.hourlyRate <= query.priceTo!).toList();
        }
        final list = result.toList();
        list.sort((a, b) {
          final compared = switch (query.sortField) {
            'capacity' => a.capacity.compareTo(b.capacity),
            'hourlyRate' => a.hourlyRate.compareTo(b.hourlyRate),
            'style' => a.style.compareTo(b.style),
            _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          };
          return query.sortAscending ? compared : -compared;
        });
        return list;
      },
    );
  }

  @override
  Future<StudioHall> save(StudioHall hall) async {
    final code = hall.code.trim().toUpperCase();
    final duplicate = items.any(
        (x) => x.id != hall.id && x.code.toUpperCase() == code && !x.isDeleted);
    if (duplicate) {
      throw const FieldValidationException(
          'code', 'Зал с таким кодом уже существует');
    }
    final saved = hall.id == 0
        ? StudioHall(
            id: nextId(),
            name: hall.name.trim(),
            code: code,
            style: hall.style,
            capacity: hall.capacity,
            hourlyRate: hall.hourlyRate,
            equipmentIds: hall.equipmentIds,
            bookingIds: hall.bookingIds)
        : hall.copyWith(name: hall.name.trim(), code: code);
    put(saved);
    await persist();
    return saved;
  }

  Future<StudioHall> saveUnchecked(StudioHall hall) async {
    put(hall);
    await persist();
    return hall;
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
      final index = items.indexWhere((x) => x.id == id && !x.isDeleted);
      if (index < 0) continue;
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
  Future<int> countBookings(int id) async =>
      items.where((hall) => hall.bookingIds.contains(id)).length;
  @override
  Future<int> countEquipment(int id) async =>
      items.where((hall) => hall.equipmentIds.contains(id)).length;
}
