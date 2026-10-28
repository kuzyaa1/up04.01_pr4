import 'package:dio/dio.dart';
import '../core/api_exceptions.dart';
import '../models/booking.dart';
import '../state/session.dart';
import 'api_booking_repository.dart';

class RoleRepository {
  RoleRepository(this.dio);
  final Dio dio;
  Future<Map<String, dynamic>> summary(String path) =>
      guard(() async => (await dio.get<Map<String, dynamic>>(path)).data ?? {});
  Future<List<Booking>> myBookings() => guard(() async {
        final rows =
            (await dio.get<List<dynamic>>('/account/bookings')).data ?? [];
        return rows
            .cast<Map<String, dynamic>>()
            .map(ApiBookingRepository(dio).fromJson)
            .toList();
      });
  Future<void> extend(int id) => guard(() => dio.post('/bookings/$id/extend'));
  Future<List<AppUser>> users() => guard(() async {
        final data = await summary('/users?size=100');
        return (data['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(AppUser.fromJson)
            .toList();
      });
  Future<void> changeRole(int id, String role) =>
      guard(() => dio.patch('/users/$id/role', data: {'role': role}));
}
