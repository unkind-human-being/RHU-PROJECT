import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../core/storage/token_storage_service.dart';

class IncomingCallPayload {
  const IncomingCallPayload({
    required this.callId,
    required this.appointmentId,
    required this.channelName,
    required this.callerName,
    required this.rhuName,
  });

  factory IncomingCallPayload.fromMap(Map<String, dynamic> data) {
    return IncomingCallPayload(
      callId: _readString(
        data,
        <String>[
          'callId',
          'call_id',
          'id',
        ],
      ),
      appointmentId: _readString(
        data,
        <String>[
          'appointmentId',
          'appointment_id',
        ],
      ),
      channelName: _readString(
        data,
        <String>[
          'channelName',
          'channel_name',
          'channel',
        ],
      ),
      callerName: _readString(
        data,
        <String>[
          'callerName',
          'caller_name',
          'fromName',
        ],
        fallback: 'RHU Admin',
      ),
      rhuName: _readString(
        data,
        <String>[
          'rhuName',
          'rhu_name',
          'officeName',
        ],
        fallback: 'RHU Video Consultation',
      ),
    );
  }

  final String callId;
  final String appointmentId;
  final String channelName;
  final String callerName;
  final String rhuName;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'callId': callId,
      'appointmentId': appointmentId,
      'channelName': channelName,
      'callerName': callerName,
      'rhuName': rhuName,
    };
  }

  Map<String, dynamic> toVideoCallArguments() {
    return <String, dynamic>{
      'callId': callId,
      'appointmentId': appointmentId,
      'channelName': channelName,
      'callerName': callerName,
      'rhuName': rhuName,
    };
  }
}

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.payload,
    this.autoAccept = false,
  });

  static const String routeName = '/incoming-call';

  final IncomingCallPayload payload;
  final bool autoAccept;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.autoAccept) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _acceptCall();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _syncCallStatus(String action) async {
    final String callId = widget.payload.callId.trim();

    if (callId.isEmpty) {
      return;
    }

    final String? token = await TokenStorageService().getToken();

    final Uri uri = ApiConstants.uri(
      '/api/video/calls/$callId/$action',
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
              'appointmentId': widget.payload.appointmentId,
              'channelName': widget.payload.channelName,
            },
          ),
        )
        .timeout(ApiConstants.requestTimeout);
  }

  Future<void> _acceptCall() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await _syncCallStatus('accept');
    } catch (_) {
      // Do not block the call screen if the status sync fails.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessing = false;
    });

    Navigator.of(context).pushReplacementNamed(
      '/video-call',
      arguments: widget.payload.toVideoCallArguments(),
    );
  }

  Future<void> _declineCall() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await _syncCallStatus('decline');
    } catch (_) {
      // Ignore status sync error for MVP.
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final IncomingCallPayload payload = widget.payload;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF022C22),
        body: SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFF022C22),
                  Color(0xFF064E3B),
                  Color(0xFF0F766E),
                ],
              ),
            ),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 32),
                const Text(
                  'Incoming RHU Video Call',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Video consultation request',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD1FAE5),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (BuildContext context, Widget? child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 138,
                    height: 138,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.26),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.video_call_rounded,
                      color: Colors.white,
                      size: 78,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                Text(
                  payload.callerName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  payload.rhuName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD1FAE5),
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Tap accept to join the consultation',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (_isProcessing) ...<Widget>[
                  const CircularProgressIndicator(
                    color: Colors.white,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Connecting...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ] else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      _CallActionButton(
                        label: 'Decline',
                        icon: Icons.call_end_rounded,
                        color: const Color(0xFFDC2626),
                        onTap: _declineCall,
                      ),
                      _CallActionButton(
                        label: 'Accept',
                        icon: Icons.videocam_rounded,
                        color: const Color(0xFF22C55E),
                        onTap: _acceptCall,
                      ),
                    ],
                  ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
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