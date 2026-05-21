import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';
import '../models/user_model.dart';

class AuthService {
  AuthService({
    ApiClient? apiClient,
    TokenStorageService? tokenStorageService,
  })  : _tokenStorageService = tokenStorageService ?? TokenStorageService(),
        _apiClient = apiClient ??
            ApiClient(
              tokenProvider:
                  (tokenStorageService ?? TokenStorageService()).getToken,
            );

  final ApiClient _apiClient;
  final TokenStorageService _tokenStorageService;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final String cleanEmail = email.trim().toLowerCase();
    final String cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      throw const ApiException(
        message: 'Email and password are required.',
        statusCode: 400,
      );
    }

    final Map<String, dynamic> response = await _apiClient.post(
      ApiConstants.login,
      requiresAuth: false,
      body: <String, dynamic>{
        'email': cleanEmail,
        'password': cleanPassword,
      },
    );

    final dynamic tokenValue = response['token'];
    final dynamic userValue = response['user'];

    if (tokenValue is! String || tokenValue.trim().isEmpty) {
      throw const ApiException(
        message: 'Login succeeded but no token was returned.',
      );
    }

    if (userValue is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Login succeeded but user data was invalid.',
      );
    }

    final UserModel user = UserModel.fromJson(userValue);

    await _tokenStorageService.saveSession(
      token: tokenValue,
      userJson: user.toJson(),
    );

    return AuthSession(
      token: tokenValue,
      user: user,
    );
  }

  Future<UserModel?> loadSavedUser() async {
    final Map<String, dynamic>? userJson =
        await _tokenStorageService.getUserJson();

    if (userJson == null) {
      return null;
    }

    return UserModel.fromJson(userJson);
  }

  Future<UserModel> getCurrentUser() async {
    final Map<String, dynamic> response = await _apiClient.get(
      ApiConstants.me,
      requiresAuth: true,
    );

    final dynamic userValue = response['user'];

    if (userValue is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Unable to load current user profile.',
      );
    }

    final UserModel user = UserModel.fromJson(userValue);

    await _tokenStorageService.saveUserJson(user.toJson());

    return user;
  }

  Future<bool> hasActiveSession() {
    return _tokenStorageService.hasActiveSession();
  }

  Future<String?> getToken() {
    return _tokenStorageService.getToken();
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(
        ApiConstants.logout,
        requiresAuth: true,
      );
    } catch (_) {
      // The app still clears local session even if the server logout call fails.
    }

    await _tokenStorageService.clearSession();
  }

  Future<void> clearLocalSession() {
    return _tokenStorageService.clearSession();
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
  });

  final String token;
  final UserModel user;
}