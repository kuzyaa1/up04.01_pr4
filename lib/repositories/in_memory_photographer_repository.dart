import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/errors.dart';
import '../data/seed_data.dart';
import '../models/page_result.dart';
import '../models/photographer.dart';
import '../models/photographer_query.dart';
import 'in_memory_repository.dart';
import 'photographer_repository.dart';

class InMemoryPhotographerRepository extends InMemoryRepository<Photographer>
    implements PhotographerRepository {
  InMemoryPhotographerRepository(SharedPreferences prefs)
      : super(
          prefs: prefs,
          name: 'photographers',
          parse: Photographer.fromJson,
          encode: (item) => item.toJson(),
          seed: seedPhotographers.map((item) => item.toJson()).toList(),
        );
  @override
  int rowId(Photographer item) => item.id;
  @override
  bool rowDeleted(Photographer item) => item.isDeleted;
  @override
  Map<String, dynamic> rowJson(Photographer item) => item.toJson();
  @override
  Photographer rowWithDeletedAt(Photographer item, DateTime? deletedAt) =>
      deletedAt == null
          ? item.copyWith(clearDeletedAt: true)
          : item.copyWith(deletedAt: deletedAt);
  @override
  Future<PageResult<Photographer>> find(PhotographerQuery query,
      {CancelToken? cancelToken}) async {
    if (query.experienceFrom != null &&
        query.experienceTo != null &&
        query.experienceFrom! > query.experienceTo!) {
      throw ArgumentError('Стаж «от» больше стажа «до»');
    }
    if (query.rateFrom != null &&
        query.rateTo != null &&
        query.rateFrom! > query.rateTo!) {
      throw ArgumentError('Ставка «от» больше ставки «до»');
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
                  x.lastName.toLowerCase().contains(search) ||
                  x.firstName.toLowerCase().contains(search) ||
                  x.specialization.toLowerCase().contains(search) ||
                  x.bio.toLowerCase().contains(search))
              .toList();
        }
        if (query.specialization != null) {
          result = result
              .where((x) => x.specialization == query.specialization)
              .toList();
        }
        if (query.hallId != null) {
          result =
              result.where((x) => x.hallIds.contains(query.hallId)).toList();
        }
        if (query.experienceFrom != null) {
          result = result
              .where((x) => x.experienceYears >= query.experienceFrom!)
              .toList();
        }
        if (query.experienceTo != null) {
          result = result
              .where((x) => x.experienceYears <= query.experienceTo!)
              .toList();
        }
        if (query.rateFrom != null) {
          result =
              result.where((x) => x.hourlyRate >= query.rateFrom!).toList();
        }
        if (query.rateTo != null) {
          result = result.where((x) => x.hourlyRate <= query.rateTo!).toList();
        }
        result.sort((a, b) {
          final compared = switch (query.sortField) {
            'specialization' => a.specialization.compareTo(b.specialization),
            'experienceYears' => a.experienceYears.compareTo(b.experienceYears),
            'hourlyRate' => a.hourlyRate.compareTo(b.hourlyRate),
            _ => a.lastName.compareTo(b.lastName),
          };
          return query.sortAscending ? compared : -compared;
        });
        return result;
      },
    );
  }

  @override
  Future<Photographer> save(Photographer photographer) async {
    await saveGuard?.call(photographer);
    final duplicate = items.any((x) =>
        x.id != photographer.id &&
        !x.isDeleted &&
        x.firstName.trim().toLowerCase() ==
            photographer.firstName.trim().toLowerCase() &&
        x.lastName.trim().toLowerCase() ==
            photographer.lastName.trim().toLowerCase());
    if (duplicate) {
      throw const FieldValidationException(
          'lastName', 'Фотограф с таким именем уже есть');
    }
    final saved = photographer.id == 0
        ? Photographer(
            id: nextId(),
            firstName: photographer.firstName.trim(),
            lastName: photographer.lastName.trim(),
            specialization: photographer.specialization,
            bio: photographer.bio.trim(),
            experienceYears: photographer.experienceYears,
            hourlyRate: photographer.hourlyRate,
            hallIds: photographer.hallIds,
            bookingIds: photographer.bookingIds)
        : photographer.copyWith(
            firstName: photographer.firstName.trim(),
            lastName: photographer.lastName.trim(),
            bio: photographer.bio.trim(),
          );
    put(saved);
    await persist();
    return saved;
  }

  Future<Photographer> saveUnchecked(Photographer photographer) async {
    put(photographer);
    await persist();
    return photographer;
  }

  @override
  Future<void> softDelete(int id) async {
    await checkDeletion([id]);
    markDeleted(id);
    await persist();
  }

  @override
  Future<void> hardDelete(int id) async {
    await checkDeletion([id], hard: true);
    remove(id);
    await persist();
  }

  @override
  Future<void> restore(int id) async {
    final item = await findById(id);
    if (item == null) throw StateError('Запись #$id не найдена');
    await save(rowWithDeletedAt(item, null));
  }

  @override
  Future<int> softDeleteMany(List<int> ids) async {
    await checkDeletion(ids);
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
    await checkDeletion(ids, hard: true);
    final before = items.length;
    for (final id in ids) {
      remove(id);
    }
    await persist();
    return before - items.length;
  }

  @override
  Future<int> countBookings(int id) async =>
      items.where((item) => item.bookingIds.contains(id)).length;
}
