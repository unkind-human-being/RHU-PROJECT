class ApiConstants {
  ApiConstants._();

  /*
    API URL guide:

    Android Emulator:
    http://10.0.2.2:5000

    Physical Android phone:
    Use your computer IP address.
    Example:
    http://192.168.1.10:5000

    Optional run command override:
    flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000
  */

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  static const Duration requestTimeout = Duration(seconds: 30);

  static const Map<String, String> defaultHeaders = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static const String health = '/api/health';

  static const String login = '/api/auth/login';
  static const String me = '/api/auth/me';
  static const String updateMe = '/api/auth/me';
  static const String changePassword = '/api/auth/change-password';
  static const String logout = '/api/auth/logout';

  static const String rhus = '/api/rhus';
  static const String barangays = '/api/barangays';
  static const String users = '/api/users';

  static const String publicPosts = '/api/posts/public';
  static const String posts = '/api/posts';

  static const String publicEvents = '/api/events/public';
  static const String events = '/api/events';

  static const String publicSurveys = '/api/surveys/public';
  static const String surveys = '/api/surveys';

  static const String medicines = '/api/medicines';
  static const String medicineSummary = '/api/medicines/summary';
  static const String medicineTransactions = '/api/medicines/transactions';

  static const String syncMedicineTransactions =
      '/api/sync/medicine-transactions';
  static const String syncLogs = '/api/sync/logs';
  static const String syncStatus = '/api/sync/status';

  static Uri uri(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    final Map<String, String> cleanedQuery = <String, String>{};

    if (queryParameters != null) {
      queryParameters.forEach((String key, dynamic value) {
        if (value == null) return;

        final String textValue = value.toString().trim();

        if (textValue.isEmpty) return;

        cleanedQuery[key] = textValue;
      });
    }

    final String normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final String normalizedPath = path.startsWith('/') ? path : '/$path';

    return Uri.parse('$normalizedBaseUrl$normalizedPath').replace(
      queryParameters: cleanedQuery.isEmpty ? null : cleanedQuery,
    );
  }
}