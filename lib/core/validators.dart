typedef Validator = String? Function(String? value);

class V {
  static Validator required([String message = 'Поле обязательно']) =>
      (value) => value == null || value.trim().isEmpty ? message : null;
  static Validator length({int min = 0, int max = 255}) => (value) {
        final text = value?.trim() ?? '';
        if (text.length < min) return 'Минимум символов: $min';
        if (text.length > max) return 'Максимум символов: $max';
        return null;
      };
  static Validator integer({int? min, int? max, String? label}) => (value) {
        final text = value?.trim() ?? '';
        final number = int.tryParse(text);
        if (number == null) return 'Введите целое число';
        if (min != null && number < min) {
          return label == null
              ? 'Значение не меньше $min'
              : '$label не меньше $min';
        }
        if (max != null && number > max) {
          return label == null
              ? 'Значение не больше $max'
              : '$label не больше $max';
        }
        return null;
      };
  static Validator positive({String label = 'Значение'}) => (value) {
        final text = value?.trim() ?? '';
        final number = int.tryParse(text);
        if (number == null) return 'Введите целое число';
        if (number <= 0) return '$label должно быть больше нуля';
        return null;
      };
  static Validator email() => (value) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value?.trim() ?? '')
          ? null
          : 'Введите корректный адрес почты';
  static Validator phone() => (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'Введите номер телефона';
        if (!RegExp(r'^\+?[\d\s\-()]{6,20}$').hasMatch(text)) {
          return 'Номер может содержать цифры, пробелы, дефисы и скобки';
        }
        final digits = text.replaceAll(RegExp(r'\D'), '');
        if (digits.length < 6 || digits.length > 15) {
          return 'В номере должно быть от 6 до 15 цифр';
        }
        return null;
      };
  static Validator accessCode() => (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return 'Укажите код бронирования';
        if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(text)) {
          return 'Код состоит из латинских букв, цифр и дефиса';
        }
        if (text.length < 6) return 'Код не короче 6 символов';
        return null;
      };
  static Validator containsDigit([String message = 'Добавьте цифру']) =>
      (value) => RegExp(r'\d').hasMatch(value ?? '') ? null : message;
  static Validator date({DateTime? min, DateTime? max}) => (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'Введите дату в формате ГГГГ-ММ-ДД';
        final date = DateTime.tryParse(text);
        if (date == null) return 'Некорректная дата, формат ГГГГ-ММ-ДД';
        if (min != null && date.isBefore(min)) {
          return 'Дата не раньше ${min.year}-${_two(min.month)}-${_two(min.day)}';
        }
        if (max != null && date.isAfter(max)) {
          return 'Дата не позже ${max.year}-${_two(max.month)}-${_two(max.day)}';
        }
        return null;
      };
  static Validator notPast() => (value) {
        final error = date()(value);
        if (error != null) return error;
        final parsed = DateTime.tryParse(value!.trim());
        if (parsed == null) return 'Некорректная дата, формат ГГГГ-ММ-ДД';
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day);
        if (parsed.isBefore(midnight)) return 'Дата не может быть в прошлом';
        return null;
      };
  static Validator notNull([String message = 'Выберите значение']) => (value) {
        final text = value?.trim() ?? '';
        return text.isEmpty ? message : null;
      };
  static Validator notEmptySelection(
          [String message = 'Выберите хотя бы один вариант']) =>
      (value) => value == null || value.trim().isEmpty ? message : null;
  static String _two(int n) => n.toString().padLeft(2, '0');
  static Validator combine(List<Validator> validators) => (value) {
        for (final validator in validators) {
          final error = validator(value);
          if (error != null) return error;
        }
        return null;
      };
}
