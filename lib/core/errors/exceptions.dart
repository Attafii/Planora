class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.status = 0,
    this.code = 'network_error',
  });
  final String message;
  final int status;
  final String code;
  @override
  String toString() => message;
}
