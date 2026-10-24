import 'package:dio/dio.dart';

import '../models/booking.dart';
import '../models/booking_query.dart';
import '../models/page_result.dart';

/// Репозиторий бронирований.
///
/// Появился параметр [cancelToken] — им отменяется устаревший запрос.
abstract interface class BookingRepository {
  Future<PageResult<Booking>> find(
    BookingQuery query, {
    CancelToken? cancelToken,
  });
  Future<Booking?> findById(int id);
  Future<List<Booking>> all({bool includeDeleted = false});
  Future<Booking> save(Booking booking);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> softDeleteMany(List<int> ids);
  Future<int> hardDeleteMany(List<int> ids);
  Future<int> countForHall(int hallId);
  Future<int> countForClient(int clientId);
  Future<int> countForPhotographer(int photographerId);
  Future<List<String>> shootingTypes();

  /// Отменяет бронирование. Сервер вернёт 409, если оно уже закрыто.
  Future<Booking> cancel(int id);

  /// Завершает бронирование. Сервер вернёт 409, если оно уже закрыто.
  Future<Booking> complete(int id);
}
