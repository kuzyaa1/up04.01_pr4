class BookingQuery {
  static const _unset = Object();
  static const allowedSizes = [10, 25, 50];
  static const sortFields = [
    'date',
    'clientName',
    'shootingType',
    'durationHours',
    'participants',
    'total'
  ];
  final String search;
  final int? hallId;
  final int? clientId;
  final int? photographerId;
  final String? shootingType;
  final int? participantsFrom;
  final int? participantsTo;
  final int? durationFrom;
  final int? durationTo;
  final String? dateFrom;
  final String? dateTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;
  const BookingQuery({
    this.search = '',
    this.hallId,
    this.clientId,
    this.photographerId,
    this.shootingType,
    this.participantsFrom,
    this.participantsTo,
    this.durationFrom,
    this.durationTo,
    this.dateFrom,
    this.dateTo,
    this.sortField = 'date',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });
  factory BookingQuery.fromUri(Uri uri) {
    final p = uri.queryParameters;
    final s = (p['sort'] ?? '').split(',');
    final field = sortFields.contains(s.first) ? s.first : 'date';
    final size = int.tryParse(p['size'] ?? '') ?? 10;
    return BookingQuery(
      search: p['search'] ?? '',
      hallId: int.tryParse(p['hallId'] ?? ''),
      clientId: int.tryParse(p['clientId'] ?? ''),
      photographerId: int.tryParse(p['photographerId'] ?? ''),
      shootingType: p['shootingType'],
      participantsFrom: int.tryParse(p['participantsFrom'] ?? ''),
      participantsTo: int.tryParse(p['participantsTo'] ?? ''),
      durationFrom: int.tryParse(p['durationFrom'] ?? ''),
      durationTo: int.tryParse(p['durationTo'] ?? ''),
      dateFrom: p['dateFrom'],
      dateTo: p['dateTo'],
      sortField: field,
      sortAscending: s.length < 2 || s[1] != 'desc',
      page: (int.tryParse(p['page'] ?? '') ?? 1).clamp(1, 9999).toInt(),
      size: allowedSizes.contains(size) ? size : 10,
      includeDeleted: p['includeDeleted'] == 'true',
    );
  }
  Map<String, String> toQueryParameters() {
    final p = <String, String>{};
    if (search.trim().isNotEmpty) p['search'] = search.trim();
    if (hallId != null) p['hallId'] = '$hallId';
    if (clientId != null) p['clientId'] = '$clientId';
    if (photographerId != null) p['photographerId'] = '$photographerId';
    if (shootingType != null) p['shootingType'] = shootingType!;
    if (participantsFrom != null) p['participantsFrom'] = '$participantsFrom';
    if (participantsTo != null) p['participantsTo'] = '$participantsTo';
    if (durationFrom != null) p['durationFrom'] = '$durationFrom';
    if (durationTo != null) p['durationTo'] = '$durationTo';
    if (dateFrom != null && dateFrom!.isNotEmpty) p['dateFrom'] = dateFrom!;
    if (dateTo != null && dateTo!.isNotEmpty) p['dateTo'] = dateTo!;
    if (sortField != 'date' || !sortAscending) {
      p['sort'] = '$sortField,${sortAscending ? 'asc' : 'desc'}';
    }
    if (page != 1) p['page'] = '$page';
    if (size != 10) p['size'] = '$size';
    if (includeDeleted) p['includeDeleted'] = 'true';
    return p;
  }

  BookingQuery copyWith({
    String? search,
    Object? hallId = _unset,
    Object? clientId = _unset,
    Object? photographerId = _unset,
    Object? shootingType = _unset,
    Object? participantsFrom = _unset,
    Object? participantsTo = _unset,
    Object? durationFrom = _unset,
    Object? durationTo = _unset,
    Object? dateFrom = _unset,
    Object? dateTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) =>
      BookingQuery(
        search: search ?? this.search,
        hallId: hallId == _unset ? this.hallId : hallId as int?,
        clientId: clientId == _unset ? this.clientId : clientId as int?,
        photographerId: photographerId == _unset
            ? this.photographerId
            : photographerId as int?,
        shootingType: shootingType == _unset
            ? this.shootingType
            : shootingType as String?,
        participantsFrom: participantsFrom == _unset
            ? this.participantsFrom
            : participantsFrom as int?,
        participantsTo: participantsTo == _unset
            ? this.participantsTo
            : participantsTo as int?,
        durationFrom:
            durationFrom == _unset ? this.durationFrom : durationFrom as int?,
        durationTo: durationTo == _unset ? this.durationTo : durationTo as int?,
        dateFrom: dateFrom == _unset ? this.dateFrom : dateFrom as String?,
        dateTo: dateTo == _unset ? this.dateTo : dateTo as String?,
        sortField: sortField ?? this.sortField,
        sortAscending: sortAscending ?? this.sortAscending,
        page: page ?? 1,
        size: size ?? this.size,
        includeDeleted: includeDeleted ?? this.includeDeleted,
      );
  bool get hasActiveFilters =>
      search.isNotEmpty ||
      hallId != null ||
      clientId != null ||
      photographerId != null ||
      shootingType != null ||
      participantsFrom != null ||
      participantsTo != null ||
      durationFrom != null ||
      durationTo != null ||
      (dateFrom != null && dateFrom!.isNotEmpty) ||
      (dateTo != null && dateTo!.isNotEmpty) ||
      includeDeleted;
}
