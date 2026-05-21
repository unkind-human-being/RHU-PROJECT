import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TokenStorageService {
  static const String _tokenKey = 'rhu_auth_token';
  static const String _userKey = 'rhu_auth_user';

  Future<void> saveSession({
    required String token,
    required Map<String, dynamic> userJson,
  }) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.setString(_tokenKey, token.trim());
    await preferences.setString(_userKey, jsonEncode(userJson));
  }

  Future<void> saveToken(String token) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.setString(_tokenKey, token.trim());
  }

  Future<String?> getToken() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String? token = preferences.getString(_tokenKey);

    if (token == null || token.trim().isEmpty) {
      return null;
    }

    return token.trim();
  }

  Future<void> saveUserJson(Map<String, dynamic> userJson) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.setString(_userKey, jsonEncode(userJson));
  }

  Future<Map<String, dynamic>?> getUserJson() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String? userText = preferences.getString(_userKey);

    if (userText == null || userText.trim().isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(userText);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return null;
    } catch (_) {
      await preferences.remove(_userKey);
      return null;
    }
  }

  Future<bool> hasActiveSession() async {
    final String? token = await getToken();

    return token != null && token.trim().isNotEmpty;
  }

  Future<void> clearSession() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.remove(_tokenKey);
    await preferences.remove(_userKey);
  }
}