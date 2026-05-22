import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../features/video/incoming_call_screen.dart';
import '../constants/api_constants.dart';
import '../storage/token_storage_service.dart';
import 'incoming_call_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final Map<String, dynamic> data = Map<String, dynamic>.from(message.data);

  if (_isIncomingCall(data)) {
    await IncomingCallNotificationService.instance.showIncomingCallNotification(
      payload: data,
    );
  }
}

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _initialized = false;
  String? _lastOpenedCallId;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await IncomingCallNotificationService.instance.initialize(
      onResponse: _handleLocalNotificationResponse,
    );

    await _requestPermission();
    await _syncCurrentFcmToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
      _sendFcmTokenToBackend(token);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageOpened(message.data);
    });

    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleMessageOpened(initialMessage.data);
    }

    _initialized = true;
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
      provisional: false,
    );
  }

  Future<void> _syncCurrentFcmToken() async {
    try {
      final String? token = await _messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        return;
      }

      await _sendFcmTokenToBackend(token);
    } catch (_) {
      // Ignore token sync errors for MVP.
    }
  }

  Future<void> _sendFcmTokenToBackend(String fcmToken) async {
    try {
      final String? authToken = await TokenStorageService().getToken();

      if (authToken == null || authToken.trim().isEmpty) {
        return;
      }

      final Uri uri = ApiConstants.uri('/api/users/fcm-token');

      await http
          .post(
            uri,
            headers: <String, String>{
              ...ApiConstants.defaultHeaders,
              'Authorization': 'Bearer ${authToken.trim()}',
            },
            body: jsonEncode(
              <String, dynamic>{
                'fcmToken': fcmToken,
                'platform': 'android',
                'purpose': 'incoming_call',
              },
            ),
          )
          .timeout(ApiConstants.requestTimeout);
    } catch (_) {
      // Backend endpoint may not exist yet. Do not crash the app.
    }
  }

  Future<void> registerDeviceTokenAfterLogin() async {
    await _syncCurrentFcmToken();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(message.data);

    if (!_isIncomingCall(data)) {
      return;
    }

    _openIncomingCallScreen(data);
  }

  void _handleMessageOpened(Map<String, dynamic> rawData) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

    if (!_isIncomingCall(data)) {
      return;
    }

    _openIncomingCallScreen(data);
  }

  Future<void> _handleLocalNotificationResponse(
    Map<String, dynamic> payload,
    String? actionId,
  ) async {
    if (!_isIncomingCall(payload)) {
      return;
    }

    if (actionId == 'decline_call') {
      await _declineCall(payload);
      return;
    }

    final bool autoAccept = actionId == 'accept_call';

    _openIncomingCallScreen(
      payload,
      autoAccept: autoAccept,
    );
  }

  void _openIncomingCallScreen(
    Map<String, dynamic> data, {
    bool autoAccept = false,
  }) {
    final IncomingCallPayload payload = IncomingCallPayload.fromMap(data);

    if (payload.callId.trim().isNotEmpty &&
        _lastOpenedCallId == payload.callId) {
      return;
    }

    _lastOpenedCallId = payload.callId;

    final NavigatorState? navigator = navigatorKey.currentState;

    if (navigator == null) {
      return;
    }

    navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) {
          return IncomingCallScreen(
            payload: payload,
            autoAccept: autoAccept,
          );
        },
      ),
    );
  }

  Future<void> _declineCall(Map<String, dynamic> data) async {
    try {
      final IncomingCallPayload payload = IncomingCallPayload.fromMap(data);

      if (payload.callId.trim().isEmpty) {
        return;
      }

      final String? token = await TokenStorageService().getToken();

      final Uri uri = ApiConstants.uri(
        '/api/video/calls/${payload.callId}/decline',
      );

      await http
          .patch(
            uri,
            headers: <String, String>{
              ...ApiConstants.defaultHeaders,
              if (token != null && token.trim().isNotEmpty)
                'Authorization': 'Bearer ${token.trim()}',
            },
            body: jsonEncode(
              <String, dynamic>{
                'appointmentId': payload.appointmentId,
                'channelName': payload.channelName,
              },
            ),
          )
          .timeout(ApiConstants.requestTimeout);
    } catch (_) {
      // Ignore decline sync errors for MVP.
    }
  }
}

bool _isIncomingCall(Map<String, dynamic> data) {
  final dynamic type = data['type'];
  return type != null && type.toString() == 'incoming_call';
}