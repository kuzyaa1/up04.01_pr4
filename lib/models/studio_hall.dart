class StudioHall {
  final int id;
  final String name;
  final String code;
  final String style;
  final int capacity;
  final int hourlyRate;
  final String description;
  final List<int> equipmentIds;
  final List<int> bookingIds;
  final DateTime? deletedAt;
  const StudioHall({
    required this.id,
    required this.name,
    required this.code,
    required this.style,
    required this.capacity,
    required this.hourlyRate,
    this.description = '',
    this.equipmentIds = const [],
    this.bookingIds = const [],
    this.deletedAt,
  });
  bool get isDeleted => deletedAt != null;
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'style': style,
        'capacity': capacity,
        'hourlyRate': hourlyRate,
        'description': description,
        'equipmentIds': equipmentIds,
        'bookingIds': bookingIds,
        'deletedAt': deletedAt?.toIso8601String(),
      };
  factory StudioHall.fromJson(Map<String, dynamic> json) => StudioHall(
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
  StudioHall copyWith(
          {String? name,
          String? code,
          String? style,
          int? capacity,
          int? hourlyRate,
          String? description,
          List<int>? equipmentIds,
          List<int>? bookingIds,
          DateTime? deletedAt,
          bool clearDeletedAt = false}) =>
      StudioHall(
        id: id,
        name: name ?? this.name,
        code: code ?? this.code,
        style: style ?? this.style,
        capacity: capacity ?? this.capacity,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        description: description ?? this.description,
        equipmentIds: equipmentIds ?? this.equipmentIds,
        bookingIds: bookingIds ?? this.bookingIds,
        deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      );
  static int _asInt(Object? value) => switch (value) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v) ?? 0,
        _ => 0,
      };
  static String _asString(Object? value) =>
      value == null ? '' : value.toString();
  static List<int> _asIntList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => _asInt(item)).where((id) => id > 0).toList();
  }

  static DateTime? _asDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}
