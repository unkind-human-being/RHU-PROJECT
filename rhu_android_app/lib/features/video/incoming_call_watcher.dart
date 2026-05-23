import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/token_storage_service.dart';
import 'incoming_call_screen.dart';

class IncomingCallWatcher extends StatefulWidget {
  const IncomingCallWatcher({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<IncomingCallWatcher> createState() => _IncomingCallWatcherState();
}

class _IncomingCallWatcherState extends State<IncomingCallWatcher> {
  Timer? _timer;
  late final ApiClient _apiClient;

  bool _isChecking = false;
  String? _lastOpenedCallId;

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient(
      tokenProvider: TokenStorageService().getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startWatcher();
    });
  }

  @override
  void didUpdateWidget(covariant IncomingCallWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _startWatcher();
      } else {
        _stopWatcher();
      }
    }
  }

  @override
  void dispose() {
    _stopWatcher();
    _apiClient.close();
    super.dispose();
  }

  void _startWatcher() {
    if (!widget.enabled) {
      return;
    }

    _timer?.cancel();

    _checkIncomingCall();

    _timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        _checkIncomingCall();
      },
    );
  }

  void _stopWatcher() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkIncomingCall() async {
    if (!mounted || !widget.enabled || _isChecking) {
      return;
    }

    _isChecking = true;

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/video/calls/incoming',
        requiresAuth: true,
      );

      final Map<String, dynamic>? payload = _extractIncomingPayload(response);

      if (payload == null) {
        return;
      }

      final IncomingCallPayload callPayload =
          IncomingCallPayload.fromMap(payload);

      if (callPayload.callId.trim().isEmpty) {
        return;
      }

      if (_lastOpenedCallId == callPayload.callId) {
        return;
      }

      _lastOpenedCallId = callPayload.callId;

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) {
            return IncomingCallScreen(
              payload: callPayload,
            );
          },
        ),
      );
    } catch (_) {
      // Silent fail. The watcher should not disturb the user.
    } finally {
      _isChecking = false;
    }
  }

  Map<String, dynamic>? _extractIncomingPayload(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data == null) {
      return null;
    }

    if (data is Map<String, dynamic>) {
      final dynamic payload = data['payload'];

      if (payload is Map<String, dynamic>) {
        return Map<String, dynamic>.from(payload);
      }

      final dynamic call = data['call'];

      if (call is Map<String, dynamic>) {
        return <String, dynamic>{
          'type': 'incoming_call',
          'callId': _readString(call, <String>['_id', 'id']),
          'appointmentId': _readRelationId(call['appointment']),
          'channelName': _readString(call, <String>['channelName']),
          'callerName': _readString(
            call,
            <String>['callerName'],
            fallback: 'RHU Admin',
          ),
          'rhuName': _readString(
            call,
            <String>['rhuName'],
            fallback: 'RHU Video Consultation',
          ),
        };
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
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
      final String nested = _readString(
        value,
        <String>['_id', 'id', 'name', 'fullName'],
      );

      if (nested.trim().isNotEmpty) {
        return nested;
      }
    }

    final String text = value.toString().trim();

    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }

  return fallback;
}

String _readRelationId(dynamic value) {
  if (value == null) {
    return '';
  }

  if (value is String) {
    return value.trim();
  }

  if (value is Map<String, dynamic>) {
    return _readString(value, <String>['_id', 'id']);
  }

  return value.toString().trim();
}