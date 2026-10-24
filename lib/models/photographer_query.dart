class PhotographerQuery {
  static const _unset = Object();
  static const allowedSizes = [10, 25, 50];
  static const sortFields = [
    'lastName',
    'firstName',
    'specialization',
    'experienceYears',
    'hourlyRate'
  ];
  final String search;
  final String? specialization;
  final int? hallId;
  final int? experienceFrom;
  final int? experienceTo;
  final int? rateFrom;
  final int? rateTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;
  const PhotographerQuery({
    this.search = '',
    this.specialization,
    this.hallId,
    this.experienceFrom,
    this.experienceTo,
    this.rateFrom,
    this.rateTo,
    this.sortField = 'lastName',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });
  factory PhotographerQuery.fromUri(Uri uri) {
    final p = uri.queryParameters;
    final s = (p['sort'] ?? '').split(',');
    final field = sortFields.contains(s.first) ? s.first : 'lastName';
    final size = int.tryParse(p['size'] ?? '') ?? 10;
    return PhotographerQuery(
      search: p['search'] ?? '',
      specialization: p['specialization'],
      hallId: int.tryParse(p['hallId'] ?? ''),
      experienceFrom: int.tryParse(p['experienceFrom'] ?? ''),
      experienceTo: int.tryParse(p['experienceTo'] ?? ''),
      rateFrom: int.tryParse(p['rateFrom'] ?? ''),
      rateTo: int.tryParse(p['rateTo'] ?? ''),
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
    if (specialization != null) p['specialization'] = specialization!;
    if (hallId != null) p['hallId'] = '$hallId';
    if (experienceFrom != null) p['experienceFrom'] = '$experienceFrom';
    if (experienceTo != null) p['experienceTo'] = '$experienceTo';
    if (rateFrom != null) p['rateFrom'] = '$rateFrom';
    if (rateTo != null) p['rateTo'] = '$rateTo';
    if (sortField != 'lastName' || !sortAscending) {
      p['sort'] = '$sortField,${sortAscending ? 'asc' : 'desc'}';
    }
    if (page != 1) p['page'] = '$page';
    if (size != 10) p['size'] = '$size';
    if (includeDeleted) p['includeDeleted'] = 'true';
    return p;
  }

  PhotographerQuery copyWith({
    String? search,
    Object? specialization = _unset,
    Object? hallId = _unset,
    Object? experienceFrom = _unset,
    Object? experienceTo = _unset,
    Object? rateFrom = _unset,
    Object? rateTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) =>
      PhotographerQuery(
        search: search ?? this.search,
        specialization: specialization == _unset
            ? this.specialization
            : specialization as String?,
        hallId: hallId == _unset ? this.hallId : hallId as int?,
        experienceFrom: experienceFrom == _unset
            ? this.experienceFrom
            : experienceFrom as int?,
        experienceTo:
            experienceTo == _unset ? this.experienceTo : experienceTo as int?,
        rateFrom: rateFrom == _unset ? this.rateFrom : rateFrom as int?,
        rateTo: rateTo == _unset ? this.rateTo : rateTo as int?,
        sortField: sortField ?? this.sortField,
        sortAscending: sortAscending ?? this.sortAscending,
        page: page ?? 1,
        size: size ?? this.size,
        includeDeleted: includeDeleted ?? this.includeDeleted,
      );
  bool get hasActiveFilters =>
      search.isNotEmpty ||
      specialization != null ||
      hallId != null ||
      experienceFrom != null ||
      experienceTo != null ||
      rateFrom != null ||
      rateTo != null ||
      includeDeleted;
}
