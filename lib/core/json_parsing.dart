/// Разбор значений, пришедших с сервера.
///
/// Сервер может прислать `null` там, где ожидается число или строка,
/// поэтому разбор всегда идёт со значением по умолчанию: иначе
/// приложение упадёт на первом же неполном ответе.
library;

/// Разбор целого числа.
int parseInt(Object? value, {int fallback = 0}) => switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ?? fallback,
      _ => fallback,
    };

/// Разбор строки.
String parseString(Object? value, {String fallback = ''}) =>
    value == null ? fallback : value.toString();

/// Разбор списка идентификаторов.
List<int> parseIntList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => parseInt(item)).where((id) => id > 0).toList();
}

/// Разбор даты из строки ISO 8601.
DateTime? parseDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}

/// Разбор логического значения.
bool parseBool(Object? value, {bool fallback = false}) => switch (value) {
      bool v => v,
      String v => v == 'true',
      num v => v != 0,
      _ => fallback,
    };
