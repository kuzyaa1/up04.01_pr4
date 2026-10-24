import 'package:dio/dio.dart';

/// Исключения предметной области.
///
/// Виджеты и состояние не знают о существовании Dio: наружу из
/// сетевого слоя выпускаются только эти типы. Между ними и `DioException`
/// стоит преобразование [mapDioError].
sealed class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Нет соединения, таймаут, сервер недоступен, заблокировано CORS.
class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'Сервер недоступен. Проверьте соединение.',
  ]);
}

/// 401 — не аутентифицирован либо срок действия токена истёк.
class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

/// 403 — роль не позволяет выполнить операцию.
class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]);
}

/// 404.
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

/// 409 — нарушено ограничение целостности.
class ConflictException extends ApiException {
  const ConflictException(super.message);
}

/// 422 — ошибки валидации по полям.
///
/// Ключи в [errors] совпадают с именами полей модели, поэтому ошибку
/// можно положить в нужное поле формы без ручного сопоставления.
class ValidationException extends ApiException {
  final Map<String, String> errors;

  const ValidationException(super.message, this.errors);

  /// Текст ошибки для конкретного поля либо null.
  String? errorFor(String field) => errors[field];
}

/// 5xx — сервер упал.
class ServerException extends ApiException {
  const ServerException([
    super.message = 'Ошибка на сервере. Попробуйте позже.',
  ]);
}

/// Запрос был отменён пользователем или устарел.
class CancelledException extends ApiException {
  const CancelledException([super.message = 'Запрос отменён.']);
}

/// Преобразует HTTP-ответ с кодом ошибки в исключение предметной области.
ApiException mapHttpError(int status, dynamic body) {
  final message = (body is Map && body['message'] is String)
      ? body['message'] as String
      : null;

  return switch (status) {
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(
        message ?? 'Недостаточно прав для этого действия.',
      ),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    422 => ValidationException(
        message ?? 'Ошибка валидации',
        (body is Map && body['errors'] is Map)
            ? (body['errors'] as Map).map(
                (k, v) => MapEntry('$k', '$v'),
              )
            : const {},
      ),
    _ => ServerException(message ?? 'Неизвестная ошибка (код $status).'),
  };
}

/// Преобразует `DioException` в исключение предметной области.
///
/// Если исключение уже разобрал интерсептор, повторно его не разбираем.
/// Без этой проверки ошибка 422 придёт в приложение как `ServerException`,
/// и обработчик `on ValidationException` никогда не сработает.
ApiException mapDioError(DioException e) {
  final existing = e.error;
  if (existing is ApiException) return existing;

  final status = e.response?.statusCode;
  if (status != null && status >= 400 && status < 500) {
    return mapHttpError(status, e.response?.data);
  }

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      const NetworkException('Сервер не ответил вовремя.'),
    DioExceptionType.connectionError => const NetworkException(
        'Не удалось соединиться с сервером. '
        'Если сервер запущен, откройте консоль браузера и проверьте '
        'наличие ошибки CORS.',
      ),
    DioExceptionType.cancel => const CancelledException(),
    _ => const ServerException(),
  };
}

/// Оборачивает обращение к сети так, чтобы наружу не вышел `DioException`.
///
/// Единственная задача [guard] — не выпустить наружу `DioException`:
/// в приложение должны попадать только исключения предметной области.
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}
