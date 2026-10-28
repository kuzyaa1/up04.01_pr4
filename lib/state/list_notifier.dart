import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';

/// Состояния экрана со списком.
///
/// Как только данные приходят извне, у экрана появляется не одно
/// состояние, а четыре: идёт загрузка, данные получены, данных нет,
/// произошла ошибка. Обрабатывать нужно все четыре.
enum LoadStatus { idle, loading, success, error }

/// Общее состояние списка.
///
/// Экраны не знают о Dio: наружу выходят только исключения предметной
/// области, поэтому [error] всегда содержит текст для пользователя.
abstract class ListNotifier<T> extends ChangeNotifier {
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  PageResult<T> _result = PageResult.empty();
  final Set<int> _selected = {};
  bool _disposed = false;
  Future<void> Function()? onMutation;

  /// Токен отмены текущего запроса.
  ///
  /// Принадлежит экрану, а не репозиторию: репозиторий один на всё
  /// приложение, а экранов несколько. Когда пользователь меняет условия
  /// отбора, предыдущий запрос отменяется — иначе на экране может
  /// оказаться результат по устаревшему запросу.
  CancelToken? _cancelToken;

  LoadStatus get status => _status;
  String? get error => _error;
  PageResult<T> get result => _result;
  Set<int> get selected => Set.unmodifiable(_selected);
  List<int> get selectedIds => _selected.toList();
  bool get hasSelection => _selected.isNotEmpty;

  /// Отменяет текущий запрос, если он ещё выполняется.
  void cancelPending() {
    final token = _cancelToken;
    if (token != null && !token.isCancelled) {
      token.cancel('Запрос устарел');
    }
    _cancelToken = null;
  }

  Future<void> applyQuery(Object query) async {
    clearSelection();
    await load();
  }

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();

    // Новый запрос отменяет предыдущий: пока пользователь набирает
    // текст в поиске, уходит несколько запросов, и ответ на «во» может
    // прийти позже ответа на «война».
    cancelPending();
    final token = CancelToken();
    _cancelToken = token;

    try {
      final result = await fetch(token);
      if (_disposed || token.isCancelled || !identical(token, _cancelToken)) {
        return;
      }
      _result = result;
      _status = LoadStatus.success;
    } on CancelledException {
      // Запрос отменён: он устарел, потому что пользователь уже изменил
      // условия отбора. Показывать ошибку не нужно — придёт новый ответ.
      return;
    } on Object catch (error) {
      if (_disposed || token.isCancelled || !identical(token, _cancelToken)) {
        return;
      }
      _error = describeError(error);
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  /// Загружает страницу данных.
  ///
  /// [cancelToken] передаётся репозиторию, чтобы запрос можно было
  /// отменить при смене условий отбора.
  Future<PageResult<T>> fetch(CancelToken cancelToken);

  void toggle(int id) {
    if (!_selected.remove(id)) _selected.add(id);
    _safeNotify();
  }

  void clearSelection() {
    _selected.clear();
    _safeNotify();
  }

  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<void> deleteSelected();
  Future<void> eraseSelected();

  /// Текст ошибки для пользователя.
  ///
  /// Исключения предметной области уже несут готовый текст, поэтому
  /// для них используется [toString]. Прочие ошибки показываются
  /// вместе с типом, чтобы их можно было отличить.
  static String describeError(Object error) {
    final text = error.toString();
    return text.isEmpty ? 'Неизвестная ошибка' : text;
  }

  @override
  void dispose() {
    _disposed = true;
    cancelPending();
    super.dispose();
  }

  /// `notifyListeners` после закрытия экрана приводит к падению,
  /// поэтому уведомление проверяется.
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}
