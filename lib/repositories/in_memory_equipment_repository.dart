import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors.dart';
import '../data/seed_data.dart';
import '../models/equipment.dart';
import '../models/equipment_query.dart';
import '../models/page_result.dart';
import 'equipment_repository.dart';
import 'in_memory_repository.dart';

/// Реализация [EquipmentRepository] на данных в памяти.
///
/// Оставлена после ПР4: на ней написаны модульные тесты из ПР3,
/// и она показывает, что интерфейс репозитория не изменился.
class EquipmentRepositoryImpl extends InMemoryRepository<Equipment>
    implements EquipmentRepository {
  EquipmentRepositoryImpl(SharedPreferences prefs)
      : super(
          prefs: prefs,
          name: 'equipment',
          parse: Equipment.fromJson,
          encode: (equipment) => equipment.toJson(),
          seed: seedEquipment.map((item) => item.toJson()).toList(),
        );

  @override
  int rowId(Equipment item) => item.id;

  @override
  bool rowDeleted(Equipment item) => item.isDeleted;

  @override
  Map<String, dynamic> rowJson(Equipment item) => item.toJson();

  @override
  Equipment rowWithDeletedAt(Equipment item, DateTime? deletedAt) =>
      deletedAt == null
          ? item.copyWith(clearDeletedAt: true)
          : item.copyWith(deletedAt: deletedAt);

  @override
  Future<PageResult<Equipment>> find(
    EquipmentQuery query, {
    CancelToken? cancelToken,
  }) async {
    if (query.quantityFrom != null &&
        query.quantityTo != null &&
        query.quantityFrom! > query.quantityTo!) {
      throw ArgumentError('Количество «от» больше количества «до»');
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
        var result =
            rows.where((x) => query.includeDeleted || !x.isDeleted).toList();
        final search = query.search.trim().toLowerCase();
        if (search.isNotEmpty) {
          result = result
              .where((x) =>
                  x.name.toLowerCase().contains(search) ||
                  x.category.toLowerCase().contains(search) ||
                  x.manufacturer.toLowerCase().contains(search))
              .toList();
        }
        if (query.category != null && query.category!.isNotEmpty) {
          result = result.where((x) => x.category == query.category).toList();
        }
        if (query.hallId != null) {
          result = result.where((x) => x.hallId == query.hallId).toList();
        }
        if (query.quantityFrom != null) {
          result =
              result.where((x) => x.quantity >= query.quantityFrom!).toList();
        }
        if (query.quantityTo != null) {
          result =
              result.where((x) => x.quantity <= query.quantityTo!).toList();
        }
        if (query.priceFrom != null) {
          result =
              result.where((x) => x.pricePerDay >= query.priceFrom!).toList();
        }
        if (query.priceTo != null) {
          result =
              result.where((x) => x.pricePerDay <= query.priceTo!).toList();
        }
        result.sort((a, b) {
          final compared = switch (query.sortField) {
            'category' => a.category.compareTo(b.category),
            'quantity' => a.quantity.compareTo(b.quantity),
            'pricePerDay' => a.pricePerDay.compareTo(b.pricePerDay),
            'hall' => a.hallId.compareTo(b.hallId),
            _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          };
          return query.sortAscending ? compared : -compared;
        });
        return result;
      },
    );
  }

  @override
  Future<Equipment> save(Equipment equipment) async {
    final name = equipment.name.trim().toLowerCase();
    final duplicate = items.any((x) =>
        x.id != equipment.id &&
        !x.isDeleted &&
        x.hallId == equipment.hallId &&
        x.name.trim().toLowerCase() == name);
    if (duplicate) {
      throw const FieldValidationException(
          'name', 'В этом зале уже есть оборудование с таким названием');
    }
    final saved = equipment.id == 0
        ? Equipment(
            id: nextId(),
            name: equipment.name.trim(),
            category: equipment.category,
            manufacturer: equipment.manufacturer.trim(),
            hallId: equipment.hallId,
            quantity: equipment.quantity,
            pricePerDay: equipment.pricePerDay)
        : equipment.copyWith(
            name: equipment.name.trim(),
            manufacturer: equipment.manufacturer.trim(),
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
}
