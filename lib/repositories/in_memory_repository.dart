import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage.dart';
import '../models/page_result.dart';

abstract class InMemoryRepository<T> {
  InMemoryRepository({
    required SharedPreferences prefs,
    required this.name,
    required T Function(Map<String, dynamic>) parse,
    required this.encode,
    required List<Map<String, dynamic>> seed,
    Map<String, dynamic> Function(Map<String, dynamic> json)? migrate,
  }) : _prefs = prefs {
    Map<String, dynamic> toJson(Map<String, dynamic> json) =>
        encode(parse(json));
    final result = VersionedStore.read(
      prefs,
      name,
      parse: toJson,
      migrate: migrate ?? toJson,
      seed: seed,
    );
    _items = result.items.map(parse).toList();
  }
  final String name;
  final Map<String, dynamic> Function(T item) encode;
  final SharedPreferences _prefs;
  late List<T> _items;
  List<T> get items => List.unmodifiable(_items);
  Future<T?> findById(int id) async =>
      _items.where((item) => rowId(item) == id).firstOrNull;
  Future<List<T>> all({bool includeDeleted = false}) async => List.unmodifiable(
      _items.where((item) => includeDeleted || !rowDeleted(item)).toList());
  Future<void> Function(List<int> ids, bool hard)? deletionGuard;
  Future<void> Function(T item)? saveGuard;
  Future<void> Function()? afterChange;
  Future<void> checkDeletion(List<int> ids, {bool hard = false}) async {
    await deletionGuard?.call(ids, hard);
  }

  Future<void> persist() async {
    await VersionedStore.write(_prefs, name, _items.map(rowJson).toList());
    await afterChange?.call();
  }

  int nextId() =>
      _items.fold<int>(
          0, (maxId, item) => rowId(item) > maxId ? rowId(item) : maxId) +
      1;
  void put(T item) {
    final index = _items.indexWhere((row) => rowId(row) == rowId(item));
    final T? previous = index < 0 ? null : _items[index];
    if (index < 0) {
      _items.add(item);
    } else {
      _items[index] = item;
    }
    onAfterPut(item, previous);
  }

  void onAfterPut(T item, T? previous) {}
  void replace(T item) {
    final index = _items.indexWhere((row) => rowId(row) == rowId(item));
    if (index < 0) {
      _items.add(item);
    } else {
      _items[index] = item;
    }
  }

  void markDeleted(int id) {
    final index = _indexOf(id);
    _items[index] = rowWithDeletedAt(_items[index], DateTime.now());
  }

  void markRestored(int id) {
    final index = _indexOf(id);
    _items[index] = rowWithDeletedAt(_items[index], null);
  }

  void remove(int id) {
    final index = _items.indexWhere((row) => rowId(row) == id);
    if (index < 0) return;
    final item = _items[index];
    onBeforeRemove(item);
    _items.removeAt(index);
  }

  void onBeforeRemove(T item) {}
  PageResult<T> page({
    required int pageNumber,
    required int pageSize,
    required List<T> Function(List<T> rows) filter,
  }) {
    final rows = filter(_items.toList());
    final total = rows.length;
    final from = (pageNumber - 1) * pageSize;
    final to = (from + pageSize) > total ? total : from + pageSize;
    return PageResult(
      items: from >= total ? <T>[] : rows.sublist(from, to),
      page: pageNumber,
      size: pageSize,
      total: total,
    );
  }

  int _indexOf(int id) {
    final index = _items.indexWhere((row) => rowId(row) == id);
    if (index < 0) throw StateError('Запись #$id не найдена');
    return index;
  }

  int rowId(T item);
  bool rowDeleted(T item);
  Map<String, dynamic> rowJson(T item) => encode(item);
  T rowWithDeletedAt(T item, DateTime? deletedAt);
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
