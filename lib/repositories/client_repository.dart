import 'package:dio/dio.dart';

import '../models/client.dart';
import '../models/client_query.dart';
import '../models/page_result.dart';

/// Репозиторий клиентов.
///
/// Появился параметр [cancelToken] — им отменяется устаревший запрос.
abstract interface class ClientRepository {
  Future<PageResult<Client>> find(
    ClientQuery query, {
    CancelToken? cancelToken,
  });
  Future<Client?> findById(int id);
  Future<List<Client>> all({bool includeDeleted = false});
  Future<Client> save(Client client);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> softDeleteMany(List<int> ids);
  Future<int> hardDeleteMany(List<int> ids);
}
