import 'package:dio/dio.dart';

import '../models/hall_query.dart';
import '../models/page_result.dart';
import '../models/photographer_query.dart';
import '../models/studio_hall.dart';
import '../models/photographer.dart';
import '../repositories/hall_repository.dart';
import '../repositories/photographer_repository.dart';
import 'list_notifier.dart';

/// Состояние списка залов студии.
///
/// Данные приходят с сервера: поиск, фильтры, сортировка и номер
/// страницы уходят в запрос, клиент держит только текущую страницу.
class HallListNotifier extends ListNotifier<StudioHall> {
  HallListNotifier(this._repo);
  final HallRepository _repo;
  HallQuery _query = const HallQuery();
  HallQuery get query => _query;

  @override
  Future<PageResult<StudioHall>> fetch(CancelToken cancelToken) =>
      _repo.find(_query, cancelToken: cancelToken);

  @override
  Future<void> applyQuery(Object query) async {
    _query = query as HallQuery;
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

/// Состояние списка фотографов.
class PhotographerListNotifier extends ListNotifier<Photographer> {
  PhotographerListNotifier(this._repo);
  final PhotographerRepository _repo;
  PhotographerQuery _query = const PhotographerQuery();
  PhotographerQuery get query => _query;

  @override
  Future<PageResult<Photographer>> fetch(CancelToken cancelToken) =>
      _repo.find(_query, cancelToken: cancelToken);

  @override
  Future<void> applyQuery(Object query) async {
    _query = query as PhotographerQuery;
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
