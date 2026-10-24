import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_studio_portal/core/api_exceptions.dart';
import 'package:photo_studio_portal/state/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Подменённый обработчик запросов.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.responder);

  final Future<ResponseBody> Function(RequestOptions options) responder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      responder(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object payload) => ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Dio _dioWith(_StubAdapter adapter) {
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
  group('сессия', () {
    test('гость без входа имеет права клиента', () {
      final session = SessionStore();
      expect(session.isAuthenticated, isFalse);
      expect(session.permissions.isGuest, isTrue);
      expect(session.permissions.canRead, isTrue);
      expect(session.permissions.canCreate, isFalse);
    });

    test('пока токен не проверен, состояние неизвестно', () {
      // Иначе при каждой перезагрузке страницы человека будет на долю
      // секунды выбрасывать на экран входа.
      final session = SessionStore();
      expect(session.status, AuthStatus.unknown);
      expect(session.isKnown, isFalse);
    });

    test('после входа состояние известно', () async {
      final session = SessionStore();
      session.setUser(const AppUser(
        id: 1,
        username: 'manager',
        fullName: 'Руководитель смены',
        email: 'manager@focusframe.local',
        role: 'manager',
      ));
      expect(session.status, AuthStatus.signedIn);
      expect(session.isKnown, isTrue);
      expect(session.isAuthenticated, isTrue);
    });

    test('после выхода состояние известно и сессия закрыта', () {
      final session = SessionStore();
      session.setUser(const AppUser(
        id: 1,
        username: 'manager',
        fullName: 'Руководитель смены',
        email: 'manager@focusframe.local',
        role: 'manager',
      ));
      session.clear();
      expect(session.status, AuthStatus.signedOut);
      expect(session.isKnown, isTrue);
      expect(session.isAuthenticated, isFalse);
      expect(session.permissions.isGuest, isTrue);
    });

    test('профиль восстанавливается по сохранённому токену', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final session = SessionStore();
      await session.restore(prefs);
      session.setToken('токен');
      await session.persist(prefs);

      // Читаем токен заново — как это делает приложение при запуске.
      final restored = SessionStore();
      await restored.restore(await SharedPreferences.getInstance());
      expect(restored.token, 'токен');

      final dio = _dioWith(
        _StubAdapter((_) async => _json(200, {
              'id': 1,
              'username': 'admin',
              'fullName': 'Администратор студии',
              'email': 'admin@focusframe.local',
              'role': 'admin',
            })),
      );
      final ok = await restored.restoreUser(AuthRepository(dio));

      expect(ok, isTrue);
      expect(restored.user?.role, 'admin');
      // Роль восстановлена — права администратора.
      expect(restored.permissions.canCreate, isTrue);
      expect(restored.permissions.canHardDelete, isTrue);
      expect(restored.permissions.isGuest, isFalse);
    });

    test('протухший токен завершает сессию', () async {
      final session = SessionStore();
      session.setToken('протухший');

      final dio = _dioWith(
        _StubAdapter(
          (_) async => _json(401, {'message': 'Требуется аутентификация'}),
        ),
      );
      final ok = await session.restoreUser(AuthRepository(dio));

      expect(ok, isFalse);
      expect(session.token, isNull);
      expect(session.user, isNull);
      expect(session.permissions.isGuest, isTrue);
    });

    test('недоступный сервер не сбрасывает сессию', () async {
      final session = SessionStore();
      session.setToken('токен');

      final dio = _dioWith(
        _StubAdapter((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }),
      );
      final ok = await session.restoreUser(AuthRepository(dio));

      expect(ok, isFalse);
      // Токен сохранён: при следующем запуске профиль восстановится.
      expect(session.token, 'токен');
      // Профиль восстановить не удалось, поэтому человек считается гостем.
      expect(session.user, isNull);
      expect(session.permissions.isGuest, isTrue);
      // Но состояние сессии уже известно: роутер не будет ждать.
      expect(session.isKnown, isTrue);
    });
  });
}
