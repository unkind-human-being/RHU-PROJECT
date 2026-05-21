class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  final String message;
  final int? statusCode;
  final dynamic data;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidationError => statusCode == 400 || statusCode == 422;
  bool get isConflict => statusCode == 409;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }

    return '[$statusCode] $message';
  }

  factory ApiException.fromResponse({
    required int statusCode,
    required dynamic responseData,
  }) {
    String message = 'Something went wrong. Please try again.';

    if (responseData is Map<String, dynamic>) {
      final dynamic responseMessage = responseData['message'];

      if (responseMessage is String && responseMessage.trim().isNotEmpty) {
        message = responseMessage.trim();
      }
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      data: responseData,
    );
  }

  factory ApiException.network() {
    return const ApiException(
      message:
          'Unable to connect to the server. Please check your internet connection or backend API URL.',
    );
  }

  factory ApiException.timeout() {
    return const ApiException(
      message: 'The request took too long. Please try again.',
    );
  }

  factory ApiException.invalidJson() {
    return const ApiException(
      message: 'The server returned an invalid response.',
    );
  }

  factory ApiException.missingToken() {
    return const ApiException(
      message: 'Your session is missing. Please login again.',
      statusCode: 401,
    );
  }

  factory ApiException.unknown(Object error) {
    return ApiException(
      message: 'Unexpected error: $error',
      data: error,
    );
  }
}