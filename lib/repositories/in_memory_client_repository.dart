import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors.dart';
import '../data/seed_data.dart';
import '../models/client.dart';
import '../models/client_query.dart';
import '../models/page_result.dart';
import 'client_repository.dart';
import 'in_memory_repository.dart';

/// Реализация [ClientRepository] на данных в памяти.
///
/// Оставлена после ПР4: на ней написаны модульные тесты из ПР3,
/// и она показывает, что интерфейс репозитория не изменился.
class ClientRepositoryImpl extends InMemoryRepository<Client>
    implements ClientRepository {
  ClientRepositoryImpl(SharedPreferences prefs)
      : super(
          prefs: prefs,
          name: 'clients',
          parse: Client.fromJson,
          encode: (client) => client.toJson(),
          seed: seedClients.map((client) => client.toJson()).toList(),
        );

  @override
  int rowId(Client item) => item.id;

  @override
  bool rowDeleted(Client item) => item.isDeleted;

  @override
  Map<String, dynamic> rowJson(Client item) => item.toJson();

  @override
  Client rowWithDeletedAt(Client item, DateTime? deletedAt) => deletedAt == null
      ? item.copyWith(clearDeletedAt: true)
      : item.copyWith(deletedAt: deletedAt);

  @override
  Future<PageResult<Client>> find(
    ClientQuery query, {
    CancelToken? cancelToken,
  }) async {
    if (query.yearFrom != null &&
        query.yearTo != null &&
        query.yearFrom! > query.yearTo!) {
      throw ArgumentError('Год «от» больше года «до»');
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
                  x.name.toLowerCase().contains(search) ||
                  x.email.toLowerCase().contains(search) ||
                  x.phone.toLowerCase().contains(search) ||
                  x.company.toLowerCase().contains(search) ||
                  x.cardNumber.toLowerCase().contains(search))
              .toList();
        }
        if (query.hasCard != null) {
          result = result
              .where((x) => x.cardNumber.trim().isNotEmpty == query.hasCard)
              .toList();
        }
        if (query.clientType != null && query.clientType!.isNotEmpty) {
          result =
              result.where((x) => x.clientType == query.clientType).toList();
        }
        if (query.yearFrom != null || query.yearTo != null) {
          result = result.where((x) {
            final year = int.tryParse(x.cardIssuedAt.split('-').first) ?? 0;
            if (year == 0) {
              return query.yearFrom == null && query.yearTo == null;
            }
            if (query.yearFrom != null && year < query.yearFrom!) return false;
            if (query.yearTo != null && year > query.yearTo!) return false;
            return true;
          }).toList();
        }
        result.sort((a, b) {
          final compared = switch (query.sortField) {
            'email' => a.email.compareTo(b.email),
            'phone' => a.phone.compareTo(b.phone),
            'cardNumber' => a.cardNumber.compareTo(b.cardNumber),
            'cardExpiresAt' => a.cardExpiresAt.compareTo(b.cardExpiresAt),
            'clientType' => a.clientType.compareTo(b.clientType),
            _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          };
          return query.sortAscending ? compared : -compared;
        });
        return result;
      },
    );
  }

  @override
  Future<Client> save(Client client) async {
    final email = client.email.trim().toLowerCase();
    final emailTaken = items.any((x) =>
        x.id != client.id &&
        !x.isDeleted &&
        x.email.trim().toLowerCase() == email);
    if (emailTaken) {
      throw const FieldValidationException(
          'email', 'Клиент с таким адресом почты уже есть');
    }
    final phoneTaken = items.any((x) =>
        x.id != client.id &&
        !x.isDeleted &&
        client.phone.trim().isNotEmpty &&
        x.phone.trim() == client.phone.trim());
    if (phoneTaken) {
      throw const FieldValidationException(
          'phone', 'Клиент с таким телефоном уже есть');
    }
    final cardTaken = items.any((x) =>
        x.id != client.id &&
        !x.isDeleted &&
        client.cardNumber.trim().isNotEmpty &&
        x.cardNumber.trim().toUpperCase() ==
            client.cardNumber.trim().toUpperCase());
    if (cardTaken) {
      throw const FieldValidationException(
          'cardNumber', 'Абонемент с таким номером уже есть');
    }
    final saved = client.id == 0
        ? Client(
            id: nextId(),
            name: client.name.trim(),
            email: client.email.trim(),
            phone: client.phone.trim(),
            clientType: client.clientType,
            company: client.company.trim(),
            cardNumber: client.cardNumber.trim().toUpperCase(),
            cardIssuedAt: client.cardIssuedAt.trim(),
            cardExpiresAt: client.cardExpiresAt.trim(),
            notes: client.notes.trim(),
          )
        : client.copyWith(
            name: client.name.trim(),
            email: client.email.trim(),
            phone: client.phone.trim(),
            clientType: client.clientType,
            company: client.company.trim(),
            cardNumber: client.cardNumber.trim().toUpperCase(),
            cardIssuedAt: client.cardIssuedAt.trim(),
            cardExpiresAt: client.cardExpiresAt.trim(),
            notes: client.notes.trim(),
          );
    put(saved);
    await persist();
    return saved;
  }

  @override
  Future<void> softDelete(int id) async {
    markDeleted(id);
    await persist();
  }

  @override
  Future<void> hardDelete(int id) async {
    remove(id);
    await persist();
  }

  @override
  Future<void> restore(int id) async {
    markRestored(id);
    await persist();
  }

  @override
  Future<int> softDeleteMany(List<int> ids) async {
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
    final before = items.length;
    for (final id in ids) {
      remove(id);
    }
    await persist();
    return before - items.length;
  }
}
