import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    super.key,
    this.appointmentId,
    this.channelName,
    this.patientName,
  });

  static const String routeName = '/video-call';

  final String? appointmentId;
  final String? channelName;
  final String? patientName;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RtcEngine? _engine;
  late final ApiClient _apiClient;

  String _appointmentId = '';
  String _channelName = 'rhu_consultation';
  String _patientName = 'Patient';

  String _agoraAppId = '';
  String _agoraToken = '';
  int _localUid = 0;

  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isInitializing = true;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _hasLoggedJoined = false;
  bool _hasLoggedEnded = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final Object? args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, dynamic>) {
      _appointmentId =
          args['appointmentId']?.toString() ?? widget.appointmentId ?? _appointmentId;
      _channelName =
          args['channelName']?.toString() ?? widget.channelName ?? _channelName;
      _patientName =
          args['patientName']?.toString() ?? widget.patientName ?? _patientName;
    } else {
      _appointmentId = widget.appointmentId ?? _appointmentId;
      _channelName = widget.channelName ?? _channelName;
      _patientName = widget.patientName ?? _patientName;
    }
  }

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAgora();
    });
  }

  @override
  void dispose() {
    _leaveAndRelease();
    _apiClient.close();
    super.dispose();
  }

  Future<void> _runAgoraStep(
    String step,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      throw Exception(
        'Agora failed at $step: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _runOptionalAgoraStep(
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      // Optional Agora actions should not block the video call.
    }
  }

  Future<void> _fetchAgoraToken() async {
    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/video/agora-token',
        requiresAuth: true,
        queryParameters: <String, dynamic>{
          'channelName': _channelName,
        },
      );

      final dynamic data = response['data'];

      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid Agora token response.');
      }

      final String appId = data['appId']?.toString() ?? '';
      final String token = data['token']?.toString() ?? '';
      final int uid = int.tryParse(data['uid']?.toString() ?? '') ?? 0;

      if (appId.trim().isEmpty) {
        throw Exception('Agora App ID was not returned by the backend.');
      }

      if (token.trim().isEmpty) {
        throw Exception('Agora token was not returned by the backend.');
      }

      if (uid <= 0) {
        throw Exception('Agora UID was not returned by the backend.');
      }

      _agoraAppId = appId;
      _agoraToken = token;
      _localUid = uid;
    } on ApiException catch (error) {
      throw Exception(error.message);
    } catch (error) {
      throw Exception(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _logVideoCallJoined() async {
    if (_hasLoggedJoined) {
      return;
    }

    if (_channelName.trim().isEmpty || _localUid <= 0) {
      return;
    }

    _hasLoggedJoined = true;

    try {
      await _apiClient.post(
        '/api/video/calls/joined',
        requiresAuth: true,
        body: <String, dynamic>{
          'channelName': _channelName,
          'uid': _localUid,
        },
      );
    } catch (_) {
      // Do not interrupt the video call if logging fails.
    }
  }

  Future<void> _logVideoCallEnded() async {
    if (_hasLoggedEnded) {
      return;
    }

    if (_channelName.trim().isEmpty) {
      return;
    }

    _hasLoggedEnded = true;

    try {
      await _apiClient.post(
        '/api/video/calls/ended',
        requiresAuth: true,
        body: <String, dynamic>{
          'channelName': _channelName,
        },
      );
    } catch (_) {
      // Do not block leaving the call if logging fails.
    }
  }

  Future<void> _initializeAgora() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _remoteUid = null;
      _localUserJoined = false;
      _hasLoggedJoined = false;
      _hasLoggedEnded = false;
    });

    try {
      if (_channelName.trim().isEmpty || _channelName == 'rhu_consultation') {
        throw Exception('Valid video channel name is missing.');
      }

      await _leaveAndRelease();

      await _fetchAgoraToken();

      final Map<Permission, PermissionStatus> statuses =
          await <Permission>[
        Permission.microphone,
        Permission.camera,
      ].request();

      final bool microphoneGranted =
          statuses[Permission.microphone]?.isGranted ?? false;
      final bool cameraGranted = statuses[Permission.camera]?.isGranted ?? false;

      if (!microphoneGranted || !cameraGranted) {
        throw Exception('Camera and microphone permission are required.');
      }

      final RtcEngine engine = createAgoraRtcEngine();

      if (!mounted) {
        return;
      }

      setState(() {
        _engine = engine;
      });

      await _runAgoraStep(
        'initialize engine',
        () async {
          await engine.initialize(
            RtcEngineContext(
              appId: _agoraAppId,
              channelProfile: ChannelProfileType.channelProfileCommunication,
            ),
          );
        },
      );

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (
            RtcConnection connection,
            int elapsed,
          ) async {
            await _logVideoCallJoined();

            if (!mounted) {
              return;
            }

            setState(() {
              _localUserJoined = true;
            });

            await _runOptionalAgoraStep(() async {
              await engine.setEnableSpeakerphone(true);
            });

            await _runOptionalAgoraStep(() async {
              await engine.startPreview();
            });
          },
          onUserJoined: (
            RtcConnection connection,
            int remoteUid,
            int elapsed,
          ) {
            if (!mounted) {
              return;
            }

            setState(() {
              _remoteUid = remoteUid;
            });
          },
          onUserOffline: (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
          ) {
            if (!mounted) {
              return;
            }

            setState(() {
              if (_remoteUid == remoteUid) {
                _remoteUid = null;
              }
            });
          },
          onError: (
            ErrorCodeType errorCode,
            String message,
          ) {
            if (!mounted) {
              return;
            }

            setState(() {
              _errorMessage = 'Agora error: $errorCode $message';
            });
          },
        ),
      );

      await _runAgoraStep(
        'enable video',
        () async {
          await engine.enableVideo();
        },
      );

      await _runAgoraStep(
        'enable audio',
        () async {
          await engine.enableAudio();
        },
      );

      await _runOptionalAgoraStep(() async {
        await engine.startPreview();
      });

      await _runAgoraStep(
        'join channel',
        () async {
          await engine.joinChannel(
            token: _agoraToken,
            channelId: _channelName,
            uid: _localUid,
            options: const ChannelMediaOptions(
              channelProfile: ChannelProfileType.channelProfileCommunication,
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
              publishCameraTrack: true,
              publishMicrophoneTrack: true,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isInitializing = false;
      });
    }
  }

  Future<void> _leaveAndRelease() async {
    final RtcEngine? engine = _engine;

    if (engine == null) {
      return;
    }

    try {
      await engine.leaveChannel();
      await engine.release();
    } catch (_) {
      // Ignore cleanup errors.
    } finally {
      if (mounted) {
        setState(() {
          _engine = null;
          _localUserJoined = false;
          _remoteUid = null;
        });
      }
    }
  }

  Future<void> _toggleMute() async {
    final RtcEngine? engine = _engine;

    if (engine == null) {
      return;
    }

    final bool nextValue = !_isMuted;

    await _runOptionalAgoraStep(() async {
      await engine.muteLocalAudioStream(nextValue);
    });

    if (!mounted) {
      return;
    }

    setState(() {
      _isMuted = nextValue;
    });
  }

  Future<void> _toggleCamera() async {
    final RtcEngine? engine = _engine;

    if (engine == null) {
      return;
    }

    final bool nextValue = !_isCameraOff;

    await _runOptionalAgoraStep(() async {
      await engine.muteLocalVideoStream(nextValue);
    });

    if (!mounted) {
      return;
    }

    setState(() {
      _isCameraOff = nextValue;
    });
  }

  Future<void> _switchCamera() async {
    final RtcEngine? engine = _engine;

    if (engine == null) {
      return;
    }

    await _runOptionalAgoraStep(() async {
      await engine.switchCamera();
    });
  }

  Future<void> _toggleSpeaker() async {
    final RtcEngine? engine = _engine;

    if (engine == null) {
      return;
    }

    final bool nextValue = !_isSpeakerOn;

    await _runOptionalAgoraStep(() async {
      await engine.setEnableSpeakerphone(nextValue);
    });

    if (!mounted) {
      return;
    }

    setState(() {
      _isSpeakerOn = nextValue;
    });
  }

  Future<void> _endCall() async {
    await _logVideoCallEnded();
    await _leaveAndRelease();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Widget _buildRemoteVideo() {
    final RtcEngine? engine = _engine;
    final int? remoteUid = _remoteUid;

    if (engine == null || remoteUid == null) {
      return _WaitingForPatientCard(
        patientName: _patientName,
        channelName: _channelName,
      );
    }

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: remoteUid),
        connection: RtcConnection(channelId: _channelName),
      ),
    );
  }

  Widget _buildLocalPreview() {
    final RtcEngine? engine = _engine;

    if (engine == null || !_localUserJoined || _isCameraOff) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          _isCameraOff ? Icons.videocam_off_rounded : Icons.person_rounded,
          color: Colors.white,
          size: 34,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine,
          canvas: VideoCanvas(uid: _localUid),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (
        bool didPop,
        Object? result,
      ) async {
        if (didPop) {
          return;
        }

        await _endCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          title: const Text(
            'Video Consultation',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SafeArea(
          child: _isInitializing
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                )
              : _errorMessage != null
                  ? _VideoErrorState(
                      message: _errorMessage!,
                      onRetry: _initializeAgora,
                      onBack: _endCall,
                    )
                  : Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: _buildRemoteVideo(),
                        ),
                        Positioned(
                          top: 18,
                          left: 18,
                          right: 18,
                          child: _TopCallInfo(
                            patientName: _patientName,
                            channelName: _channelName,
                            appointmentId: _appointmentId,
                            remoteJoined: _remoteUid != null,
                          ),
                        ),
                        Positioned(
                          top: 128,
                          right: 18,
                          child: SizedBox(
                            width: 112,
                            height: 156,
                            child: _buildLocalPreview(),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          right: 18,
                          bottom: 22,
                          child: _CallControls(
                            isMuted: _isMuted,
                            isCameraOff: _isCameraOff,
                            isSpeakerOn: _isSpeakerOn,
                            onToggleMute: _toggleMute,
                            onToggleCamera: _toggleCamera,
                            onSwitchCamera: _switchCamera,
                            onToggleSpeaker: _toggleSpeaker,
                            onEndCall: _endCall,
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _TopCallInfo extends StatelessWidget {
  const _TopCallInfo({
    required this.patientName,
    required this.channelName,
    required this.appointmentId,
    required this.remoteJoined,
  });

  final String patientName;
  final String channelName;
  final String appointmentId;
  final bool remoteJoined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            remoteJoined ? Icons.verified_rounded : Icons.hourglass_top_rounded,
            color: remoteJoined
                ? const Color(0xFF22C55E)
                : const Color(0xFFFBBF24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  remoteJoined ? 'Connected' : 'Waiting for other user',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$patientName • $channelName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (appointmentId.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    'Appointment: $appointmentId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingForPatientCard extends StatelessWidget {
  const _WaitingForPatientCard({
    required this.patientName,
    required this.channelName,
  });

  final String patientName;
  final String channelName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFF334155),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.video_call_rounded,
                  color: Colors.white,
                  size: 54,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                patientName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Waiting for the other user to join the video consultation.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFCBD5E1),
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                channelName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF93C5FD),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallControls extends StatelessWidget {
  const _CallControls({
    required this.isMuted,
    required this.isCameraOff,
    required this.isSpeakerOn,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onSwitchCamera,
    required this.onToggleSpeaker,
    required this.onEndCall,
  });

  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onEndCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _RoundControlButton(
            icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            backgroundColor:
                isMuted ? const Color(0xFF475569) : const Color(0xFF334155),
            onTap: onToggleMute,
          ),
          _RoundControlButton(
            icon: isCameraOff
                ? Icons.videocam_off_rounded
                : Icons.videocam_rounded,
            backgroundColor: isCameraOff
                ? const Color(0xFF475569)
                : const Color(0xFF334155),
            onTap: onToggleCamera,
          ),
          _RoundControlButton(
            icon: Icons.cameraswitch_rounded,
            backgroundColor: const Color(0xFF334155),
            onTap: onSwitchCamera,
          ),
          _RoundControlButton(
            icon: isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            backgroundColor:
                isSpeakerOn ? const Color(0xFF334155) : const Color(0xFF475569),
            onTap: onToggleSpeaker,
          ),
          _RoundControlButton(
            icon: Icons.call_end_rounded,
            backgroundColor: const Color(0xFFDC2626),
            onTap: onEndCall,
          ),
        ],
      ),
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  const _RoundControlButton({
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: IconButton.filled(
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
        ),
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}

class _VideoErrorState extends StatelessWidget {
  const _VideoErrorState({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF334155),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFF87171),
                size: 52,
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to start video call',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(0xFF64748B),
                        ),
                      ),
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                      ),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}