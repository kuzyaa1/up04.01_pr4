class ClientQuery {
  static const _unset = Object();
  static const allowedSizes = [10, 25, 50];
  static const sortFields = [
    'name',
    'email',
    'phone',
    'cardNumber',
    'cardExpiresAt',
    'clientType'
  ];
  final String search;
  final bool? hasCard;
  final String? clientType;
  final int? yearFrom;
  final int? yearTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;
  const ClientQuery({
    this.search = '',
    this.hasCard,
    this.clientType,
    this.yearFrom,
    this.yearTo,
    this.sortField = 'name',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });
  factory ClientQuery.fromUri(Uri uri) {
    final p = uri.queryParameters;
    final s = (p['sort'] ?? '').split(',');
    final field = sortFields.contains(s.first) ? s.first : 'name';
    final size = int.tryParse(p['size'] ?? '') ?? 10;
    final hasCard = switch (p['hasCard']) {
      'true' => true,
      'false' => false,
      _ => null,
    };
    return ClientQuery(
      search: p['search'] ?? '',
      hasCard: hasCard,
      clientType: p['clientType'],
      yearFrom: int.tryParse(p['yearFrom'] ?? ''),
      yearTo: int.tryParse(p['yearTo'] ?? ''),
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
    if (hasCard != null) p['hasCard'] = '$hasCard';
    if (clientType != null && clientType!.isNotEmpty) {
      p['clientType'] = clientType!;
    }
    if (yearFrom != null) p['yearFrom'] = '$yearFrom';
    if (yearTo != null) p['yearTo'] = '$yearTo';
    if (sortField != 'name' || !sortAscending) {
      p['sort'] = '$sortField,${sortAscending ? 'asc' : 'desc'}';
    }
    if (page != 1) p['page'] = '$page';
    if (size != 10) p['size'] = '$size';
    if (includeDeleted) p['includeDeleted'] = 'true';
    return p;
  }

  ClientQuery copyWith({
    String? search,
    Object? hasCard = _unset,
    Object? clientType = _unset,
    Object? yearFrom = _unset,
    Object? yearTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) =>
      ClientQuery(
        search: search ?? this.search,
        hasCard: hasCard == _unset ? this.hasCard : hasCard as bool?,
        clientType:
            clientType == _unset ? this.clientType : clientType as String?,
        yearFrom: yearFrom == _unset ? this.yearFrom : yearFrom as int?,
        yearTo: yearTo == _unset ? this.yearTo : yearTo as int?,
        sortField: sortField ?? this.sortField,
        sortAscending: sortAscending ?? this.sortAscending,
        page: page ?? 1,
        size: size ?? this.size,
        includeDeleted: includeDeleted ?? this.includeDeleted,
      );
  bool get hasActiveFilters =>
      search.isNotEmpty ||
      hasCard != null ||
      (clientType != null && clientType!.isNotEmpty) ||
      yearFrom != null ||
      yearTo != null ||
      includeDeleted;
}
