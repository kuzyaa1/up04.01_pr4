import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_exceptions.dart';
import '../core/config.dart';
import '../core/permissions.dart';

/// Учётная запись, полученная после входа.
class AppUser {
  final int id;
  final String username;
  final String fullName;
  final String email;
  final String role;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] as num?)?.toInt() ?? 0,
        username: json['username'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'client',
      );

  /// Роль в виде перечисления.
  UserRole get roleLevel => UserRole.parse(role);

  /// Права пользователя.
  Permissions get permissions => Permissions(roleLevel);

  /// Может ли пользователь изменять данные.
  bool get canManage => permissions.canCreate;

  /// Может ли пользователь удалять записи физически и восстанавливать их.
  bool get canAdminister => permissions.canHardDelete;
}

/// Состояние сессии.
enum AuthStatus {
  /// Ещё не знаем: проверяем сохранённый токен.
  ///
  /// Пока идёт проверка, решать о доступе рано: иначе при каждой
  /// перезагрузке страницы человека будет на долю секунды выбрасывать
  /// на экран входа.
  unknown,

  /// Вход не выполнен.
  signedOut,

  /// Вход выполнен.
  signedIn,
}

/// Хранилище сессии: токен доступа и текущий пользователь.
///
/// Токен кладётся в `SharedPreferences` (на web это `localStorage`).
/// Это допустимо для токена доступа, но не для пароля и не для признака
/// администратора: проверка прав всегда выполняется на сервере.
///
/// Профиль пользователя хранится только в памяти: он восстанавливается
/// с сервера по сохранённому токену при запуске. Иначе после перезагрузки
/// страницы приложение потеряло бы роль и показывало гостю. Роль рядом
/// с токеном в `localStorage` не лежит — значение, лежащее в браузере,
/// пользователь может отредактировать в два клика.
class SessionStore extends ChangeNotifier {
  SessionStore();

  static const _tokenKey = 'focus_frame_api_token';
  static const _refreshKey = 'focus_frame_api_refresh';

  String? _token;
  String? _refreshToken;
  AppUser? _user;
  AuthStatus _status = AuthStatus.unknown;

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  AppUser? get user => _user;

  /// Состояние сессии.
  AuthStatus get status => _status;

  /// Выполнен ли вход.
  bool get isAuthenticated => _status == AuthStatus.signedIn;

  /// Известно ли состояние сессии.
  ///
  /// Пока состояние `unknown`, роутер не принимает решений о переходах.
  bool get isKnown => _status != AuthStatus.unknown;

  /// Права текущего пользователя.
  ///
  /// Гостю достаются права клиента: каталог можно читать, изменять —
  /// нельзя. Отличие гостя от вошедшего клиента — в признаке
  /// [Permissions.isGuest].
  Permissions get permissions =>
      _user?.permissions ?? const Permissions.guest();

  /// Задаёт токен, который клиент Dio подставит в заголовок `Authorization`.
  void setToken(String? value) => _token = value;

  void setRefreshToken(String? value) => _refreshToken = value;

  void setUser(AppUser? value) {
    _user = value;
    _status = value == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }

  /// Завершает сессию: пользователь считается гостем.
  void clear() {
    _token = null;
    _refreshToken = null;
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  /// Читает сохранённый токен из локального хранилища.
  Future<void> restore(SharedPreferences prefs) async {
    _token = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshKey);
    // Токен из --dart-define имеет приоритет: он удобен при проверке
    // на занятии, когда вход в систему ещё не реализован.
    if (apiToken.isNotEmpty) _token = apiToken;
  }

  /// Сохраняет токен в локальное хранилище.
  Future<void> persist(SharedPreferences prefs) async {
    final token = _token;
    final refresh = _refreshToken;
    if (token == null || token.isEmpty) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
    if (refresh == null || refresh.isEmpty) {
      await prefs.remove(_refreshKey);
    } else {
      await prefs.setString(_refreshKey, refresh);
    }
  }

  /// Завершает сессию на клиенте.
  Future<void> logout() async {
    clear();
  }

  /// Восстанавливает профиль пользователя по сохранённому токену.
  ///
  /// Вызывается при запуске приложения: без этого после перезагрузки
  /// страницы роль была бы потеряна. Если токен протух, сессия
  /// завершается и приложение работает как гость.
  Future<bool> restoreUser(AuthRepository auth) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return false;
    }
    try {
      final user = await auth.me();
      _user = user;
      _status = AuthStatus.signedIn;
      notifyListeners();
      return true;
    } on UnauthorizedException {
      // Протухший токен — не повод показывать ошибку: человек просто
      // давно не заходил. Молча забываем его и считаем гостем.
      clear();
      return false;
    } on ApiException {
      // Сервер недоступен: оставляем гостя, но сессию не сбрасываем —
      // при следующем запуске профиль восстановится.
      _status = AuthStatus.signedOut;
      notifyListeners();
      return false;
    }
  }
}

/// Вход в систему и получение токена.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  /// Входит по логину и паролю. Возвращает пару «токен, пользователь».
  Future<({String accessToken, String refreshToken, AppUser user})> login(
    String username,
    String password,
  ) async {
    final response = await guard(
      () => _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'username': username, 'password': password},
      ),
    );
    final data = response.data ?? const <String, dynamic>{};
    return (
      accessToken: data['accessToken'] as String? ?? '',
      refreshToken: data['refreshToken'] as String? ?? '',
      user: AppUser.fromJson(
        (data['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
    );
  }

  /// Возвращает текущего пользователя по сохранённому токену.
  Future<AppUser> me() async {
    final response =
        await guard(() => _dio.get<Map<String, dynamic>>('/auth/me'));
    return AppUser.fromJson(response.data ?? const <String, dynamic>{});
  }

  /// Завершает сессию на сервере.
  Future<void> logout(String? refreshToken) async {
    await guard(
      () => _dio.post<void>(
        '/auth/logout',
        data: {if (refreshToken != null) 'refreshToken': refreshToken},
      ),
    );
  }
}
