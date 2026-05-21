import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage_service.dart';

class NotificationBadgeButton extends StatefulWidget {
  const NotificationBadgeButton({
    super.key,
    this.iconColor,
    this.routeName = '/notifications',
    this.tooltip = 'Notifications',
  });

  final Color? iconColor;
  final String routeName;
  final String tooltip;

  @override
  State<NotificationBadgeButton> createState() =>
      _NotificationBadgeButtonState();
}

class _NotificationBadgeButtonState extends State<NotificationBadgeButton> {
  late final ApiClient _apiClient;

  int _unreadCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/notifications/unread-count',
        requiresAuth: true,
      );

      final int unreadCount = int.tryParse(
            _readString(response, <String>['unreadCount']),
          ) ??
          0;

      if (!mounted) {
        return;
      }

      setState(() {
        _unreadCount = unreadCount;
      });
    } catch (_) {
      // Do not show an error here. The full Notification Center screen
      // will display errors if there is a real connection issue.
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).pushNamed(widget.routeName);

    if (!mounted) {
      return;
    }

    await _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final String badgeText = _unreadCount > 99 ? '99+' : _unreadCount.toString();

    return IconButton(
      tooltip: widget.tooltip,
      onPressed: _openNotifications,
      icon: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Icon(
            Icons.notifications_rounded,
            color: widget.iconColor,
          ),
          if (_unreadCount > 0)
            Positioned(
              top: -7,
              right: -7,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  badgeText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final String key in keys) {
    final dynamic value = json[key];

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
