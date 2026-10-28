import 'package:flutter/foundation.dart';

import '../models/booking.dart';
import '../models/booking_query.dart';
import '../models/client.dart';
import '../models/client_query.dart';
import '../models/equipment.dart';
import '../models/equipment_query.dart';
import '../models/hall_query.dart';
import '../models/page_result.dart';
import '../models/photographer.dart';
import '../models/photographer_query.dart';
import '../models/studio_hall.dart';
import '../repositories/booking_repository.dart';
import '../repositories/client_repository.dart';
import '../repositories/equipment_repository.dart';
import '../repositories/hall_repository.dart';
import '../repositories/photographer_repository.dart';
import 'list_notifier.dart';

/// Справочники приложения: залы, фотографы, клиенты, типы съёмки.
///
/// Справочники запрашиваются у сервера один раз и держатся в памяти —
/// при каждом открытии формы список заново не запрашивается.
class CatalogNotifier extends ChangeNotifier {
  CatalogNotifier({
    required HallRepository halls,
    required PhotographerRepository photographers,
    required ClientRepository clients,
    required BookingRepository bookings,
    required EquipmentRepository equipment,
    this.includeClients = true,
  })  : _halls = halls,
        _photographers = photographers,
        _clients = clients,
        _bookings = bookings,
        _equipment = equipment;

  final bool includeClients;
  final HallRepository _halls;
  final PhotographerRepository _photographers;
  final ClientRepository _clients;
  final BookingRepository _bookings;
  final EquipmentRepository _equipment;

  List<StudioHall> _hallOptions = [];
  List<Photographer> _photographerOptions = [];
  List<Client> _clientOptions = [];
  List<Equipment> _equipmentOptions = [];
  List<String> _shootingTypes = [];
  bool _disposed = false;
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool _loaded = false;
  bool _loading = false;
  String? _error;
  DateTime? _loadedAt;
  Future<void>? _pending;

  List<StudioHall> get halls => List.unmodifiable(_hallOptions);
  List<Photographer> get photographers =>
      List.unmodifiable(_photographerOptions);
  List<Client> get clients => List.unmodifiable(_clientOptions);
  List<Equipment> get equipment => List.unmodifiable(_equipmentOptions);
  List<String> get shootingTypes => List.unmodifiable(_shootingTypes);
  bool get loaded => _loaded;
  bool get loading => _loading;
  String? get error => _error;

  /// Когда справочники были загружены в последний раз.
  DateTime? get loadedAt => _loadedAt;

  /// Загружает справочники с сервера.
  ///
  /// Повторный вызов до истечения [refetchAfter] ничего не делает:
  /// справочник считается актуальным.
  Future<void> load(
      {bool force = false,
      Duration refetchAfter = const Duration(minutes: 5)}) {
    return _pending ??= _load(force: force, refetchAfter: refetchAfter)
        .whenComplete(() => _pending = null);
  }

  Future<PageResult<T>> _allPages<T, Q>(Q query, Q Function(int page) next,
      Future<PageResult<T>> Function(Q) fetch) async {
    var result = await fetch(query);
    final items = <T>[...result.items];
    while (items.length < result.total && result.items.isNotEmpty) {
      result = await fetch(next(result.page + 1));
      items.addAll(result.items);
    }
    return PageResult(
        items: items, page: 1, size: items.length, total: result.total);
  }

  Future<void> _load(
      {bool force = false,
      Duration refetchAfter = const Duration(minutes: 5)}) async {
    await Future<void>.value();
    final loadedAt = _loadedAt;
    if (!force &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < refetchAfter) {
      return;
    }
    if (_loading) return;
    _loading = true;
    _error = null;
    _safeNotify();
    try {
      // Запросы не зависят друг от друга, поэтому уходят разом, а не по
      // очереди. На справочниках в памяти разницы не видно, а вот на
      // сервере последовательные запросы сложатся в заметную задержку.
      final results = await Future.wait<PageResult<dynamic>>([
        _allPages<StudioHall, HallQuery>(const HallQuery(size: 100),
            (p) => HallQuery(size: 100, page: p), (q) => _halls.find(q)),
        _allPages<Photographer, PhotographerQuery>(
            const PhotographerQuery(size: 100),
            (p) => PhotographerQuery(size: 100, page: p),
            (q) => _photographers.find(q)),
        if (includeClients)
          _allPages<Client, ClientQuery>(const ClientQuery(size: 100),
              (p) => ClientQuery(size: 100, page: p), (q) => _clients.find(q))
        else
          Future.value(PageResult<Client>.empty()),
        _allPages<Equipment, EquipmentQuery>(
            const EquipmentQuery(size: 100),
            (p) => EquipmentQuery(size: 100, page: p),
            (q) => _equipment.find(q)),
        _allPages<Booking, BookingQuery>(const BookingQuery(size: 100),
            (p) => BookingQuery(size: 100, page: p), (q) => _bookings.find(q)),
      ]);

      _hallOptions = (results[0] as PageResult<StudioHall>).items;
      _photographerOptions = (results[1] as PageResult<Photographer>)
          .items
          .where((item) => !item.isDeleted)
          .toList();
      _clientOptions = (results[2] as PageResult<Client>)
          .items
          .where((item) => !item.isDeleted)
          .toList();
      _equipmentOptions = (results[3] as PageResult<Equipment>)
          .items
          .where((item) => !item.isDeleted)
          .toList();
      _shootingTypes = (results[4] as PageResult<Booking>)
          .items
          .map((booking) => booking.shootingType.trim())
          .where((text) => text.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      _loaded = true;
      _loadedAt = DateTime.now();
    } on Object catch (error) {
      _error = ListNotifier.describeError(error);
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  /// Сбрасывает кэш справочников — следующая загрузка пойдёт на сервер.
  void invalidate() {
    _loadedAt = null;
  }

  String hallName(int id) {
    for (final hall in _hallOptions) {
      if (hall.id == id) return hall.name;
    }
    return 'Зал #$id';
  }

  String photographerName(int id) {
    for (final item in _photographerOptions) {
      if (item.id == id) return item.fullName;
    }
    return 'Фотограф #$id';
  }

  String clientName(int id) {
    for (final client in _clientOptions) {
      if (client.id == id) return client.name;
    }
    return 'Клиент #$id';
  }

  String hallCode(int id) {
    for (final hall in _hallOptions) {
      if (hall.id == id) return hall.code;
    }
    return '';
  }

  List<String> get hallStyles {
    final values = _hallOptions
        .map((hall) => hall.style)
        .where((style) => style.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<String> get specializations {
    final values = _photographerOptions
        .map((item) => item.specialization)
        .where((text) => text.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<String> get clientTypes => Client.clientTypes;

  /// Категории оборудования — из кэшированного справочника.
  List<String> get equipmentCategories {
    final values = _equipmentOptions
        .map((item) => item.category)
        .where((text) => text.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }
}
