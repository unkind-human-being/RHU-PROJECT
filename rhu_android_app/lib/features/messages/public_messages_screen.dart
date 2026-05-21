import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class PublicMessagesScreen extends StatefulWidget {
  const PublicMessagesScreen({super.key});

  static const String routeName = '/public-messages';

  @override
  State<PublicMessagesScreen> createState() => _PublicMessagesScreenState();
}

class _PublicMessagesScreenState extends State<PublicMessagesScreen> {
  late final ApiClient _apiClient;

  bool _isLoading = false;
  String? _errorMessage;

  List<_AppointmentMessageGroup> _messageGroups = <_AppointmentMessageGroup>[];

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> appointmentResponse = await _apiClient.get(
        '/api/appointments/my',
        requiresAuth: true,
        queryParameters: <String, dynamic>{
          'limit': 100,
        },
      );

      final List<dynamic> rawAppointments = _extractList(appointmentResponse);

      final List<Map<String, dynamic>> appointments = rawAppointments
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();

      final List<_AppointmentMessageGroup> groups =
          <_AppointmentMessageGroup>[];

      for (final Map<String, dynamic> appointment in appointments) {
        final String appointmentId = _readString(
          appointment,
          <String>['_id', 'id'],
        );

        if (appointmentId.trim().isEmpty) {
          continue;
        }

        try {
          final Map<String, dynamic> messageResponse = await _apiClient.get(
            '/api/consultation-messages/appointment/${Uri.encodeComponent(appointmentId)}',
            requiresAuth: true,
          );

          final List<dynamic> rawMessages = _extractList(messageResponse);

          final List<Map<String, dynamic>> messages = rawMessages
              .whereType<Map<String, dynamic>>()
              .map((Map<String, dynamic> item) {
            return Map<String, dynamic>.from(item);
          }).toList();

          if (messages.isNotEmpty) {
            groups.add(
              _AppointmentMessageGroup(
                appointment: appointment,
                messages: messages,
              ),
            );
          }
        } catch (_) {
          // Keep loading other appointment message threads.
        }
      }

      groups.sort(
        (_AppointmentMessageGroup a, _AppointmentMessageGroup b) {
          return b.latestMessageDate.compareTo(a.latestMessageDate);
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messageGroups = groups;
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
        _errorMessage = 'Unable to load your RHU messages.';
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
      final dynamic messages = data['messages'];
      final dynamic appointments = data['appointments'];
      final dynamic records = data['records'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (messages is List) {
        return messages;
      }

      if (appointments is List) {
        return appointments;
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

    final dynamic messages = response['messages'];
    final dynamic appointments = response['appointments'];

    if (messages is List) {
      return messages;
    }

    if (appointments is List) {
      return appointments;
    }

    return <dynamic>[];
  }

  void _openMessageGroup(_AppointmentMessageGroup group) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _MessageThreadSheet(group: group);
      },
    );
  }

  int get _totalMessages {
    int total = 0;

    for (final _AppointmentMessageGroup group in _messageGroups) {
      total += group.messages.length;
    }

    return total;
  }

  int get _prescriptionQrCount {
    int total = 0;

    for (final _AppointmentMessageGroup group in _messageGroups) {
      total += group.messages.where((Map<String, dynamic> message) {
        return _readString(message, <String>['messageType']) ==
            'prescription_qr';
      }).length;
    }

    return total;
  }

