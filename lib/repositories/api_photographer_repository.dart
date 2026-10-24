import '../core/json_parsing.dart';
import '../models/photographer.dart';
import '../models/photographer_query.dart';
import 'api_repository.dart';
import 'photographer_repository.dart';

/// Реализация [PhotographerRepository] поверх REST API.
class ApiPhotographerRepository
    extends ApiRepository<Photographer, PhotographerQuery>
    implements PhotographerRepository {
  ApiPhotographerRepository(super.dio);

  @override
  String get collectionPath => '/photographers';

  @override
  int get defaultSize => 10;

  @override
  Photographer fromJson(Map<String, dynamic> json) {
    final fullName = parseString(json['fullName']).trim();
    final parts = fullName.split(RegExp(r'\s+'));
    final lastName = parts.isEmpty ? '' : parts.first;
    final firstName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return Photographer(
      id: parseInt(json['id']),
      firstName: firstName,
      lastName: lastName,
      specialization: parseString(json['specialization']),
      bio: parseString(json['city']),
      experienceYears: parseInt(json['experienceYears']),
      hourlyRate: parseInt(json['hourlyRate']),
      hallIds: parseIntList(json['bookingIds']),
      bookingIds: parseIntList(json['bookingIds']),
      deletedAt: parseDate(json['deletedAt']),
    );
  }

  @override
  Map<String, dynamic> toRequestBody(Photographer photographer) => {
        'fullName': photographer.fullName.trim(),
        'specialization': photographer.specialization.trim(),
        'city': photographer.bio.trim(),
        'experienceYears': photographer.experienceYears,
        'hourlyRate': photographer.hourlyRate,
      };

  @override
  Map<String, dynamic> toParameters(PhotographerQuery query) => {
        if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
        if (query.specialization != null && query.specialization!.isNotEmpty)
          'specialization': query.specialization,
        if (query.experienceFrom != null)
          'experienceFrom': query.experienceFrom,
        if (query.experienceTo != null) 'experienceTo': query.experienceTo,
        if (query.rateFrom != null) 'rateFrom': query.rateFrom,
        if (query.rateTo != null) 'rateTo': query.rateTo,
        'sort': '${query.sortField},${query.sortAscending ? 'asc' : 'desc'}',
        'page': query.page,
        'size': query.size,
        if (query.includeDeleted) 'includeDeleted': 'true',
      };

  @override
  PhotographerQuery allQuery({bool includeDeleted = false}) =>
      PhotographerQuery(
        size: 100,
        page: 1,
        includeDeleted: includeDeleted,
      );

  @override
  Future<Photographer> save(Photographer photographer) async {
    if (photographer.id == 0) return create(photographer);
    return update(photographer.id, photographer);
  }

  @override
  Future<int> countBookings(int id) async {
    final photographers = await all();
    for (final photographer in photographers) {
      if (photographer.id == id) return photographer.bookingIds.length;
    }
    return 0;
  }
}
