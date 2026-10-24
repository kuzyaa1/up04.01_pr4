class Booking {
  final int id;
  final String clientName;
  final int clientId;
  final String email;
  final String accessCode;
  final int hallId;
  final List<int> photographerIds;
  final DateTime date;
  final int durationHours;
  final int participants;
  final String shootingType;
  final String comment;
  final String status;
  final DateTime? deletedAt;
  const Booking({
    required this.id,
    required this.clientName,
    this.clientId = 0,
    required this.email,
    required this.accessCode,
    required this.hallId,
    this.photographerIds = const [],
    required this.date,
    required this.durationHours,
    required this.participants,
    required this.shootingType,
    this.comment = '',
    this.status = 'active',
    this.deletedAt,
  });
  bool get isDeleted => deletedAt != null;
  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'clientId': clientId,
        'email': email,
        'accessCode': accessCode,
        'hallId': hallId,
        'photographerIds': photographerIds,
        'date': date.toIso8601String(),
        'durationHours': durationHours,
        'participants': participants,
        'shootingType': shootingType,
        'comment': comment,
        'status': status,
        'deletedAt': deletedAt?.toIso8601String(),
      };
  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: _asInt(json['id']),
        clientName: _asString(json['clientName']),
        clientId: _asInt(json['clientId']),
        email: _asString(json['email']),
        accessCode: _asString(json['accessCode']),
        hallId: _asInt(json['hallId']),
        photographerIds: _asIntList(json['photographerIds']),
        date: _asDate(json['date']) ?? DateTime.now(),
        durationHours: _asInt(json['durationHours'], fallback: 1),
        participants: _asInt(json['participants'], fallback: 1),
        shootingType: _asString(json['shootingType'], fallback: 'Портретная'),
        comment: _asString(json['comment']),
        status: _asString(json['status'], fallback: 'active'),
        deletedAt: _asDate(json['deletedAt']),
      );
  Booking copyWith(
          {String? clientName,
          int? clientId,
          String? email,
          String? accessCode,
          int? hallId,
          List<int>? photographerIds,
          DateTime? date,
          int? durationHours,
          int? participants,
          String? shootingType,
          String? comment,
          String? status,
          DateTime? deletedAt,
          bool clearDeletedAt = false}) =>
      Booking(
        id: id,
        clientName: clientName ?? this.clientName,
        clientId: clientId ?? this.clientId,
        email: email ?? this.email,
        accessCode: accessCode ?? this.accessCode,
        hallId: hallId ?? this.hallId,
        photographerIds: photographerIds ?? this.photographerIds,
        date: date ?? this.date,
        durationHours: durationHours ?? this.durationHours,
        participants: participants ?? this.participants,
        shootingType: shootingType ?? this.shootingType,
        comment: comment ?? this.comment,
        status: status ?? this.status,
        deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      );
  static int _asInt(Object? value, {int fallback = 0}) => switch (value) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v) ?? fallback,
        _ => fallback,
      };
  static String _asString(Object? value, {String fallback = ''}) =>
      value == null ? fallback : value.toString();
  static List<int> _asIntList(Object? value) {
    if (value is! List) return const [];
    return value.map(_asInt).where((id) => id > 0).toList();
  }

  static DateTime? _asDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}
