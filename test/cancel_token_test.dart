import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_studio_portal/core/api_exceptions.dart';
import 'package:photo_studio_portal/models/hall_query.dart';
import 'package:photo_studio_portal/repositories/api_hall_repository.dart';
import 'package:photo_studio_portal/state/list_notifiers.dart';

/// Подменённый обработчик запросов: отвечает по задержке.
class _DelayedAdapter implements HttpClientAdapter {
  _DelayedAdapter(this.delay);

  /// Задержка ответа в миллисекундах.
  final int delay;

  /// Все запросы.
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (delay > 0) {
      await Future<void>.delayed(Duration(milliseconds: delay));
    }
    // Если запрос отменили, пока он ждал, — не отвечаем.
    if (options.cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'items': [
          {
            'id': 1,
            'name': 'Белая циклорама',
            'code': 'A-01',
            'style': 'Циклорама',
            'capacity': 8,
            'hourlyRate': 2500,
            'description': '',
            'equipmentIds': [1],
            'photographerIds': [1],
            'createdAt': '2026-08-01T09:00:00Z',
            'deletedAt': null,
          },
        ],
        'page': 1,
        'size': 10,
        'total': 1,
        'totalPages': 1,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_DelayedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    InterceptorsWrapper(
      onResponse: (response, handler) {
        final status = response.statusCode ?? 0;
        if (status >= 400) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
    ),
  );
  return dio;
}

void main() {
  group('отмена устаревших запросов', () {
    test('новый запрос отменяет предыдущий', () async {
      final adapter = _DelayedAdapter(400);
      final repository = ApiHallRepository(_dioWith(adapter));
      final notifier = HallListNotifier(repository);

      // Первый запрос уходит в полёт.
      final first = notifier.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Второй запрос отменяет первый.
      final second = notifier.load();
      await Future.wait([first, second]);

      expect(adapter.requests, hasLength(2));
      // Отменён ровно один — устаревший.
      final cancelled =
          adapter.requests.where((r) => r.cancelToken?.isCancelled ?? false);
      expect(cancelled, hasLength(1));
    });

    test('после отмены приходит новый результат, а не ошибка', () async {
      final adapter = _DelayedAdapter(400);
      final repository = ApiHallRepository(_dioWith(adapter));
      final notifier = HallListNotifier(repository);

      final first = notifier.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final second = notifier.load();
      await Future.wait([first, second]);

      // Экран в состоянии успеха, а не ошибки.
      expect(notifier.status.name, 'success');
      expect(notifier.error, isNull);
      expect(notifier.result.items, hasLength(1));
    });

    test('запросы разных экранов не отменяют друг друга', () async {
      // Справочник и список пользуются одним репозиторием. Раньше токен
      // отмены хранился в репозитории, и запрос справочника отменялся
      // запросом списка — справочники оставались пустыми.
      final adapter = _DelayedAdapter(200);
      final repository = ApiHallRepository(_dioWith(adapter));

      final listNotifier = HallListNotifier(repository);
      final catalogToken = CancelToken();

      final listFuture = listNotifier.load();
      final catalogFuture = repository.find(const HallQuery(size: 100),
          cancelToken: catalogToken);

      await Future.wait([listFuture, catalogFuture]);

      expect(catalogToken.isCancelled, isFalse);
      expect(adapter.requests, hasLength(2));
    });
  });
}
