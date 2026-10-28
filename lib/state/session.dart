import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_exceptions.dart';
import '../core/config.dart';
import '../core/permissions.dart';

class AppUser {
  final int id;
  final int? clientId;
  final String username, fullName, email, role;
  const AppUser(
      {required this.id,
      this.clientId,
      required this.username,
      required this.fullName,
      required this.email,
      required this.role});
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      clientId: (json['clientId'] as num?)?.toInt(),
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'client');
  UserRole get roleLevel => UserRole.parse(role);
  Permissions get permissions => Permissions(roleLevel);
  bool get canManage => permissions.canCreate;
  bool get canAdminister => permissions.canHardDelete;
}

enum AuthStatus { unknown, signedOut, signedIn }

typedef AuthTokens = ({String accessToken, String refreshToken, AppUser user});

class SessionStore extends ChangeNotifier {
  SessionStore(
      {DateTime Function()? clock,
      this.inactivityTimeout = const Duration(seconds: sessionIdleSeconds),
      this.maximumDuration = const Duration(seconds: sessionMaxSeconds),
      this.warningDuration = const Duration(seconds: 30)})
      : _clock = clock ?? DateTime.now;
  static const tokenKey = 'focus_frame_api_token';
  static const refreshKey = 'focus_frame_api_refresh';
  // Untrusted presentation preference only. API authorizes the signed token.
  static const uiRoleKey = 'focus_frame_ui_role';
  static const startedKey = 'focus_frame_session_started';
  static const activityKey = 'focus_frame_last_activity';
  final DateTime Function() _clock;
  final Duration inactivityTimeout, maximumDuration, warningDuration;
  SharedPreferences? _prefs;
  AuthRepository? _auth;
  String? _token, _refreshToken;
  AppUser? _user;
  UserRole? _uiRole;
  AuthStatus _status = AuthStatus.unknown;
  DateTime? _startedAt, _lastActivity, _lastPersistedActivity;
  Future<bool>? _refreshing;
  int _generation = 0;
  bool _disposed = false;
  bool _warning = false;
  String? notice;
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  AppUser? get user => _user;
  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.signedIn;
  bool get isKnown => _status != AuthStatus.unknown;
  Permissions get permissions => isAuthenticated && _user != null
      ? Permissions(_uiRole ?? _user!.roleLevel)
      : const Permissions.guest();
  bool get inactivityWarning => _warning;
  int get secondsRemaining => _lastActivity == null
      ? 0
      : (inactivityTimeout - _clock().difference(_lastActivity!))
          .inSeconds
          .clamp(0, inactivityTimeout.inSeconds);
  void attach(AuthRepository auth) => _auth = auth;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setToken(String? value) => _token = value;
  void setRefreshToken(String? value) => _refreshToken = value;
  void setUser(AppUser? value) {
    _generation++;
    _user = value;
    _uiRole = value?.roleLevel;
    _status = value == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    _startedAt ??= _clock();
    _lastActivity ??= _clock();
    _notify();
  }

  void clear() {
    _generation++;
    _token = null;
    _refreshToken = null;
    _user = null;
    _uiRole = null;
    _startedAt = null;
    _lastActivity = null;
    _warning = false;
    _status = AuthStatus.signedOut;
    _notify();
  }

  Future<void> restore(SharedPreferences prefs) async {
    _prefs = prefs;
    _token = prefs.getString(tokenKey);
    _refreshToken = prefs.getString(refreshKey);
    final role = prefs.getString(uiRoleKey);
    _uiRole = role == null ? null : UserRole.parse(role);
    DateTime? date(String key) => DateTime.tryParse(prefs.getString(key) ?? '');
    _startedAt = date(startedKey);
    _lastActivity = date(activityKey);
    if (apiToken.isNotEmpty) _token = apiToken;
    if (_token != null || _refreshToken != null) {
      final now = _clock();
      if ((_startedAt != null &&
              now.difference(_startedAt!) >= maximumDuration) ||
          (_lastActivity != null &&
              now.difference(_lastActivity!) >= inactivityTimeout)) {
        await logout(
            reason: 'Сессия завершена по времени. Войдите снова.',
            revoke: false);
      }
    }
  }

  Future<void> persist(SharedPreferences prefs) async {
    _prefs = prefs;
    final values = <String, String?>{
      tokenKey: _token,
      refreshKey: _refreshToken,
      uiRoleKey: _uiRole?.name,
      startedKey: _startedAt?.toIso8601String(),
      activityKey: _lastActivity?.toIso8601String(),
    };
    for (final entry in values.entries) {
      if (entry.value == null || entry.value!.isEmpty) {
        await prefs.remove(entry.key);
      } else {
        await prefs.setString(entry.key, entry.value!);
      }
    }
  }

