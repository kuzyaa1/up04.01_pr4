class EquipmentQuery {
  static const _unset = Object();
  static const allowedSizes = [10, 25, 50];
  static const sortFields = [
    'name',
    'category',
    'quantity',
    'pricePerDay',
    'hall'
  ];
  final String search;
  final String? category;
  final int? hallId;
  final int? quantityFrom;
  final int? quantityTo;
  final int? priceFrom;
  final int? priceTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;
  const EquipmentQuery({
    this.search = '',
    this.category,
    this.hallId,
    this.quantityFrom,
    this.quantityTo,
    this.priceFrom,
    this.priceTo,
    this.sortField = 'name',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });
  factory EquipmentQuery.fromUri(Uri uri) {
    final p = uri.queryParameters;
    final s = (p['sort'] ?? '').split(',');
    final field = sortFields.contains(s.first) ? s.first : 'name';
    final size = int.tryParse(p['size'] ?? '') ?? 10;
    return EquipmentQuery(
      search: p['search'] ?? '',
      category: p['category'],
      hallId: int.tryParse(p['hallId'] ?? ''),
      quantityFrom: int.tryParse(p['quantityFrom'] ?? ''),
      quantityTo: int.tryParse(p['quantityTo'] ?? ''),
      priceFrom: int.tryParse(p['priceFrom'] ?? ''),
      priceTo: int.tryParse(p['priceTo'] ?? ''),
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
    if (category != null) p['category'] = category!;
    if (hallId != null) p['hallId'] = '$hallId';
    if (quantityFrom != null) p['quantityFrom'] = '$quantityFrom';
    if (quantityTo != null) p['quantityTo'] = '$quantityTo';
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

  EquipmentQuery copyWith({
    String? search,
    Object? category = _unset,
    Object? hallId = _unset,
    Object? quantityFrom = _unset,
    Object? quantityTo = _unset,
    Object? priceFrom = _unset,
    Object? priceTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) =>
      EquipmentQuery(
        search: search ?? this.search,
        category: category == _unset ? this.category : category as String?,
        hallId: hallId == _unset ? this.hallId : hallId as int?,
        quantityFrom:
            quantityFrom == _unset ? this.quantityFrom : quantityFrom as int?,
        quantityTo: quantityTo == _unset ? this.quantityTo : quantityTo as int?,
        priceFrom: priceFrom == _unset ? this.priceFrom : priceFrom as int?,
        priceTo: priceTo == _unset ? this.priceTo : priceTo as int?,
        sortField: sortField ?? this.sortField,
        sortAscending: sortAscending ?? this.sortAscending,
        page: page ?? 1,
        size: size ?? this.size,
        includeDeleted: includeDeleted ?? this.includeDeleted,
      );
  bool get hasActiveFilters =>
      search.isNotEmpty ||
      category != null ||
      hallId != null ||
      quantityFrom != null ||
      quantityTo != null ||
      priceFrom != null ||
      priceTo != null ||
      includeDeleted;
}
