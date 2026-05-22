import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'medicine_sync_channel';
  static const String _channelName = 'Medicine Sync';
  static const String _channelDescription =
      'Notifications for medicine transaction syncing.';

  static bool _initialized = false;

  static Future<void> initialize({
    bool requestPermission = true,
  }) async {
    if (_initialized) {
      return;
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(settings);

    if (requestPermission) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  static Future<void> showMedicineSyncSuccess({
    required int syncedCount,
  }) async {
    await initialize(requestPermission: false);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    final String body = syncedCount == 1
        ? '1 pending medicine transaction was synced successfully.'
        : '$syncedCount pending medicine transactions were synced successfully.';

    await _plugin.show(
      1001,
      'Medicine transactions synced',
      body,
      details,
    );
  }

  static Future<void> showSimpleNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize(requestPermission: false);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      id,
      title,
      body,
      details,
    );
  }
}