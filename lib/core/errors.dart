class FieldValidationException implements Exception {
  final String field;
  final String message;
  const FieldValidationException(this.field, this.message);
  @override
  String toString() => message;
}

class LinkedRecordsException implements Exception {
  final String message;
  final int count;
  const LinkedRecordsException(this.message, this.count);

  @override
  String toString() => message;
}