  Future<void> signIn(
      AuthRepository auth, String username, String password) async {
    final generation = ++_generation;
    final result = await auth.login(username, password);
    if (generation != _generation) return;
    _auth = auth;
    _token = result.accessToken;
    _refreshToken = result.refreshToken;
    _user = result.user;
    _uiRole = result.user.roleLevel;
    _startedAt = _clock();
    _lastActivity = _clock();
    _warning = false;
    notice = null;
    _status = AuthStatus.signedIn;
    if (_prefs != null) await persist(_prefs!);
    _notify();
  }

  Future<void> logout({String? reason, bool revoke = true}) async {
    final oldRefresh = _refreshToken;
    clear();
    notice = reason;
    if (_prefs != null) await persist(_prefs!);
    _notify();
    if (revoke && _auth != null && oldRefresh != null) {
      try {
        await _auth!.logout(oldRefresh);
      } on Object {/* Local logout is final even offline. */}
    }
  }

  Future<bool> restoreUser(AuthRepository auth) async {
    _auth = auth;
    if (_token == null && _refreshToken == null) {
      _status = AuthStatus.signedOut;
      _notify();
      return false;
    }
    final generation = _generation;
    try {
      final restored = _token == null ? null : await auth.me();
      if (generation != _generation) return false;
      if (restored == null) return refreshTokens();
      _user = restored;
      _uiRole ??= restored.roleLevel;
      _startedAt ??= _clock();
      _lastActivity ??= _clock();
      _status = AuthStatus.signedIn;
      if (_prefs != null) await persist(_prefs!);
      _notify();
      return true;
    } on UnauthorizedException {
      return refreshTokens();
    } on ApiException {
      _status = AuthStatus.signedOut;
      _notify();
      return false;
    }
  }

  Future<bool> refreshTokens() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  Future<bool> _doRefresh() async {
    final refresh = _refreshToken;
    if (refresh == null || _auth == null) {
      await logout(reason: 'Сессия истекла. Войдите снова.', revoke: false);
      return false;
    }
    final generation = _generation;
    try {
      final result = await _auth!.refresh(refresh);
      if (generation != _generation) return false;
      _token = result.accessToken;
      _refreshToken = result.refreshToken;
      _user = result.user;
      _uiRole ??= result.user.roleLevel;
      _status = AuthStatus.signedIn;
      _startedAt ??= _clock();
      _lastActivity ??= _clock();
      if (_prefs != null) await persist(_prefs!);
      _notify();
      return true;
    } on ApiException {
      if (generation == _generation) {
        await logout(
            reason: 'Не удалось обновить сессию. Войдите снова.',
            revoke: false);
      }
      return false;
    }
  }

  void recordActivity() {
    if (!isAuthenticated) return;
    // An action after expiry must not resurrect an expired session.
    if (_expired()) {
      unawaited(checkLimits());
      return;
    }
    _lastActivity = _clock();
    final hadWarning = _warning;
    _warning = false;
    if (_prefs != null &&
        (_lastPersistedActivity == null ||
            _clock().difference(_lastPersistedActivity!) >=
                const Duration(seconds: 1))) {
      _lastPersistedActivity = _clock();
      unawaited(
          _prefs!.setString(activityKey, _lastActivity!.toIso8601String()));
    }
    if (hadWarning) _notify();
  }

  bool _expired() =>
      (_startedAt != null &&
          _clock().difference(_startedAt!) >= maximumDuration) ||
      (_lastActivity != null &&
          _clock().difference(_lastActivity!) >= inactivityTimeout);
  Future<void> checkLimits() async {
    if (!isAuthenticated) return;
    if (_expired()) {
      final total = _startedAt != null &&
          _clock().difference(_startedAt!) >= maximumDuration;
      await logout(
          reason: total
              ? 'Время сессии истекло. Войдите снова.'
              : 'Сессия завершена из-за неактивности. Войдите снова.');
    } else {
      final warning = secondsRemaining <= warningDuration.inSeconds;
      if (warning || _warning != warning) {
        _warning = warning;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;
  AuthTokens _tokens(Map<String, dynamic> data) => (
        accessToken: data['accessToken'] as String? ?? '',
        refreshToken: data['refreshToken'] as String? ?? '',
        user: AppUser.fromJson(data['user'] as Map<String, dynamic>? ?? {})
      );
  Future<AuthTokens> login(String username, String password) async {
    final response = await guard(() => _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'username': username, 'password': password}));
    return _tokens(response.data ?? {});
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    final response = await guard(() => _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken}));
    return _tokens(response.data ?? {});
  }

  Future<void> register(
          {required String username,
          required String password,
          required String fullName,
          required String email}) =>
      guard(() => _dio.post('/auth/register', data: {
            'username': username,
            'password': password,
            'fullName': fullName,
            'email': email
          }));
  Future<AppUser> me() async {
    final response =
        await guard(() => _dio.get<Map<String, dynamic>>('/auth/me'));
    return AppUser.fromJson(response.data ?? {});
  }

  Future<void> logout(String? refreshToken) =>
      guard(() => _dio.post('/auth/logout',
          data: {if (refreshToken != null) 'refreshToken': refreshToken}));
}
