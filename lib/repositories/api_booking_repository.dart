import '../core/api_exceptions.dart';
import '../core/json_parsing.dart';
import '../models/booking.dart';
import '../models/booking_query.dart';
import 'api_repository.dart';
import 'booking_repository.dart';

/// Реализация [BookingRepository] поверх REST API.
class ApiBookingRepository extends ApiRepository<Booking, BookingQuery>
    implements BookingRepository {
  ApiBookingRepository(super.dio);

  @override
  String get collectionPath => '/bookings';

  @override
  int get defaultSize => 10;

  @override
  Booking fromJson(Map<String, dynamic> json) {
    final hall = json['hall'];
    final client = json['client'];
    final hallData = hall is Map<String, dynamic> ? hall : const {};
    final clientData = client is Map<String, dynamic> ? client : const {};
    return Booking(
      id: parseInt(json['id']),
      clientName: parseString(clientData['fullName']),
      clientId: parseInt(clientData['id']),
      email: '',
      accessCode: parseString(json['accessCode']),
      hallId: parseInt(hallData['id']),
      photographerIds: parseIntList(json['photographerIds']),
      date: parseDate(json['date']) ?? DateTime.now(),
      durationHours: parseInt(json['durationHours'], fallback: 1),
      participants: parseInt(json['participants'], fallback: 1),
      shootingType: parseString(json['shootingType'], fallback: 'Портрет'),
      comment: parseString(json['comment']),
      status: parseString(json['status'], fallback: 'active'),
      deletedAt: parseDate(json['deletedAt']),
    );
  }

  @override
  Map<String, dynamic> toRequestBody(Booking booking) => {
        'accessCode': booking.accessCode.trim().toUpperCase(),
        'hallId': booking.hallId,
        'clientId': booking.clientId,
        'photographerIds': booking.photographerIds,
        'date': booking.date.toUtc().toIso8601String(),
        'durationHours': booking.durationHours,
        'participants': booking.participants,
        'shootingType': booking.shootingType.trim(),
        'comment': booking.comment.trim(),
      };

  @override
  Map<String, dynamic> toParameters(BookingQuery query) => {
        if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
        if (query.hallId != null) 'hallId': query.hallId,
        if (query.clientId != null) 'clientId': query.clientId,
        if (query.photographerId != null)
          'photographerId': query.photographerId,
        if (query.shootingType != null && query.shootingType!.isNotEmpty)
          'shootingType': query.shootingType,
        if (query.participantsFrom != null)
          'participantsFrom': query.participantsFrom,
        if (query.participantsTo != null)
          'participantsTo': query.participantsTo,
        if (query.durationFrom != null) 'durationFrom': query.durationFrom,
        if (query.durationTo != null) 'durationTo': query.durationTo,
        if (query.dateFrom != null && query.dateFrom!.isNotEmpty)
          'dateFrom': query.dateFrom,
        if (query.dateTo != null && query.dateTo!.isNotEmpty)
          'dateTo': query.dateTo,
        'sort': '${query.sortField},${query.sortAscending ? 'asc' : 'desc'}',
        'page': query.page,
        'size': query.size,
        if (query.includeDeleted) 'includeDeleted': 'true',
      };

  @override
  BookingQuery allQuery({bool includeDeleted = false}) => BookingQuery(
        size: 100,
        page: 1,
        includeDeleted: includeDeleted,
      );

  @override
  Future<Booking> save(Booking booking) async {
    if (booking.id == 0) return create(booking);
    return update(booking.id, booking);
  }

  @override
  Future<int> countForHall(int hallId) async {
    final page = await find(BookingQuery(size: 1, hallId: hallId));
    return page.total;
  }

  @override
  Future<int> countForClient(int clientId) async {
    final page = await find(BookingQuery(size: 1, clientId: clientId));
    return page.total;
  }

  @override
  Future<int> countForPhotographer(int photographerId) async {
    final page = await find(
      BookingQuery(size: 1, photographerId: photographerId),
    );
    return page.total;
  }

  @override
  Future<List<String>> shootingTypes() async {
    final bookings = await all();
    final values = bookings
        .map((booking) => booking.shootingType.trim())
        .where((text) => text.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  /// Отменяет бронирование.
  ///
  /// Сервер вернёт 409, если бронирование уже закрыто или отменено.
  @override
  Future<Booking> cancel(int id) async {
    final response = await guard(
      () => dio.post<Map<String, dynamic>>('/bookings/$id/cancel'),
    );
    return fromJson(response.data ?? const <String, dynamic>{});
  }

  /// Завершает бронирование.
  @override
  Future<Booking> complete(int id) async {
    final response = await guard(
      () => dio.post<Map<String, dynamic>>('/bookings/$id/complete'),
    );
    return fromJson(response.data ?? const <String, dynamic>{});
  }
}
