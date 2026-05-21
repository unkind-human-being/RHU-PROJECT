import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthRepository {
  AuthRepository({
    AuthService? authService,
  }) : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) {
    return _authService.login(
      email: email,
      password: password,
    );
  }

  Future<UserModel?> loadSavedUser() {
    return _authService.loadSavedUser();
  }

  Future<UserModel> getCurrentUser() {
    return _authService.getCurrentUser();
  }

  Future<bool> hasActiveSession() {
    return _authService.hasActiveSession();
  }

  Future<String?> getToken() {
    return _authService.getToken();
  }

  Future<void> logout() {
    return _authService.logout();
  }

  Future<void> clearLocalSession() {
    return _authService.clearLocalSession();
  }
}