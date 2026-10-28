import 'package:dio/dio.dart';

import '../models/booking.dart';
import '../models/booking_query.dart';
import '../models/client.dart';
import '../models/client_query.dart';
import '../models/equipment.dart';
import '../models/equipment_query.dart';
import '../models/page_result.dart';
import '../repositories/booking_repository.dart';
import '../repositories/client_repository.dart';
import '../repositories/equipment_repository.dart';
import 'list_notifier.dart';

/// Состояние списка бронирований.
class BookingListNotifier extends ListNotifier<Booking> {
  BookingListNotifier(this._repo);
  final BookingRepository _repo;
  BookingQuery _query = const BookingQuery();
  BookingQuery get query => _query;

  @override
  Future<PageResult<Booking>> fetch(CancelToken cancelToken) =>
      _repo.find(_query, cancelToken: cancelToken);

  @override
  Future<void> applyQuery(Object query) async {
    _query = query as BookingQuery;
    clearSelection();
    await load();
  }

  @override
  Future<void> softDelete(int id) async {
    await _repo.softDelete(id);
    await onMutation?.call();
    await load();
  }

  @override
  Future<void> hardDelete(int id) async {
    await _repo.hardDelete(id);
    await onMutation?.call();
    await load();
  }

  @override
  Future<void> restore(int id) async {
    await _repo.restore(id);
    await onMutation?.call();
    await load();
  }

  @override
  Future<void> deleteSelected() async {
    await _repo.softDeleteMany(selectedIds);
    await onMutation?.call();
    clearSelection();
    await load();
  }

  @override
  Future<void> eraseSelected() async {
    await _repo.hardDeleteMany(selectedIds);
    await onMutation?.call();
    clearSelection();
    await load();
  }

  /// Отменяет бронирование.
  ///
  /// Сервер отвечает 409, если бронирование уже закрыто — приложение
  /// показывает это понятным сообщением.
  Future<void> cancel(int id) async {
    await _repo.cancel(id);
    await onMutation?.call();
    await load();
  }

  /// Завершает бронирование.
  Future<void> complete(int id) async {
    await _repo.complete(id);
    await onMutation?.call();
    await load();
  }
}

/// Состояние списка клиентов.
class ClientListNotifier extends ListNotifier<Client> {
  ClientListNotifier(this._repo);
  final ClientRepository _repo;
  ClientQuery _query = const ClientQuery();
  ClientQuery get query => _query;

  @override
  Future<PageResult<Client>> fetch(CancelToken cancelToken) =>
      _repo.find(_query, cancelToken: cancelToken);

  @override
  Future<void> applyQuery(Object query) async {
    _query = query as ClientQuery;
    clearSelection();
    await load();
  }

  @override
  Future<void> softDelete(int id) async {
    await _repo.softDelete(id);
    await onMutation?.call();
    await load();
  }

  @override
  Future<void> hardDelete(int id) async {
    await _repo.hardDelete(id);
    await onMutation?.call();
    await load();
  }

  @override
  Future<void> restore(int id) async {
    await _repo.restore(id);
    await onMutation?.call();
    await load();
  }

  @override
  Future<void> deleteSelected() async {
    await _repo.softDeleteMany(selectedIds);
    await onMutation?.call();
    clearSelection();
    await load();
  }

  @override
  Future<void> eraseSelected() async {
    await _repo.hardDeleteMany(selectedIds);
    await onMutation?.call();
    clearSelection();
    await load();
  }
}

/// Состояние списка оборудования.
class EquipmentListNotifier extends ListNotifier<Equipment> {
  EquipmentListNotifier(this._repo);
  final EquipmentRepository _repo;
  EquipmentQuery _query = const EquipmentQuery();
  EquipmentQuery get query => _query;

  @override
  Future<PageResult<Equipment>> fetch(CancelToken cancelToken) =>
      _repo.find(_query, cancelToken: cancelToken);

  @override
  Future<void> applyQuery(Object query) async {
    _query = query as EquipmentQuery;
    clearSelection();
    await load();
  }

  @override
  Future<void> softDelete(int id) async {
    await _repo.softDelete(id);
    await onMutation?.call();
    await load();
  }

  @override
  Future<void> hardDelete(int id) async {
    await _repo.hardDelete(id);
    await onMutation?.call();
    await load();
  }

  @override
  Future<void> restore(int id) async {
    await _repo.restore(id);
    await onMutation?.call();
    await load();
  }

  @override
  Future<void> deleteSelected() async {
    await _repo.softDeleteMany(selectedIds);
    await onMutation?.call();
    clearSelection();
    await load();
  }

  @override
  Future<void> eraseSelected() async {
    await _repo.hardDeleteMany(selectedIds);
    await onMutation?.call();
    clearSelection();
    await load();
  }
}
