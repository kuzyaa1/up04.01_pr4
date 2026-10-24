import '../core/json_parsing.dart';
import '../models/equipment.dart';
import '../models/equipment_query.dart';
import 'api_repository.dart';
import 'equipment_repository.dart';

/// Реализация [EquipmentRepository] поверх REST API.
class ApiEquipmentRepository extends ApiRepository<Equipment, EquipmentQuery>
    implements EquipmentRepository {
  ApiEquipmentRepository(super.dio);

  @override
  String get collectionPath => '/equipment';

  @override
  int get defaultSize => 10;

  @override
  Equipment fromJson(Map<String, dynamic> json) => Equipment(
        id: parseInt(json['id']),
        name: parseString(json['name']),
        category: parseString(json['category']),
        manufacturer: parseString(json['manufacturer']),
        hallId: parseInt(json['hallId']),
        quantity: parseInt(json['quantity'], fallback: 1),
        pricePerDay: parseInt(json['pricePerDay']),
        deletedAt: parseDate(json['deletedAt']),
      );

  @override
  Map<String, dynamic> toRequestBody(Equipment equipment) => {
        'name': equipment.name.trim(),
        'category': equipment.category.trim(),
        'manufacturer': equipment.manufacturer.trim(),
        'hallId': equipment.hallId,
        'quantity': equipment.quantity,
        'pricePerDay': equipment.pricePerDay,
      };

  @override
  Map<String, dynamic> toParameters(EquipmentQuery query) => {
        if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
        if (query.category != null && query.category!.isNotEmpty)
          'category': query.category,
        if (query.hallId != null) 'hallId': query.hallId,
        if (query.quantityFrom != null) 'quantityFrom': query.quantityFrom,
        if (query.quantityTo != null) 'quantityTo': query.quantityTo,
        if (query.priceFrom != null) 'priceFrom': query.priceFrom,
        if (query.priceTo != null) 'priceTo': query.priceTo,
        'sort': '${query.sortField},${query.sortAscending ? 'asc' : 'desc'}',
        'page': query.page,
        'size': query.size,
        if (query.includeDeleted) 'includeDeleted': 'true',
      };

  @override
  EquipmentQuery allQuery({bool includeDeleted = false}) => EquipmentQuery(
        size: 100,
        page: 1,
        includeDeleted: includeDeleted,
      );

  @override
  Future<Equipment> save(Equipment equipment) async {
    if (equipment.id == 0) return create(equipment);
    return update(equipment.id, equipment);
  }
}
