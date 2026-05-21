import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  static const String routeName = '/notifications';

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  late final ApiClient _apiClient;

  bool _isLoading = false;
  bool _isMarkingAll = false;
  String? _errorMessage;

  String _selectedFilter = 'all';

  List<Map<String, dynamic>> _notifications = <Map<String, dynamic>>[];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedFilter == 'all') {
      return _notifications;
    }

    if (_selectedFilter == 'unread') {
      return _notifications.where((Map<String, dynamic> notification) {
        return !_readBool(notification, 'isRead', fallback: false);
      }).toList();
    }

    if (_selectedFilter == 'read') {
      return _notifications.where((Map<String, dynamic> notification) {
        return _readBool(notification, 'isRead', fallback: false);
      }).toList();
    }

    return _notifications.where((Map<String, dynamic> notification) {
      return _readString(notification, <String>['type']) == _selectedFilter;
    }).toList();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/notifications/my',
        requiresAuth: true,
        queryParameters: <String, dynamic>{
          'limit': 100,
        },
      );

      final List<dynamic> rawNotifications = _extractList(response);

      final List<Map<String, dynamic>> notifications = rawNotifications
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();

      notifications.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime bDate = _readDateTime(
          b,
          <String>['createdAt'],
        );
        final DateTime aDate = _readDateTime(
          a,
          <String>['createdAt'],
        );

        return bDate.compareTo(aDate);
      });

      final int unreadCount = int.tryParse(
            _readString(response, <String>['unreadCount']),
          ) ??
          notifications.where((Map<String, dynamic> notification) {
            return !_readBool(notification, 'isRead', fallback: false);
          }).length;

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to load notifications.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> _extractList(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      final dynamic notifications = data['notifications'];
      final dynamic records = data['records'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (notifications is List) {
        return notifications;
      }

      if (records is List) {
        return records;
      }

      if (results is List) {
        return results;
      }

      if (docs is List) {
        return docs;
      }

      if (items is List) {
        return items;
      }
    }

    final dynamic notifications = response['notifications'];

    if (notifications is List) {
      return notifications;
    }

    return <dynamic>[];
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final bool isRead = _readBool(notification, 'isRead', fallback: false);

    if (isRead) {
      return;
    }

    final String notificationId = _readString(
      notification,
      <String>['_id', 'id'],
    );

    if (notificationId.trim().isEmpty) {
      return;
    }

    try {
      await _apiClient.patch(
        '/api/notifications/${Uri.encodeComponent(notificationId)}/read',
        requiresAuth: true,
        body: <String, dynamic>{},
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final int index = _notifications.indexWhere(
          (Map<String, dynamic> item) {
            return _readString(item, <String>['_id', 'id']) == notificationId;
          },
        );

        if (index >= 0) {
          final Map<String, dynamic> updatedNotification =
              Map<String, dynamic>.from(_notifications[index]);
          updatedNotification['isRead'] = true;
          updatedNotification['readAt'] = DateTime.now().toIso8601String();

          _notifications[index] = updatedNotification;
          _unreadCount = (_unreadCount - 1).clamp(0, 999999);
        }
      });
    } catch (_) {
      // Do not block navigation if mark-read fails.
    }
  }

  Future<void> _markAllAsRead() async {
    if (_unreadCount <= 0) {
      return;
    }

    setState(() {
      _isMarkingAll = true;
    });

    try {
      await _apiClient.patch(
        '/api/notifications/read-all',
        requiresAuth: true,
        body: <String, dynamic>{},
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = _notifications.map((Map<String, dynamic> item) {
          final Map<String, dynamic> updated = Map<String, dynamic>.from(item);
          updated['isRead'] = true;
          updated['readAt'] = DateTime.now().toIso8601String();
          return updated;
        }).toList();
        _unreadCount = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to mark notifications as read.');
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingAll = false;
        });
      }
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    await _markAsRead(notification);

    if (!mounted) {
      return;
    }

    final String targetRoute = _readString(
      notification,
      <String>['targetRoute'],
    );

    if (targetRoute.trim().isEmpty) {
      _showNotificationDetails(notification);
      return;
    }

    Navigator.of(context).pushNamed(targetRoute);
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _NotificationDetailsSheet(notification: notification);
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> filteredNotifications =
        _filteredNotifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadNotifications,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Mark all as read',
            onPressed:
                _isLoading || _isMarkingAll || _unreadCount <= 0 ? null : _markAllAsRead,
            icon: _isMarkingAll
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                    ),
                  )
                : const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadNotifications,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _HeaderCard(
                    totalCount: _notifications.length,
                    unreadCount: _unreadCount,
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _FilterHeaderDelegate(
                  selectedFilter: _selectedFilter,
                  onChanged: (String value) {
                    setState(() {
                      _selectedFilter = value;
                    });
                  },
                ),
              ),
              if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _ErrorCard(
                      message: _errorMessage!,
                      onRetry: _loadNotifications,
                    ),
                  ),
                )
              else if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _LoadingBox(),
                  ),
                )
              else if (filteredNotifications.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _EmptyState(),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: filteredNotifications.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> notification =
                        filteredNotifications[index];

                    return Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: index == 0 ? 12 : 0,
                        bottom: 12,
                      ),
                      child: _NotificationCard(
                        notification: notification,
                        onTap: () {
                          _openNotification(notification);
                        },
                        onLongPress: () {
                          _showNotificationDetails(notification);
                        },
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.totalCount,
    required this.unreadCount,
  });

  final int totalCount;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0EA5E9),
            Color(0xFF0284C7),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 34,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Notification Center',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'View appointment, QR, prescription, event, survey, and pharmacy updates.',
            style: TextStyle(
              color: Color(0xFFE0F2FE),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderMetric(
                  label: 'Total',
                  value: totalCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Unread',
                  value: unreadCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE0F2FE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterHeaderDelegate({
    required this.selectedFilter,
    required this.onChanged,
  });

  final String selectedFilter;
  final ValueChanged<String> onChanged;

  @override
  double get minExtent => 74;

  @override
  double get maxExtent => 74;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _FilterChipButton(
            label: 'All',
            value: 'all',
            selectedValue: selectedFilter,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Unread',
            value: 'unread',
            selectedValue: selectedFilter,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Read',
            value: 'read',
            selectedValue: selectedFilter,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Appointments',
            value: 'appointment_accepted',
            selectedValue: selectedFilter,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'QR',
            value: 'walk_in_qr_generated',
            selectedValue: selectedFilter,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Prescription',
            value: 'prescription_qr_received',
            selectedValue: selectedFilter,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Events',
            value: 'event_registration_confirmed',
            selectedValue: selectedFilter,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Surveys',
            value: 'survey_submitted',
            selectedValue: selectedFilter,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return oldDelegate.selectedFilter != selectedFilter;
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool selected = value == selectedValue;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        selectedColor: const Color(0xFF0EA5E9),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF075985),
          fontWeight: FontWeight.w900,
        ),
        side: BorderSide(
          color: selected ? const Color(0xFF0EA5E9) : const Color(0xFFBAE6FD),
        ),
        onSelected: (_) {
          onChanged(value);
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onLongPress,
  });

  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final String type = _readString(notification, <String>['type']);
    final bool isRead = _readBool(notification, 'isRead', fallback: false);
    final Color color = _notificationColor(type);

    return Card(
      color: isRead ? Colors.white : const Color(0xFFF0F9FF),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isRead ? const Color(0xFFE5E7EB) : const Color(0xFF7DD3FC),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Icon(
                      _notificationIcon(type),
                      color: color,
                      size: 30,
                    ),
                  ),
                  if (!isRead)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _readString(
                        notification,
                        <String>['title'],
                        fallback: 'Notification',
                      ),
                      style: TextStyle(
                        color: const Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: isRead ? FontWeight.w800 : FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _readString(notification, <String>['body']),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Text(
                          _prettyNotificationType(type),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '•',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatDateTimeText(
                              _readString(notification, <String>['createdAt']),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _readString(notification, <String>['targetRoute']).isEmpty
                    ? Icons.info_outline_rounded
                    : Icons.chevron_right_rounded,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationDetailsSheet extends StatelessWidget {
  const _NotificationDetailsSheet({
    required this.notification,
  });

  final Map<String, dynamic> notification;

  @override
  Widget build(BuildContext context) {
    final String type = _readString(notification, <String>['type']);
    final Color color = _notificationColor(type);

    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(22),
            children: <Widget>[
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: <Widget>[
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _notificationIcon(type),
                      color: color,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _readString(
                        notification,
                        <String>['title'],
                        fallback: 'Notification',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailsSection(
                title: 'Notification Details',
                children: <Widget>[
                  _InfoLine(
                    label: 'Type',
                    value: _prettyNotificationType(type),
                  ),
                  _InfoLine(
                    label: 'Date',
                    value: _formatDateTimeText(
                      _readString(notification, <String>['createdAt']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Status',
                    value: _readBool(notification, 'isRead', fallback: false)
                        ? 'Read'
                        : 'Unread',
                  ),
                  _InfoLine(
                    label: 'Target',
                    value: _fallback(
                      _readString(notification, <String>['targetRoute']),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DetailsSection(
                title: 'Message',
                children: <Widget>[
                  Text(
                    _fallback(
                      _readString(notification, <String>['body']),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.done_rounded),
                label: const Text('Done'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(
          color: Color(0xFFE5E7EB),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 14),
            Expanded(
              child: Text('Loading notifications...'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF0EA5E9),
              size: 54,
            ),
            SizedBox(height: 16),
            Text(
              'No notifications found',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your appointment, QR, event, survey, and prescription notices will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load notifications',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

Color _notificationColor(String type) {
  if (type.contains('appointment') || type.contains('qr')) {
    return const Color(0xFF0EA5E9);
  }

  if (type.contains('prescription') || type.contains('pharmacy')) {
    return const Color(0xFF16A34A);
  }

  if (type.contains('event')) {
    return const Color(0xFF2563EB);
  }

  if (type.contains('survey')) {
    return const Color(0xFF7C3AED);
  }

  return const Color(0xFF64748B);
}

IconData _notificationIcon(String type) {
  if (type.contains('appointment')) {
    return Icons.event_available_rounded;
  }

  if (type.contains('qr')) {
    return Icons.qr_code_2_rounded;
  }

  if (type.contains('prescription')) {
    return Icons.medication_rounded;
  }

  if (type.contains('pharmacy')) {
    return Icons.local_pharmacy_rounded;
  }

  if (type.contains('event')) {
    return Icons.event_rounded;
  }

  if (type.contains('survey')) {
    return Icons.poll_rounded;
  }

  return Icons.notifications_rounded;
}

String _prettyNotificationType(String type) {
  switch (type) {
    case 'appointment_submitted':
      return 'Appointment Submitted';
    case 'appointment_accepted':
      return 'Appointment Accepted';
    case 'appointment_rejected':
      return 'Appointment Rejected';
    case 'walk_in_qr_generated':
      return 'Walk-in QR';
    case 'prescription_qr_received':
      return 'Prescription QR';
    case 'prescription_claimed':
      return 'Prescription Claimed';
    case 'event_registration_confirmed':
      return 'Event Registration';
    case 'event_registration_received':
      return 'New Event Registrant';
    case 'survey_submitted':
      return 'Survey Submitted';
    case 'survey_response_received':
      return 'New Survey Response';
    case 'pharmacy_claim_synced':
      return 'Pharmacy Claim Synced';
    case 'pharmacy_claim_pending':
      return 'Pharmacy Claim Pending';
    default:
      return _prettyEnum(type);
  }
}

String _prettyEnum(String value) {
  if (value.trim().isEmpty) {
    return 'General';
  }

  return value
      .split('_')
      .where((String item) => item.trim().isNotEmpty)
      .map((String item) {
    return item[0].toUpperCase() + item.substring(1);
  }).join(' ');
}

String _fallback(String value) {
  if (value.trim().isEmpty || value.trim() == 'null') {
    return 'N/A';
  }

  return value.trim();
}

bool _readBool(
  Map<String, dynamic> json,
  String key, {
  required bool fallback,
}) {
  final dynamic value = json[key];

  if (value is bool) {
    return value;
  }

  if (value is String) {
    return value.toLowerCase() == 'true';
  }

  return fallback;
}

DateTime _readDateTime(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value == null) {
      continue;
    }

    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      continue;
    }
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _formatDateTime(DateTime dateTime) {
  if (dateTime.year <= 1971) {
    return 'N/A';
  }

  final String year = dateTime.year.toString().padLeft(4, '0');
  final String month = dateTime.month.toString().padLeft(2, '0');
  final String day = dateTime.day.toString().padLeft(2, '0');

  final int hour12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final String minute = dateTime.minute.toString().padLeft(2, '0');
  final String period = dateTime.hour >= 12 ? 'PM' : 'AM';

  return '$year-$month-$day $hour12:$minute $period';
}

String _formatDateTimeText(String value) {
  if (value.trim().isEmpty || value.trim() == 'null') {
    return 'N/A';
  }

  try {
    return _formatDateTime(DateTime.parse(value).toLocal());
  } catch (_) {
    return value;
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

    if (value is Map<String, dynamic>) {
      final String nestedValue = _readString(
        value,
        <String>['name', 'title', 'fullName', 'email', '_id', 'id'],
      );

      if (nestedValue.trim().isNotEmpty) {
        return nestedValue;
      }
    }

    final String text = value.toString().trim();

    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }

  return fallback;
}
