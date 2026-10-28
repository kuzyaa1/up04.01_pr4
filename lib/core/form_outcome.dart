import 'package:flutter/material.dart';

import 'api_exceptions.dart';
import 'errors.dart';
import '../widgets/common.dart';

/// Результат разбора ответа сервера в форме.
sealed class FormOutcome {
  const FormOutcome();
}

/// Запись сохранена.
class FormSaved extends FormOutcome {
  const FormSaved();
}

/// Сервер вернул ошибки валидации по полям (422).
///
/// Ключи в [errors] совпадают с именами полей модели, поэтому ошибку
/// можно положить в нужное поле без ручного сопоставления.
class FormInvalid extends FormOutcome {
  final Map<String, String> errors;
  const FormInvalid(this.errors);
}

/// Сервер вернул конфликт (409) — показать пользователю понятное сообщение.
class FormConflict extends FormOutcome {
  final String message;
  const FormConflict(this.message);
}

/// Прочие ошибки: нет сети, нет прав, сервер упал.
class FormFailed extends FormOutcome {
  final String message;
  const FormFailed(this.message);
}

/// Разбирает исключение сетевого слоя в результат для формы.
///
/// Единая точка, где ошибки 422, 409 и остальные коды превращаются
/// в понятные пользователю сообщения.
FormOutcome toFormOutcome(Object error) {
  if (error is ValidationException) {
    return FormInvalid(error.errors);
  }
  // Реализация на данных в памяти сообщает об ошибке по одному полю.
  if (error is FieldValidationException) {
    return FormInvalid({error.field: error.message});
  }
  if (error is ConflictException) {
    return FormConflict(error.message);
  }
  if (error is ApiException) {
    return FormFailed(error.message);
  }
  return FormFailed('Не удалось сохранить: $error');
}

/// Показывает сообщение об ошибке в виде всплывающей подсказки.
void showFormError(BuildContext context, FormOutcome outcome) {
  if (outcome is FormConflict) {
    showOperationError(context, ConflictException(outcome.message));
    return;
  }
  final message = switch (outcome) {
    FormConflict(:final message) => message,
    FormFailed(:final message) => message,
    FormInvalid() => 'Проверьте отмеченные поля: сервер отклонил запись.',
    FormSaved() => '',
  };
  if (message.isNotEmpty) toast(context, message);
}
