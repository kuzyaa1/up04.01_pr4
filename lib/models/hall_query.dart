class HallQuery {
  static const _unset = Object();
  static const allowedSizes = [10, 25, 50];
  static const sortFields = ['name', 'capacity', 'hourlyRate', 'style'];
  final String search;
  final String? style;
  final int? capacityFrom;
  final int? capacityTo;
  final int? priceFrom;
  final int? priceTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;
  const HallQuery(
      {this.search = '',
      this.style,
      this.capacityFrom,
      this.capacityTo,
      this.priceFrom,
      this.priceTo,
      this.sortField = 'name',
      this.sortAscending = true,
      this.page = 1,
      this.size = 10,
      this.includeDeleted = false});
  factory HallQuery.fromUri(Uri uri) {
    final p = uri.queryParameters;
    final sort = (p['sort'] ?? '').split(',');
    final field = sortFields.contains(sort.first) ? sort.first : 'name';
    final size = int.tryParse(p['size'] ?? '') ?? 10;
    return HallQuery(
        search: p['search'] ?? '',
        style: p['style'],
        capacityFrom: int.tryParse(p['capacityFrom'] ?? ''),
        capacityTo: int.tryParse(p['capacityTo'] ?? ''),
        priceFrom: int.tryParse(p['priceFrom'] ?? ''),
        priceTo: int.tryParse(p['priceTo'] ?? ''),
        sortField: field,
        sortAscending: sort.length < 2 || sort[1] != 'desc',
        page: (int.tryParse(p['page'] ?? '') ?? 1).clamp(1, 9999).toInt(),
        size: allowedSizes.contains(size) ? size : 10,
        includeDeleted: p['includeDeleted'] == 'true');
  }
  Map<String, String> toQueryParameters() {
    final p = <String, String>{};
    if (search.trim().isNotEmpty) p['search'] = search.trim();
    if (style != null) p['style'] = style!;
    if (capacityFrom != null) p['capacityFrom'] = '$capacityFrom';
    if (capacityTo != null) p['capacityTo'] = '$capacityTo';
    if (priceFrom != null) p['priceFrom'] = '$priceFrom';
    if (priceTo != null) p['priceTo'] = '$priceTo';
    if (sortField != 'name' || !sortAscending) {
      p['sort'] = '$sortField,${sortAscending ? 'asc' : 'desc'}';
    }
    if (page != 1) p['page'] = '$page';
    if (size != 10) p['size'] = '$size';
    if (includeDeleted) p['includeDeleted'] = 'true';
    return p;
  }

  HallQuery copyWith(
          {String? search,
          Object? style = _unset,
          Object? capacityFrom = _unset,
          Object? capacityTo = _unset,
          Object? priceFrom = _unset,
          Object? priceTo = _unset,
          String? sortField,
          bool? sortAscending,
          int? page,
          int? size,
          bool? includeDeleted}) =>
      HallQuery(
          search: search ?? this.search,
          style: style == _unset ? this.style : style as String?,
          capacityFrom:
              capacityFrom == _unset ? this.capacityFrom : capacityFrom as int?,
          capacityTo:
              capacityTo == _unset ? this.capacityTo : capacityTo as int?,
          priceFrom: priceFrom == _unset ? this.priceFrom : priceFrom as int?,
          priceTo: priceTo == _unset ? this.priceTo : priceTo as int?,
          sortField: sortField ?? this.sortField,
          sortAscending: sortAscending ?? this.sortAscending,
          page: page ?? 1,
          size: size ?? this.size,
          includeDeleted: includeDeleted ?? this.includeDeleted);
  bool get hasActiveFilters =>
      search.isNotEmpty ||
      style != null ||
      capacityFrom != null ||
      capacityTo != null ||
      priceFrom != null ||
      priceTo != null ||
      includeDeleted;
}
