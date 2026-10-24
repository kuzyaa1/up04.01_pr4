import 'package:dio/dio.dart';

import '../models/page_result.dart';
import '../models/photographer.dart';
import '../models/photographer_query.dart';

/// Репозиторий фотографов.
///
/// Появился параметр [cancelToken] — им отменяется устаревший запрос.
abstract interface class PhotographerRepository {
  Future<PageResult<Photographer>> find(
    PhotographerQuery query, {
    CancelToken? cancelToken,
  });
  Future<Photographer?> findById(int id);
  Future<List<Photographer>> all({bool includeDeleted = false});
  Future<Photographer> save(Photographer photographer);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> softDeleteMany(List<int> ids);
  Future<int> hardDeleteMany(List<int> ids);
  Future<int> countBookings(int id);
}
