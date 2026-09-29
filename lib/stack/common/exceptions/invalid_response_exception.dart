class InvalidResponseException implements Exception {
  @override
  String toString() => 'Response is not in expected format.';
}
