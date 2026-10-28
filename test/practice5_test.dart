import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_studio_portal/core/api_client.dart';
import 'package:photo_studio_portal/core/api_exceptions.dart';
import 'package:photo_studio_portal/core/permissions.dart';
import 'package:photo_studio_portal/core/router.dart';
import 'package:photo_studio_portal/screens/register_screen.dart';
import 'package:photo_studio_portal/state/session.dart';
import 'package:photo_studio_portal/widgets/session_watcher.dart';

const client = AppUser(
    id: 1,
    username: 'client',
    fullName: 'Клиент',
    email: 'client@example.com',
    role: 'client');
Map<String, dynamic> tokens() => {
      'accessToken': 'fresh',
      'refreshToken': 'refresh2',
      'user': {
        'id': 1,
        'username': 'client',
        'fullName': 'Клиент',
        'email': 'client@example.com',
        'role': 'client'
      }
    };
ResponseBody jsonBody(int status, Object data) =>
    ResponseBody.fromString(jsonEncode(data), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class Adapter implements HttpClientAdapter {
  Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? s, Future<void>? cancel) {
    requests.add(o);
    return respond(o);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final role in UserRole.values) {
    test('доступ к отдельным экранам: ${role.name}', () {
      final p = Permissions(role);
      expect(isRouteAllowed('/my-bookings', p), role == UserRole.client);
      expect(isRouteAllowed('/manager', p), role == UserRole.manager);
      expect(isRouteAllowed('/admin/users', p), role == UserRole.admin);
      expect(isRouteAllowed('/admin/statistics', p), role == UserRole.admin);
      expect(isRouteAllowed('/bookings/new', p),
          role.canManage || role == UserRole.client);
      expect(isRouteAllowed('/my-bookings/new', p), role == UserRole.client);
      for (final collection in ['halls', 'photographers', 'equipment']) {
        expect(isRouteAllowed('/$collection/new', p), role == UserRole.admin);
        expect(
            isRouteAllowed('/$collection/1/edit', p), role == UserRole.admin);
        expect(p.canManageEntity(collection), role == UserRole.admin);
      }
      expect(isRouteAllowed('/bookings/1/edit', p), role.canManage);
      expect(isRouteAllowed('/clients', p), role.canManage);
    });
  }
  test('гость не допускается ни на один внутренний экран', () {
    for (final path in [
      '/',
      '/halls',
      '/halls/1',
      '/bookings',
      '/manager',
      '/admin/users'
    ]) {
      expect(isRouteAllowed(path, const Permissions.guest()), isFalse);
    }
  });
  test('from сохраняет карточку и параметры и отвергает внешний адрес', () {
    expect(safeReturnLocation('/halls/12?tab=info'), '/halls/12?tab=info');
    for (final path in [
      'https://example.com',
      '//example.com',
      '/login',
      '/register',
      ''
    ]) {
      expect(safeReturnLocation(path), '/');
    }
  });
  test('пароль требует длину, цифру и специальный символ', () {
    for (final value in ['', '123!', 'abcdefgh!', 'abcdefgh1']) {
      expect(registrationPasswordError(value), isNotNull);
    }
    expect(registrationPasswordError('Photo123!'), isNull);
  });
  testWidgets('проверка пароля регистрации срабатывает при вводе',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Пароль'), 'abcdefgh1');
    await tester.pump();
    expect(find.text('Добавьте специальный символ'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Пароль'), 'Photo123!');
    await tester.pump();
    expect(find.text('Добавьте специальный символ'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
  });
  testWidgets('ручной адрес гостя ведёт на вход, чужая роль — на отказ',
      (tester) async {
    final session = SessionStore()..setUser(null);
    final router = createRouter(session);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: session, child: MaterialApp.router(routerConfig: router)));
    router.go('/admin/users');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(router.routeInformationProvider.value.uri.queryParameters['from'],
        '/admin/users');
    session.setUser(client);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/forbidden');
    expect(find.text('Недостаточно прав'), findsWidgets);
    session.clear();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    session.dispose();
  });
  test('предупреждение за 30 секунд, действие продлевает только неактивность',
      () async {
    var now = DateTime(2026, 10, 28);
    final session = SessionStore(clock: () => now)..setUser(client);
    now = now.add(const Duration(seconds: 150));
    await session.checkLimits();
    expect(session.inactivityWarning, isTrue);
    expect(session.secondsRemaining, 30);
    session.recordActivity();
    expect(session.inactivityWarning, isFalse);
    now = now.add(const Duration(seconds: 180));
    await session.checkLimits();
    expect(session.isAuthenticated, isFalse);
    expect(session.notice, contains('неактивности'));
  });
  test('общая длительность ограничена независимо от активности', () async {
    var now = DateTime(2026);
    final session = SessionStore(
        clock: () => now, maximumDuration: const Duration(seconds: 200))
      ..setUser(client);
    now = now.add(const Duration(seconds: 170));
    session.recordActivity();
    now = now.add(const Duration(seconds: 31));
    await session.checkLimits();
    expect(session.isAuthenticated, isFalse);
    expect(session.notice, contains('Время сессии'));
  });
  test('перезагрузка не обнуляет время неактивности', () async {
    var now = DateTime(2026);
    final prefs = await SharedPreferences.getInstance();
    final session = SessionStore(clock: () => now);
    await session.restore(prefs);
    session.setToken('old');
    session.setUser(client);
    await session.persist(prefs);
    now = now.add(const Duration(minutes: 3));
    final restored = SessionStore(clock: () => now);
    await restored.restore(prefs);
    expect(restored.token, isNull);
    expect(prefs.getString(SessionStore.tokenKey), isNull);
  });
  testWidgets('глобальная клавиатура сбрасывает предупреждение в поле формы',
      (tester) async {
    var now = DateTime(2026);
    final session = SessionStore(clock: () => now)..setUser(client);
    await tester.pumpWidget(MaterialApp(
        home: SessionWatcher(
            session: session, child: const Scaffold(body: TextField()))));
    now = now.add(const Duration(seconds: 151));
    await session.checkLimits();
    expect(session.inactivityWarning, isTrue);
    await tester.tap(find.byType(TextField));
    now = now.add(const Duration(seconds: 151));
    await session.checkLimits();
    expect(session.inactivityWarning, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(session.inactivityWarning, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
  test('несколько 401 вызывают один refresh и повтор с новым Authorization',
      () async {
    final session = SessionStore();
    await session.restore(await SharedPreferences.getInstance());
    session.setToken('old');
    session.setRefreshToken('refresh1');
    session.setUser(client);
    final gate = Completer<ResponseBody>();
    final adapter = Adapter((o) async {
      if (o.path == '/auth/refresh') return gate.future;
      if (o.headers['Authorization'] == 'Bearer fresh') {
        return jsonBody(200, {'ok': true});
      }
      return jsonBody(401, {'message': 'expired'});
    });
    final dio = buildDio(
        tokenProvider: () => session.token,
        refreshTokens: session.refreshTokens)
      ..httpClientAdapter = adapter;
    session.attach(AuthRepository(dio));
    final a = dio.get('/one'), b = dio.get('/two');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    gate.complete(jsonBody(200, tokens()));
    expect((await a).statusCode, 200);
    expect((await b).statusCode, 200);
    expect(
        adapter.requests.where((r) => r.path == '/auth/refresh'), hasLength(1));
    expect(
        adapter.requests
            .where((r) => r.extra['authRetried'] == true)
            .every((r) => r.headers['Authorization'] == 'Bearer fresh'),
        isTrue);
    expect(session.token, 'fresh');
    dio.close();
  });
  test('плохой refresh завершает сессию и не зацикливает запросы', () async {
    final session = SessionStore();
    final prefs = await SharedPreferences.getInstance();
    await session.restore(prefs);
    session.setToken('old');
    session.setRefreshToken('invalid');
    session.setUser(client);
    await session.persist(prefs);
    final adapter = Adapter((_) async => jsonBody(401, {'message': 'invalid'}));
    final dio = buildDio(
        tokenProvider: () => session.token,
        refreshTokens: session.refreshTokens)
      ..httpClientAdapter = adapter;
    session.attach(AuthRepository(dio));
    await expectLater(
        guard(() => dio.get('/halls')), throwsA(isA<UnauthorizedException>()));
    expect(adapter.requests, hasLength(2));
    expect(session.isAuthenticated, isFalse);
    expect(prefs.getString(SessionStore.refreshKey), isNull);
    dio.close();
  });
  test('неверный пароль не вызывает refresh', () async {
    var refreshes = 0;
    final dio = buildDio(refreshTokens: () async {
      refreshes++;
      return true;
    })
      ..httpClientAdapter =
          Adapter((_) async => jsonBody(401, {'message': 'Неверный пароль'}));
    await expectLater(AuthRepository(dio).login('client', 'wrong'),
        throwsA(isA<UnauthorizedException>()));
    expect(refreshes, 0);
    dio.close();
  });
  test('повторный 401 после refresh не вызывает второй refresh', () async {
    final session = SessionStore()
      ..setToken('old')
      ..setRefreshToken('r')
      ..setUser(client);
    final adapter = Adapter((o) async => o.path == '/auth/refresh'
        ? jsonBody(200, tokens())
        : jsonBody(401, {'message': 'expired'}));
    final dio = buildDio(
        tokenProvider: () => session.token,
        refreshTokens: session.refreshTokens,
        onSessionExpired: () => session.logout(revoke: false))
      ..httpClientAdapter = adapter;
    session.attach(AuthRepository(dio));
    await expectLater(
        guard(() => dio.get('/halls')), throwsA(isA<UnauthorizedException>()));
    expect(adapter.requests, hasLength(3));
    expect(session.isAuthenticated, isFalse);
    dio.close();
  });
  test('выход во время refresh не восстанавливает закрытую сессию', () async {
    final session = SessionStore()
      ..setToken('old')
      ..setRefreshToken('r')
      ..setUser(client);
    final gate = Completer<ResponseBody>();
    final dio = buildDio()..httpClientAdapter = Adapter((_) => gate.future);
    session.attach(AuthRepository(dio));
    final pending = session.refreshTokens();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await session.logout(revoke: false);
    gate.complete(jsonBody(200, tokens()));
    expect(await pending, isFalse);
    expect(session.token, isNull);
    dio.close();
  });
  test('подмена роли меняет только интерфейс, не серверный профиль и токен',
      () async {
    SharedPreferences.setMockInitialValues({
      SessionStore.tokenKey: 'signed-client-token',
      SessionStore.uiRoleKey: 'admin'
    });
    final session = SessionStore();
    await session.restore(await SharedPreferences.getInstance());
    final dio = buildDio()
      ..httpClientAdapter =
          Adapter((_) async => jsonBody(200, tokens()['user']));
    await session.restoreUser(AuthRepository(dio));
    expect(session.permissions.canManageUsers, isTrue);
    expect(session.user!.role, 'client');
    expect(session.token, 'signed-client-token');
    dio.close();
  });
}
