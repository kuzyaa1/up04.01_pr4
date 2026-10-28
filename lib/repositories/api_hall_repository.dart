import '../core/api_exceptions.dart';
import '../models/hall_query.dart';
import '../models/studio_hall.dart';
import 'api_repository.dart';
import 'hall_repository.dart';

/// Реализация [HallRepository] поверх REST API.
///
/// Интерфейс репозитория не изменился с ПР3 — поменялась только реализация.
class ApiHallRepository extends ApiRepository<StudioHall, HallQuery>
    implements HallRepository {
  ApiHallRepository(super.dio);

  @override
  String get collectionPath => '/halls';

  @override
  int get defaultSize => 10;

  @override
  StudioHall fromJson(Map<String, dynamic> json) => StudioHall(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        code: _asString(json['code']),
        style: _asString(json['style']),
        capacity: _asInt(json['capacity']),
        hourlyRate: _asInt(json['hourlyRate']),
        description: _asString(json['description']),
        equipmentIds: _asIntList(json['equipmentIds']),
        bookingIds: _asIntList(json['bookingIds']),
        deletedAt: _asDate(json['deletedAt']),
      );

  @override
  Map<String, dynamic> toRequestBody(StudioHall hall) => {
        'name': hall.name.trim(),
        'code': hall.code.trim().toUpperCase(),
        'style': hall.style.trim(),
        'capacity': hall.capacity,
        'hourlyRate': hall.hourlyRate,
        'description': hall.description.trim(),
      };

  @override
  Map<String, dynamic> toParameters(HallQuery query) => {
        if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
        if (query.style != null && query.style!.isNotEmpty)
          'style': query.style,
        if (query.capacityFrom != null) 'capacityFrom': query.capacityFrom,
        if (query.capacityTo != null) 'capacityTo': query.capacityTo,
        if (query.priceFrom != null) 'priceFrom': query.priceFrom,
        if (query.priceTo != null) 'priceTo': query.priceTo,
        'sort': '${query.sortField},${query.sortAscending ? 'asc' : 'desc'}',
        'page': query.page,
        'size': query.size,
        if (query.includeDeleted) 'includeDeleted': 'true',
      };

  @override
  HallQuery allQuery({bool includeDeleted = false}) => HallQuery(
        size: 100,
        page: 1,
        includeDeleted: includeDeleted,
      );

  @override
  Future<StudioHall> save(StudioHall hall) async {
    if (hall.id == 0) return create(hall);
    return update(hall.id, hall);
  }

  @override
  Future<int> countBookings(int id) async {
    final response = await guard(() => dio.get<Map<String, dynamic>>(
          '/bookings',
          queryParameters: {'hallId': id, 'size': 1},
        ));
    return _asInt(response.data?['total']);
  }

  @override
  Future<int> countEquipment(int id) async {
    final halls = await all();
    for (final hall in halls) {
      if (hall.id == id) return hall.equipmentIds.length;
    }
    return 0;
  }
}

/// Разбор целого числа с безопасным значением по умолчанию.
int _asInt(Object? value, {int fallback = 0}) => switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ?? fallback,
      _ => fallback,
    };

/// Разбор строки с безопасным значением по умолчанию.
String _asString(Object? value, {String fallback = ''}) =>
    value == null ? fallback : value.toString();

/// Разбор списка идентификаторов.
List<int> _asIntList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => _asInt(item)).where((id) => id > 0).toList();
}

/// Разбор даты.
DateTime? _asDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
