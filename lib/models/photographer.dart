class Photographer {
  final int id;
  final String firstName;
  final String lastName;
  final String specialization;
  final String bio;
  final int experienceYears;
  final int hourlyRate;
  final List<int> hallIds;
  final List<int> bookingIds;
  final DateTime? deletedAt;
  const Photographer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.specialization,
    this.bio = '',
    required this.experienceYears,
    required this.hourlyRate,
    this.hallIds = const [],
    this.bookingIds = const [],
    this.deletedAt,
  });
  String get fullName => '$lastName $firstName';
  bool get isDeleted => deletedAt != null;
  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'specialization': specialization,
        'bio': bio,
        'experienceYears': experienceYears,
        'hourlyRate': hourlyRate,
        'hallIds': hallIds,
        'bookingIds': bookingIds,
        'deletedAt': deletedAt?.toIso8601String(),
      };
  factory Photographer.fromJson(Map<String, dynamic> json) => Photographer(
        id: _asInt(json['id']),
        firstName: _asString(json['firstName']),
        lastName: _asString(json['lastName']),
        specialization: _asString(json['specialization']),
        bio: _asString(json['bio']),
        experienceYears: _asInt(json['experienceYears']),
        hourlyRate: _asInt(json['hourlyRate']),
        hallIds: _asIntList(json['hallIds']),
        bookingIds: _asIntList(json['bookingIds']),
        deletedAt: _asDate(json['deletedAt']),
      );
  Photographer copyWith(
          {String? firstName,
          String? lastName,
          String? specialization,
          String? bio,
          int? experienceYears,
          int? hourlyRate,
          List<int>? hallIds,
          List<int>? bookingIds,
          DateTime? deletedAt,
          bool clearDeletedAt = false}) =>
      Photographer(
        id: id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        specialization: specialization ?? this.specialization,
        bio: bio ?? this.bio,
        experienceYears: experienceYears ?? this.experienceYears,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        hallIds: hallIds ?? this.hallIds,
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
    return value.map(_asInt).where((id) => id > 0).toList();
  }

  static DateTime? _asDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}