  int get _videoCallCount {
    int total = 0;

    for (final _AppointmentMessageGroup group in _messageGroups) {
      total += group.messages.where((Map<String, dynamic> message) {
        return _readString(message, <String>['messageType']) == 'video_call';
      }).length;
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        title: const Text(
          'Messages',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadMessages,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMessages,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _HeaderCard(
                    threadCount: _messageGroups.length,
                    messageCount: _totalMessages,
                    qrCount: _prescriptionQrCount,
                    videoCount: _videoCallCount,
                  ),
                ),
              ),
              if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _ErrorCard(
                      message: _errorMessage!,
                      onRetry: _loadMessages,
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
              else if (_messageGroups.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _EmptyState(),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: _messageGroups.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _AppointmentMessageGroup group =
                        _messageGroups[index];

                    return Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: index == 0 ? 12 : 0,
                        bottom: 12,
                      ),
                      child: _MessageThreadCard(
                        group: group,
                        onTap: () {
                          _openMessageGroup(group);
                        },
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 90),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentMessageGroup {
  const _AppointmentMessageGroup({
    required this.appointment,
    required this.messages,
  });

  final Map<String, dynamic> appointment;
  final List<Map<String, dynamic>> messages;

  DateTime get latestMessageDate {
    if (messages.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final Map<String, dynamic> latest = messages.last;

    return _readDateTime(
      latest,
      <String>['sentAt', 'createdAt'],
    );
  }

  Map<String, dynamic> get latestMessage {
    if (messages.isEmpty) {
      return <String, dynamic>{};
    }

    return messages.last;
  }

  bool get hasPrescriptionQr {
    return messages.any((Map<String, dynamic> message) {
      return _readString(message, <String>['messageType']) ==
          'prescription_qr';
    });
  }

  bool get hasVideoCall {
    return messages.any((Map<String, dynamic> message) {
      return _readString(message, <String>['messageType']) == 'video_call';
    });
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.threadCount,
    required this.messageCount,
    required this.qrCount,
    required this.videoCount,
  });

  final int threadCount;
  final int messageCount;
  final int qrCount;
  final int videoCount;

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
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 34,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'RHU Messages',
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
            'View RHU messages, video call invites, and prescription QR codes. Public users cannot reply here.',
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
                  label: 'Threads',
                  value: threadCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Messages',
                  value: messageCount.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderMetric(
                  label: 'Video',
                  value: videoCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Rx QR',
                  value: qrCount.toString(),
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

class _MessageThreadCard extends StatelessWidget {
  const _MessageThreadCard({
    required this.group,
    required this.onTap,
  });

  final _AppointmentMessageGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> latestMessage = group.latestMessage;

    final String latestType = _readString(
      latestMessage,
      <String>['messageType'],
    );

    final bool latestIsQr = latestType == 'prescription_qr';
    final bool latestIsVideo = latestType == 'video_call';

    final Color iconBackground = latestIsVideo
        ? const Color(0xFFDBEAFE)
        : latestIsQr
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFE0F2FE);

    final Color iconColor = latestIsVideo
        ? const Color(0xFF2563EB)
        : latestIsQr
            ? const Color(0xFF16A34A)
            : const Color(0xFF0EA5E9);

    final IconData icon = latestIsVideo
        ? Icons.video_call_rounded
        : latestIsQr
            ? Icons.qr_code_2_rounded
            : Icons.chat_bubble_rounded;

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(
          color: Color(0xFFBAE6FD),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _prettyService(
                        _readString(
                          group.appointment,
                          <String>['serviceType'],
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _readString(latestMessage, <String>['body']).isEmpty
                          ? 'No message body.'
                          : _readString(latestMessage, <String>['body']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${group.messages.length} message(s) • ${_formatDateTime(group.latestMessageDate)}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (group.hasVideoCall)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.video_call_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
              if (group.hasPrescriptionQr)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.medication_rounded,
                    color: Color(0xFF16A34A),
                  ),
                ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF0EA5E9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageThreadSheet extends StatelessWidget {
  const _MessageThreadSheet({
    required this.group,
  });

  final _AppointmentMessageGroup group;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.95,
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
            padding: const EdgeInsets.all(18),
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
              const SizedBox(height: 20),
              _ThreadHeader(appointment: group.appointment),
              const SizedBox(height: 14),
              const _ReadOnlyNotice(),
              const SizedBox(height: 14),
              ...group.messages.map(
                (Map<String, dynamic> message) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PublicMessageBubble(
                      message: message,
                      appointment: group.appointment,
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_rounded),
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

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.appointment,
  });

  final Map<String, dynamic> appointment;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(
          color: Color(0xFFE5E7EB),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.local_hospital_rounded,
                color: Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _prettyService(
                      _readString(appointment, <String>['serviceType']),
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_prettyAppointmentType(_readString(appointment, <String>['appointmentType']))} • ${_formatDateTimeText(_readString(appointment, <String>['scheduledAt']))}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFDE68A),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFD97706),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is a read-only message thread. RHU Admin can send messages, video call invites, and prescription QR codes here.',
              style: TextStyle(
                color: Color(0xFF92400E),
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicMessageBubble extends StatelessWidget {
  const _PublicMessageBubble({
    required this.message,
    required this.appointment,
  });

  final Map<String, dynamic> message;
  final Map<String, dynamic> appointment;

  String get _messageType {
    return _readString(message, <String>['messageType']);
  }

  bool get _isPrescriptionQr => _messageType == 'prescription_qr';

  bool get _isVideoCall => _messageType == 'video_call';

  Color get _accentColor {
    if (_isVideoCall) {
      return const Color(0xFF2563EB);
    }

    if (_isPrescriptionQr) {
      return const Color(0xFF16A34A);
    }

    return const Color(0xFF0EA5E9);
  }

  Color get _backgroundColor {
    if (_isVideoCall) {
      return const Color(0xFFDBEAFE);
    }

    if (_isPrescriptionQr) {
      return const Color(0xFFDCFCE7);
    }

    return Colors.white;
  }

  Color get _borderColor {
    if (_isVideoCall) {
      return const Color(0xFFBFDBFE);
    }

    if (_isPrescriptionQr) {
      return const Color(0xFFBBF7D0);
    }

    return const Color(0xFFE5E7EB);
  }

  IconData get _icon {
    if (_isVideoCall) {
      return Icons.video_call_rounded;
    }

    if (_isPrescriptionQr) {
      return Icons.qr_code_2_rounded;
    }

    return Icons.chat_bubble_rounded;
  }

  String get _title {
    if (_isVideoCall) {
      return 'Video Call Invite';
    }

    if (_isPrescriptionQr) {
      return 'Prescription QR';
    }

    return 'Message from RHU Admin';
  }

  void _joinVideoCall(BuildContext context, String videoChannelName) {
    Navigator.of(context).pushNamed(
      '/video-call',
      arguments: <String, dynamic>{
        'appointmentId': _readString(appointment, <String>['_id', 'id']),
        'channelName': videoChannelName,
        'patientName': _patientName(appointment),
        'appointment': appointment,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String body = _readString(message, <String>['body']);
    final String qrPayload = _readString(
      message,
      <String>['prescriptionQrPayload'],
    );
    final String videoChannelName = _readString(
      message,
      <String>['videoChannelName'],
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  _icon,
                  color: _accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _title,
                    style: TextStyle(
                      color: _accentColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  _formatDateTimeText(
                    _readString(message, <String>['sentAt', 'createdAt']),
                  ),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body.trim().isEmpty ? 'No message body.' : body,
              style: TextStyle(
                color: _isVideoCall
                    ? const Color(0xFF1E3A8A)
                    : _isPrescriptionQr
                        ? const Color(0xFF14532D)
                        : const Color(0xFF334155),
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_isVideoCall && videoChannelName.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFBFDBFE),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    const Icon(
                      Icons.video_call_rounded,
                      color: Color(0xFF2563EB),
                      size: 42,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Online Consultation Room',
                      style: TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Channel: $videoChannelName',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF1E40AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                        ),
                        onPressed: () {
                          _joinVideoCall(context, videoChannelName);
                        },
                        icon: const Icon(Icons.video_call_rounded),
                        label: const Text(
                          'Join Video Call',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_isPrescriptionQr && qrPayload.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: 230,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Show this QR code to the pharmacist.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF166534),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 14),
            Expanded(
              child: Text('Loading RHU messages...'),
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
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.mark_chat_unread_outlined,
                color: Color(0xFF0EA5E9),
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'When RHU Admin sends a consultation message, video call invite, or prescription QR, it will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
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
      color: Colors.white,
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
              'Unable to load messages',
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

String _patientName(Map<String, dynamic> appointment) {
  final String firstName = _readString(
    appointment,
    <String>['patientFirstName'],
  );

  final String middleInitial = _readString(
    appointment,
    <String>['patientMiddleInitial'],
  );

  final String lastName = _readString(
    appointment,
    <String>['patientLastName'],
  );

  final List<String> parts = <String>[
    firstName,
    middleInitial,
    lastName,
  ].where((String item) => item.trim().isNotEmpty).toList();

  if (parts.isEmpty) {
    final dynamic requestedBy = appointment['requestedBy'];

    if (requestedBy is Map<String, dynamic>) {
      final String fullName = _readString(
        requestedBy,
        <String>['fullName', 'email'],
      );

      if (fullName.trim().isNotEmpty) {
        return fullName;
      }
    }

    return 'Patient';
  }

  return parts.join(' ');
}

String _prettyService(String value) {
  switch (value) {
    case 'medical_consultation':
      return 'Medical Consultation';
    case 'maternal_care':
      return 'Maternal Care';
    case 'family_planning':
      return 'Family Planning';
    case 'screening_prevention':
      return 'Screening & Prevention';
    case 'dental_services':
      return 'Dental Services';
    case 'immunization':
      return 'Immunization';
    default:
      return _prettyEnum(value);
  }
}

String _prettyAppointmentType(String value) {
  switch (value) {
    case 'walk_in':
      return 'Walk-in';
    case 'online':
      return 'Online Consultation';
    default:
      return _prettyEnum(value);
  }
}

String _prettyEnum(String value) {
  if (value.trim().isEmpty) {
    return 'N/A';
  }

  return value
      .split('_')
      .where((String item) => item.trim().isNotEmpty)
      .map((String item) {
    return item[0].toUpperCase() + item.substring(1);
  }).join(' ');
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
  List<String> keys,
) {
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

  return '';
}
