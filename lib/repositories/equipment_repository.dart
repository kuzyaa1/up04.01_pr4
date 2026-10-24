import 'package:dio/dio.dart';

import '../models/equipment.dart';
import '../models/equipment_query.dart';
import '../models/page_result.dart';

/// Репозиторий оборудования студии.
///
/// Появился параметр [cancelToken] — им отменяется устаревший запрос.
abstract interface class EquipmentRepository {
  Future<PageResult<Equipment>> find(
    EquipmentQuery query, {
    CancelToken? cancelToken,
  });
  Future<Equipment?> findById(int id);
  Future<List<Equipment>> all({bool includeDeleted = false});
  Future<Equipment> save(Equipment equipment);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> softDeleteMany(List<int> ids);
  Future<int> hardDeleteMany(List<int> ids);
}
