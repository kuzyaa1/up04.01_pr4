class Client {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String clientType;
  final String company;
  final String cardNumber;
  final String cardIssuedAt;
  final String cardExpiresAt;
  final String notes;
  final DateTime? deletedAt;
  const Client({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.clientType = 'Частный',
    this.company = '',
    required this.cardNumber,
    required this.cardIssuedAt,
    this.cardExpiresAt = '',
    this.notes = '',
    this.deletedAt,
  });
  bool get isDeleted => deletedAt != null;
  static List<String> get clientTypes => const ['Частный', 'Корпоративный'];
  bool isCardValidOn(DateTime date) {
    final issued = DateTime.tryParse(cardIssuedAt);
    if (issued != null && date.isBefore(issued)) return false;
    final expires = DateTime.tryParse(cardExpiresAt);
    if (expires != null && date.isAfter(expires)) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'clientType': clientType,
        'company': company,
        'cardNumber': cardNumber,
        'cardIssuedAt': cardIssuedAt,
        'cardExpiresAt': cardExpiresAt,
        'notes': notes,
        'deletedAt': deletedAt?.toIso8601String(),
      };
  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        email: _asString(json['email']),
        phone: _asString(json['phone']),
        clientType: _asString(json['clientType'], fallback: 'Частный'),
        company: _asString(json['company']),
        cardNumber: _asString(json['cardNumber']),
        cardIssuedAt: _asString(json['cardIssuedAt']),
        cardExpiresAt: _asString(json['cardExpiresAt']),
        notes: _asString(json['notes']),
        deletedAt: _asDate(json['deletedAt']),
      );
  Client copyWith({
    String? name,
    String? email,
    String? phone,
    String? clientType,
    String? company,
    String? cardNumber,
    String? cardIssuedAt,
    String? cardExpiresAt,
    String? notes,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) =>
      Client(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        clientType: clientType ?? this.clientType,
        company: company ?? this.company,
        cardNumber: cardNumber ?? this.cardNumber,
        cardIssuedAt: cardIssuedAt ?? this.cardIssuedAt,
        cardExpiresAt: cardExpiresAt ?? this.cardExpiresAt,
        notes: notes ?? this.notes,
        deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      );
  static int _asInt(Object? value) => switch (value) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v) ?? 0,
        _ => 0,
      };
  static String _asString(Object? value, {String fallback = ''}) =>
      value == null ? fallback : value.toString();
  static DateTime? _asDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}
