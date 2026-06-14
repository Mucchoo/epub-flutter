class EpubParseException implements Exception {
  final String message;
  EpubParseException(this.message);

  @override
  String toString() => 'EpubParseException: $message';
}
