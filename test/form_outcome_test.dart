import 'package:flutter_test/flutter_test.dart';
import 'package:photo_studio_portal/core/api_exceptions.dart';
import 'package:photo_studio_portal/core/errors.dart';
import 'package:photo_studio_portal/core/form_outcome.dart';

/// Проверки разбора ошибок сервера в форме.
///
/// Один и тот же обработчик сохранения работает и для сетевой реализации
/// репозитория, и для реализации на данных в памяти: разбирать ошибки
/// по-разному в двух местах не нужно.
void main() {
  group('разбор ошибок в форме', () {
    test('422 даёт ошибки по полям', () {
      final outcome = toFormOutcome(
        const ValidationException(
          'Ошибка валидации',
          {'code': 'Зал с таким кодом уже существует'},
        ),
      );
      expect(outcome, isA<FormInvalid>());
      final invalid = outcome as FormInvalid;
      expect(invalid.errors['code'], 'Зал с таким кодом уже существует');
    });

    test('409 даёт конфликт с понятным сообщением', () {
      final outcome = toFormOutcome(
        const ConflictException(
            'На эту дату в зале уже есть активное бронирование'),
      );
      expect(outcome, isA<FormConflict>());
      expect(
        (outcome as FormConflict).message,
        'На эту дату в зале уже есть активное бронирование',
      );
    });

    test('401 даёт сообщение о необходимости входа', () {
      final outcome = toFormOutcome(const UnauthorizedException());
      expect(outcome, isA<FormFailed>());
      expect((outcome as FormFailed).message, 'Требуется вход в систему.');
    });

    test('ошибка реализации на данных в памяти тоже попадает в поле', () {
      final outcome = toFormOutcome(
        const FieldValidationException(
            'code', 'Зал с таким кодом уже существует'),
      );
      expect(outcome, isA<FormInvalid>());
      expect(
        (outcome as FormInvalid).errors['code'],
        'Зал с таким кодом уже существует',
      );
    });

    test('неизвестная ошибка не теряется', () {
      final outcome = toFormOutcome(StateError('что-то пошло не так'));
      expect(outcome, isA<FormFailed>());
      expect((outcome as FormFailed).message.contains('что-то пошло не так'),
          isTrue);
    });
  });

  group('исключения предметной области', () {
    test('ValidationException хранит ошибки по полям', () {
      const error = ValidationException('Ошибка', {'a': 'текст'});
      expect(error.errorFor('a'), 'текст');
      expect(error.errorFor('b'), isNull);
      expect(error.toString(), 'Ошибка');
    });

    test('неизвестный код 5xx даёт ServerException', () {
      expect(mapHttpError(503, null), isA<ServerException>());
    });

    test('сообщение сервера имеет приоритет над запасным', () {
      final error = mapHttpError(409, {'message': 'Свой текст'});
      expect(error.message, 'Свой текст');
    });

    test('тело без errors даёт пустой словарь', () {
      final error = mapHttpError(422, {'message': 'Ошибка'});
      expect(error, isA<ValidationException>());
      expect((error as ValidationException).errors, isEmpty);
    });
  });
}
