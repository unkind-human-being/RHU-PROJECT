import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import 'api_exception.dart';

typedef TokenProvider = Future<String?> Function();

class ApiClient {
  ApiClient({
    http.Client? client,
    TokenProvider? tokenProvider,
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider;

  final http.Client _client;
  final TokenProvider? _tokenProvider;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _send(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _send(
      method: 'POST',
      path: path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _send(
      method: 'PATCH',
      path: path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _send(
      method: 'DELETE',
      path: path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    required bool requiresAuth,
  }) async {
    try {
      final Uri uri = ApiConstants.uri(
        path,
        queryParameters: queryParameters,
      );

      final Map<String, String> headers =
          Map<String, String>.from(ApiConstants.defaultHeaders);

      if (requiresAuth) {
        final String? token = await _tokenProvider?.call();

        if (token == null || token.trim().isEmpty) {
          throw ApiException.missingToken();
        }

        headers['Authorization'] = 'Bearer ${token.trim()}';
      }

      final http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(ApiConstants.requestTimeout);
          break;

        case 'POST':
          response = await _client
              .post(
                uri,
                headers: headers,
                body: jsonEncode(body ?? <String, dynamic>{}),
              )
              .timeout(ApiConstants.requestTimeout);
          break;

        case 'PATCH':
          response = await _client
              .patch(
                uri,
                headers: headers,
                body: jsonEncode(body ?? <String, dynamic>{}),
              )
              .timeout(ApiConstants.requestTimeout);
          break;

        case 'DELETE':
          response = await _client
              .delete(
                uri,
                headers: headers,
                body: jsonEncode(body ?? <String, dynamic>{}),
              )
              .timeout(ApiConstants.requestTimeout);
          break;

        default:
          throw ApiException(
            message: 'Unsupported HTTP method: $method',
          );
      }

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException.timeout();
    } on SocketException {
      throw ApiException.network();
    } on http.ClientException {
      throw ApiException.network();
    } on FormatException {
      throw ApiException.invalidJson();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException.unknown(error);
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final dynamic decodedResponse = _decodeResponse(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decodedResponse is Map<String, dynamic>) {
        return decodedResponse;
      }

      return <String, dynamic>{
        'success': true,
        'data': decodedResponse,
      };
    }

    throw ApiException.fromResponse(
      statusCode: response.statusCode,
      responseData: decodedResponse,
    );
  }

  dynamic _decodeResponse(String responseBody) {
    if (responseBody.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final dynamic decoded = jsonDecode(responseBody);

    return decoded;
  }

  void close() {
    _client.close();
  }
}