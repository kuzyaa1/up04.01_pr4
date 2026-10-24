import '../core/json_parsing.dart';
import '../models/client.dart';
import '../models/client_query.dart';
import 'api_repository.dart';
import 'client_repository.dart';

/// Реализация [ClientRepository] поверх REST API.
class ApiClientRepository extends ApiRepository<Client, ClientQuery>
    implements ClientRepository {
  ApiClientRepository(super.dio);

  @override
  String get collectionPath => '/clients';

  @override
  int get defaultSize => 10;

  @override
  Client fromJson(Map<String, dynamic> json) {
    final card = json['card'];
    final cardData = card is Map<String, dynamic> ? card : const {};
    return Client(
      id: parseInt(json['id']),
      name: parseString(json['fullName']),
      email: parseString(json['email']),
      phone: parseString(json['phone']),
      clientType: parseString(json['clientType'], fallback: 'Частный'),
      company: parseString(json['company']),
      cardNumber: parseString(cardData['number']),
      cardIssuedAt: parseString(cardData['issuedAt']),
      cardExpiresAt: parseString(cardData['expiresAt']),
      notes: '',
      deletedAt: parseDate(json['deletedAt']),
    );
  }

  @override
  Map<String, dynamic> toRequestBody(Client client) => {
        'fullName': client.name.trim(),
        'email': client.email.trim(),
        'phone': client.phone.trim(),
        'clientType': client.clientType,
        'company': client.company.trim(),
        'cardNumber': client.cardNumber.trim().toUpperCase(),
        'cardIssuedAt': client.cardIssuedAt.trim(),
        'cardExpiresAt': client.cardExpiresAt.trim(),
      };

  @override
  Map<String, dynamic> toParameters(ClientQuery query) => {
        if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
        if (query.clientType != null && query.clientType!.isNotEmpty)
          'clientType': query.clientType,
        if (query.hasCard != null) 'hasCard': query.hasCard,
        if (query.yearFrom != null) 'yearFrom': query.yearFrom,
        if (query.yearTo != null) 'yearTo': query.yearTo,
        'sort': '${query.sortField},${query.sortAscending ? 'asc' : 'desc'}',
        'page': query.page,
        'size': query.size,
        if (query.includeDeleted) 'includeDeleted': 'true',
      };

  @override
  ClientQuery allQuery({bool includeDeleted = false}) => ClientQuery(
        size: 100,
        page: 1,
        includeDeleted: includeDeleted,
      );

  @override
  Future<Client> save(Client client) async {
    if (client.id == 0) return create(client);
    return update(client.id, client);
  }
}
