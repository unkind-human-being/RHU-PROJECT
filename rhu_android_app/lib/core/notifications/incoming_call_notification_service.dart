import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class IncomingCallNotificationService {
  IncomingCallNotificationService._();

  static final IncomingCallNotificationService instance =
      IncomingCallNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'rhu_incoming_calls';
  static const String channelName = 'RHU Incoming Calls';
  static const String channelDescription =
      'Full-screen notifications for RHU video consultation calls.';

  bool _initialized = false;

  Future<void> Function(
    Map<String, dynamic> payload,
    String? actionId,
  )? onNotificationResponse;

  Future<void> initialize({
    Future<void> Function(
      Map<String, dynamic> payload,
      String? actionId,
    )? onResponse,
  }) async {
    if (_initialized) {
      if (onResponse != null) {
        onNotificationResponse = onResponse;
      }

      return;
    }

    onNotificationResponse = onResponse;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          incomingCallNotificationBackgroundTap,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> showIncomingCallNotification({
    required Map<String, dynamic> payload,
  }) async {
    await initialize();

    final String callerName = _readString(
      payload,
      <String>[
        'callerName',
        'caller_name',
        'fromName',
      ],
      fallback: 'RHU Admin',
    );

    final String rhuName = _readString(
      payload,
      <String>[
        'rhuName',
        'rhu_name',
        'officeName',
      ],
      fallback: 'RHU Video Consultation',
    );

    final int notificationId = _notificationIdFromPayload(payload);
    final String encodedPayload = jsonEncode(payload);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      ticker: 'Incoming RHU video call',
      timeoutAfter: 60000,
      icon: '@mipmap/ic_launcher',
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'accept_call',
          'Accept',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'decline_call',
          'Decline',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      notificationId,
      'Incoming RHU Video Call',
      '$callerName • $rhuName',
      notificationDetails,
      payload: encodedPayload,
    );
  }

  Future<void> cancelIncomingCallNotification({
    required Map<String, dynamic> payload,
  }) async {
    final int notificationId = _notificationIdFromPayload(payload);

    await _plugin.cancel(notificationId);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final Map<String, dynamic> payload = _decodePayload(response.payload);

    if (payload.isEmpty) {
      return;
    }

    onNotificationResponse?.call(payload, response.actionId);
  }

  Map<String, dynamic> _decodePayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final dynamic decoded = jsonDecode(payload);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  int _notificationIdFromPayload(Map<String, dynamic> payload) {
    final String callId = _readString(
      payload,
      <String>[
        'callId',
        'call_id',
        'id',
      ],
      fallback: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    int hash = 0;

    for (int index = 0; index < callId.length; index += 1) {
      hash = (hash * 31 + callId.codeUnitAt(index)) & 0x7fffffff;
    }

    return hash == 0 ? 7117 : hash;
  }
}

@pragma('vm:entry-point')
void incomingCallNotificationBackgroundTap(NotificationResponse response) {
  // Required background callback entry point.
}

String _readString(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final String key in keys) {
    final dynamic value = data[key];

    if (value == null) {
      continue;
    }

    final String text = value.toString().trim();

    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }

  return fallback;
}