/// Exceptions personnalisées de l'application.
class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() => 'AppException: $message${code != null ? " (code: $code)" : ""}';
}

class NetworkException extends AppException {
  NetworkException(String message, {String? code}) : super(message, code: code);
}

class AuthException extends AppException {
  AuthException(String message, {String? code}) : super(message, code: code);
}

class DataException extends AppException {
  DataException(String message, {String? code}) : super(message, code: code);
}

class ValidationException extends AppException {
  ValidationException(String message, {String? code}) : super(message, code: code);
}
