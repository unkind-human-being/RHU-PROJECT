import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/auth_service.dart';

enum AuthStatus {
  initial,
  checking,
  authenticated,
  unauthenticated,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthRepository? authRepository,
  }) : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _token;
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get token => _token;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isUnauthenticated => _status == AuthStatus.unauthenticated;

  String get userDisplayName => _user?.fullName ?? 'Guest';
  String get userRole => _user?.roleDisplayName ?? 'Not logged in';
  String get assignedLocation => _user?.assignedLocation ?? 'No location';

  Future<void> initialize() async {
    _setStatus(AuthStatus.checking);
    _setError(null);

    try {
      final bool hasSession = await _authRepository.hasActiveSession();

      if (!hasSession) {
        _clearSessionState();
        _setStatus(AuthStatus.unauthenticated);
        return;
      }

      final UserModel? savedUser = await _authRepository.loadSavedUser();
      final String? savedToken = await _authRepository.getToken();

      _user = savedUser;
      _token = savedToken;

      try {
        final UserModel freshUser = await _authRepository.getCurrentUser();
        _user = freshUser;
      } catch (_) {
        // If the profile refresh fails but a local session exists,
        // we still allow the app to open. API calls will handle expired tokens.
      }

      _setStatus(AuthStatus.authenticated);
    } catch (error) {
      await _authRepository.clearLocalSession();
      _clearSessionState();
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final AuthSession session = await _authRepository.login(
        email: email,
        password: password,
      );

      _user = session.user;
      _token = session.token;
      _status = AuthStatus.authenticated;

      notifyListeners();

      return true;
    } on ApiException catch (error) {
      _setError(error.message);
      _status = AuthStatus.unauthenticated;
      notifyListeners();

      return false;
    } catch (_) {
      _setError('Unable to login. Please try again.');
      _status = AuthStatus.unauthenticated;
      notifyListeners();

      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshUser() async {
    if (!isAuthenticated) {
      return;
    }

    try {
      final UserModel freshUser = await _authRepository.getCurrentUser();
      _user = freshUser;
      notifyListeners();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await logout();
      } else {
        _setError(error.message);
      }
    } catch (_) {
      _setError('Unable to refresh user profile.');
    }
  }

  Future<void> logout() async {
    _setLoading(true);

    try {
      await _authRepository.logout();
    } finally {
      _clearSessionState();
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
      notifyListeners();
    }
  }

  void clearError() {
    _setError(null);
  }

  void _clearSessionState() {
    _user = null;
    _token = null;
    _errorMessage = null;
  }

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
}