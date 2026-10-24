class Equipment {
  final int id;
  final String name;
  final String category;
  final String manufacturer;
  final int hallId;
  final int quantity;
  final int pricePerDay;
  final DateTime? deletedAt;
  const Equipment({
    required this.id,
    required this.name,
    required this.category,
    this.manufacturer = '',
    required this.hallId,
    this.quantity = 1,
    this.pricePerDay = 0,
    this.deletedAt,
  });
  bool get isDeleted => deletedAt != null;
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'manufacturer': manufacturer,
        'hallId': hallId,
        'quantity': quantity,
        'pricePerDay': pricePerDay,
        'deletedAt': deletedAt?.toIso8601String(),
      };
  factory Equipment.fromJson(Map<String, dynamic> json) => Equipment(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        category: _asString(json['category']),
        manufacturer: _asString(json['manufacturer']),
        hallId: _asInt(json['hallId']),
        quantity: _asInt(json['quantity'], fallback: 1),
        pricePerDay: _asInt(json['pricePerDay']),
        deletedAt: _asDate(json['deletedAt']),
      );
  Equipment copyWith(
          {String? name,
          String? category,
          String? manufacturer,
          int? hallId,
          int? quantity,
          int? pricePerDay,
          DateTime? deletedAt,
          bool clearDeletedAt = false}) =>
      Equipment(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        manufacturer: manufacturer ?? this.manufacturer,
        hallId: hallId ?? this.hallId,
        quantity: quantity ?? this.quantity,
        pricePerDay: pricePerDay ?? this.pricePerDay,
        deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      );
  static int _asInt(Object? value, {int fallback = 0}) => switch (value) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v) ?? fallback,
        _ => fallback,
      };
  static String _asString(Object? value) =>
      value == null ? '' : value.toString();
  static DateTime? _asDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}
