import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/api_exceptions.dart';
import '../models/page_result.dart';

/// Общая часть репозитория, работающего поверх REST API.
///
/// Здесь собрано то, что одинаково у всех сущностей: разбор страницы,
/// отправка запросов, отмена устаревших запросов и повтор при сетевом сбое.
///
/// Наследники реализуют только предметную часть: путь коллекции,
/// разбор одной записи, построение тела запроса и перевод условий
/// отбора в параметры запроса.
abstract class ApiRepository<T, Q> {
  ApiRepository(this.dio);

  /// HTTP-клиент. Открыт, чтобы наследники могли отправлять
  /// нестандартные запросы — например, отмену бронирования.
  final Dio dio;

  /// Путь коллекции, например `/halls`.
  String get collectionPath;

  /// Разбирает одну запись из ответа сервера.
  T fromJson(Map<String, dynamic> json);

  /// Тело запроса для создания и изменения записи.
  Map<String, dynamic> toRequestBody(T item);

  /// Переводит условия отбора в параметры запроса.
  ///
  /// Поиск, фильтры, сортировка и номер страницы уходят на сервер —
  /// клиент держит только текущую страницу.
  Map<String, dynamic> toParameters(Q query);

  /// Сколько записей показывать на странице по умолчанию.
  int get defaultSize;

  /// Разбор ответа с постраничным списком.
  PageResult<T> parsePage(
    Map<String, dynamic> data, {
    required int fallbackSize,
  }) {
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().map(fromJson).toList()
        : <T>[];
    return PageResult(
      items: items,
      page: _asInt(data['page']) ?? 1,
      size: _asInt(data['size']) ?? fallbackSize,
      total: _asInt(data['total']) ?? items.length,
    );
  }

  /// Читает страницу записей по условиям отбора.
  ///
  /// [cancelToken] передаётся вызывающим: токен отмены принадлежит
  /// экрану, а не репозиторию. Репозиторий один на всё приложение, а
  /// экранов и справочников несколько, и общее поле токена приводило к
  /// тому, что запрос справочника отменялся запросом списка.
  ///
  /// Если [cancelToken] задан, предыдущий запрос с этим же токеном
  /// отменяется — так список не получает устаревший ответ.
  Future<PageResult<T>> find(
    Q query, {
    CancelToken? cancelToken,
  }) async {
    final parameters = toParameters(query);
    final size = _asInt(parameters['size']) ?? defaultSize;

    final response = await withRetry(
      () => guard(
        () => dio.get<Map<String, dynamic>>(
          collectionPath,
          queryParameters: {
            ..._clean(parameters),
            if (apiDemoDelayMs > 0) '__delay': apiDemoDelayMs,
            if (apiDemoFail > 0) '__fail': apiDemoFail,
          },
          cancelToken: cancelToken,
        ),
      ),
    );
    return parsePage(
      response.data ?? const <String, dynamic>{},
      fallbackSize: size,
    );
  }

  /// Читает одну запись по идентификатору.
  Future<T> findById(int id) async {
    final response = await withRetry(
      () => guard(
        () => dio.get<Map<String, dynamic>>('$collectionPath/$id'),
      ),
    );
    return fromJson(response.data ?? const <String, dynamic>{});
  }

  /// Создаёт запись.
  Future<T> create(T item) async {
    final response = await guard(
      () => dio.post<Map<String, dynamic>>(
        collectionPath,
        data: toRequestBody(item),
      ),
    );
    return fromJson(response.data ?? const <String, dynamic>{});
  }

  /// Изменяет запись.
  Future<T> update(int id, T item) async {
    final response = await guard(
      () => dio.put<Map<String, dynamic>>(
        '$collectionPath/$id',
        data: toRequestBody(item),
      ),
    );
    return fromJson(response.data ?? const <String, dynamic>{});
  }

  /// Помечает запись удалённой.
  Future<void> softDelete(int id) async {
    await guard(() => dio.delete<void>('$collectionPath/$id'));
  }

  /// Удаляет запись физически.
  Future<void> hardDelete(int id) async {
    await guard(
      () => dio.delete<void>(
        '$collectionPath/$id',
        queryParameters: {'hard': 'true'},
      ),
    );
  }

  /// Восстанавливает запись.
  Future<T> restore(int id) async {
    final response = await guard(
      () => dio.post<Map<String, dynamic>>('$collectionPath/$id/restore'),
    );
    return fromJson(response.data ?? const <String, dynamic>{});
  }

  /// Помечает удалёнными несколько записей. Возвращает их количество.
  Future<int> softDeleteMany(List<int> ids) async {
    final response = await guard(
      () => dio.post<Map<String, dynamic>>(
        '$collectionPath/bulk-delete',
        data: {'ids': ids},
      ),
    );
    return _asInt(response.data?['deleted']) ?? 0;
  }

  /// Удаляет физически несколько записей.
  ///
  /// Сервер сначала проверяет зависимости всего набора, затем удаляет
  /// записи одним запросом.
  Future<int> hardDeleteMany(List<int> ids) async {
    final response = await guard(() => dio.post<Map<String, dynamic>>(
          '$collectionPath/bulk-delete',
          queryParameters: {'hard': true},
          data: {'ids': ids},
        ));
    return _asInt(response.data?['deleted']) ?? 0;
  }

  /// Читает все записи без постраничного вывода.
  ///
  /// Нужно для справочников: список залов и фотографов клиент запрашивает
  /// один раз и держит у себя.
  ///
  /// Условия отбора для этого запроса задаёт [allQuery].
  Future<List<T>> all({bool includeDeleted = false}) async {
    final parameters = toParameters(allQuery(includeDeleted: includeDeleted));
    final items = <T>[];
    var page = 1;
    while (true) {
      final response =
          await withRetry(() => guard(() => dio.get<Map<String, dynamic>>(
                collectionPath,
                queryParameters: {..._clean(parameters), 'page': page},
              )));
      final result = parsePage(response.data ?? {}, fallbackSize: 100);
      items.addAll(result.items);
      if (items.length >= result.total || result.items.isEmpty) return items;
      page++;
    }
  }

  /// Условия отбора для запроса «прочитать всё».
  Q allQuery({bool includeDeleted = false});

  /// Убирает из параметров пустые значения, чтобы в адрес не попадали
  /// пустые строки и нули там, где фильтр не задан.
  static Map<String, dynamic> _clean(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    source.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      result[key] = value;
    });
    return result;
  }

  static int? _asInt(Object? value) => switch (value) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v),
        _ => null,
      };
}
