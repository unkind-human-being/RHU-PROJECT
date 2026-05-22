import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class AppointmentChatScreen extends StatefulWidget {
  const AppointmentChatScreen({
    super.key,
    this.appointment,
  });

  static const String routeName = '/appointment-chat';

  final Map<String, dynamic>? appointment;

  @override
  State<AppointmentChatScreen> createState() => _AppointmentChatScreenState();
}

class _AppointmentChatScreenState extends State<AppointmentChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  late final ApiClient _apiClient;

  bool _isLoading = false;
  bool _isSending = false;
  bool _isStartingVideoCall = false;
  bool _isCreatingPrescription = false;

  String? _errorMessage;

  Map<String, dynamic>? _appointment;
  List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];

  String get _appointmentId {
    final Map<String, dynamic>? appointment = _appointment;

    if (appointment == null) {
      return '';
    }

    return _readString(appointment, <String>['_id', 'id']);
  }

  bool get _isOnlineAppointment {
    final Map<String, dynamic>? appointment = _appointment;

    if (appointment == null) {
      return false;
    }

    return _readString(
          appointment,
          <String>['appointmentType', 'type'],
        ).toLowerCase() ==
        'online';
  }

  String get _videoChannelName {
    if (_appointmentId.trim().isEmpty) {
      return 'rhu_consultation';
    }

    return 'rhu_appointment_$_appointmentId';
  }

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    _appointment = widget.appointment;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _apiClient.close();

    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (_appointmentId.trim().isEmpty) {
      setState(() {
        _errorMessage =
            'Appointment data was not found. Open chat from an appointment record.';
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/consultation-messages/appointment/${Uri.encodeComponent(_appointmentId)}',
        requiresAuth: true,
      );

      final dynamic appointmentData = response['appointment'];
      final List<dynamic> rawMessages = _extractList(response);

      final List<Map<String, dynamic>> messages = rawMessages
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        if (appointmentData is Map<String, dynamic>) {
          _appointment = Map<String, dynamic>.from(appointmentData);
        }

        _messages = messages;
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
        _errorMessage = 'Unable to load consultation messages.';
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
      final dynamic records = data['records'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (messages is List) return messages;
      if (records is List) return records;
      if (results is List) return results;
      if (docs is List) return docs;
      if (items is List) return items;
    }

    final dynamic messages = response['messages'];

    if (messages is List) return messages;

    return <dynamic>[];
  }

  Map<String, dynamic> _extractMessageFromResponse(
    Map<String, dynamic> response,
  ) {
    final dynamic data = response['data'];

    if (data is Map<String, dynamic>) {
      final dynamic message = data['message'];

      if (message is Map<String, dynamic>) {
        return Map<String, dynamic>.from(message);
      }

      return Map<String, dynamic>.from(data);
    }

    final dynamic message = response['message'];

    if (message is Map<String, dynamic>) {
      return Map<String, dynamic>.from(message);
    }

    return Map<String, dynamic>.from(response);
  }

  Future<void> _sendTextMessage() async {
    final String body = _messageController.text.trim();

    if (body.isEmpty) {
      return;
    }

    if (_appointmentId.trim().isEmpty) {
      _showError('Appointment ID was not found.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSending = true;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.post(
        '/api/consultation-messages/appointment/${Uri.encodeComponent(_appointmentId)}/text',
        requiresAuth: true,
        body: <String, dynamic>{
          'body': body,
        },
      );

      final Map<String, dynamic> createdMessage =
          _extractMessageFromResponse(response);

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(createdMessage);
        _messageController.clear();
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to send message.');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendVideoCallInviteAndOpen() async {
    if (!_isOnlineAppointment) {
      _showError('Video call is only available for online consultations.');
      return;
    }

    if (_appointmentId.trim().isEmpty) {
      _showError('Appointment ID was not found.');
      return;
    }

    setState(() {
      _isStartingVideoCall = true;
    });

    String callId = '';

    try {
      final Map<String, dynamic> startCallResponse = await _apiClient.post(
        '/api/video/calls/start',
        requiresAuth: true,
        body: <String, dynamic>{
          'appointmentId': _appointmentId,
          'receiverId': _patientUserId(_appointment ?? <String, dynamic>{}),
          'channelName': _videoChannelName,
        },
      );

      callId = _extractCallId(startCallResponse);

      await _sendVideoCallChatBackup();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incoming video call sent to patient.'),
          backgroundColor: Color(0xFF2563EB),
        ),
      );

      _openVideoScreen(
        channelName: _videoChannelName,
        callId: callId,
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

      _showError('Unable to start incoming video call.');
    } finally {
      if (mounted) {
        setState(() {
          _isStartingVideoCall = false;
        });
      }
    }
  }

  Future<void> _sendVideoCallChatBackup() async {
    try {
      final Map<String, dynamic> response = await _apiClient.post(
        '/api/consultation-messages/appointment/${Uri.encodeComponent(_appointmentId)}/video-call',
        requiresAuth: true,
        body: <String, dynamic>{
          'videoChannelName': _videoChannelName,
          'body':
              'RHU Admin is calling you for your online consultation. Please accept the incoming call notification.',
        },
      );

      final Map<String, dynamic> createdMessage =
          _extractMessageFromResponse(response);

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(createdMessage);
      });
    } catch (_) {
      // The incoming call notification is the main action.
      // The chat backup should not block the video call.
    }
  }

  void _openVideoScreen({
    required String channelName,
    String callId = '',
  }) {
    Navigator.of(context).pushNamed(
      '/video-call',
      arguments: <String, dynamic>{
        'appointmentId': _appointmentId,
        'channelName': channelName,
        'callId': callId,
        'patientName': _patientName(_appointment ?? <String, dynamic>{}),
        'appointment': _appointment ?? <String, dynamic>{},
      },
    );
  }

  Future<void> _openPrescriptionCreator() async {
    if (_appointmentId.trim().isEmpty) {
      _showError('Appointment ID was not found.');
      return;
    }

    final Map<String, dynamic> appointment =
        _appointment ?? <String, dynamic>{};

    final Object? result = await Navigator.of(context).pushNamed(
      '/create-prescription',
      arguments: <String, dynamic>{
        'appointment': appointment,
        'appointmentId': _appointmentId,
        'requestedBy': appointment['requestedBy'],
        'patientUser': appointment['requestedBy'],
        'patientFirstName': _readString(
          appointment,
          <String>['patientFirstName'],
        ),
        'patientLastName': _readString(
          appointment,
          <String>['patientLastName'],
        ),
        'patientMiddleInitial': _readString(
          appointment,
          <String>['patientMiddleInitial'],
        ),
        'patientAge': _readString(
          appointment,
          <String>['patientAge'],
        ),
        'patientSex': _readString(
          appointment,
          <String>['patientSex'],
        ),
        'contactNumber': _readString(
          appointment,
          <String>['contactNumber'],
        ),
        'serviceType': _readString(
          appointment,
          <String>['serviceType'],
        ),
        'appointmentType': _readString(
          appointment,
          <String>['appointmentType'],
        ),
        'diagnosis': _readString(
          appointment,
          <String>[
            'consultationDiagnosis',
            'consultationNotes',
            'healthConcern',
          ],
        ),
        'rhu': appointment['rhu'],
      },
    );

    if (!mounted) {
      return;
    }

    if (result is Map<String, dynamic>) {
      await _sendCreatedPrescriptionToChat(result);
    }
  }

  Future<void> _sendCreatedPrescriptionToChat(
    Map<String, dynamic> prescription,
  ) async {
    if (_appointmentId.trim().isEmpty) {
      _showError('Appointment ID was not found.');
      return;
    }

    final List<Map<String, dynamic>> medicines =
        _extractPrescriptionMedicineList(prescription);

    if (medicines.isEmpty) {
      _showError('The created prescription has no medicine items.');
      return;
    }

    setState(() {
      _isCreatingPrescription = true;
      _isSending = true;
    });

    try {
      final String diagnosis = _readString(
        prescription,
        <String>['diagnosis'],
      );

      final String doctorName = _readString(
        prescription,
        <String>['doctorName'],
      );

      final String expiresAt = _readString(
        prescription,
        <String>['expiresAt'],
      );

      final Map<String, dynamic> response = await _apiClient.post(
        '/api/consultation-messages/appointment/${Uri.encodeComponent(_appointmentId)}/prescription',
        requiresAuth: true,
        body: <String, dynamic>{
          'diagnosis': diagnosis,
          'doctorName': doctorName,
          'expiresAt': expiresAt,
          'messageBody':
              'Your prescription QR is ready. Please show this at the pharmacy.',
          'medicines': medicines,
        },
      );

      final Map<String, dynamic> createdMessage =
          _extractMessageFromResponse(response);

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(createdMessage);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription QR sent to patient.'),
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

      _showError('Unable to send prescription QR to chat.');
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingPrescription = false;
          _isSending = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _extractPrescriptionMedicineList(
    Map<String, dynamic> prescription,
  ) {
    final dynamic rawMedicines = prescription['medicines'];

    if (rawMedicines is! List) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> medicines = <Map<String, dynamic>>[];

    for (final dynamic rawMedicine in rawMedicines) {
      if (rawMedicine is! Map<String, dynamic>) {
        continue;
      }

      medicines.add(<String, dynamic>{
        'medicine': _readMedicineId(rawMedicine['medicine']),
        'medicineName': _readString(
          rawMedicine,
          <String>['medicineName', 'name'],
        ),
        'genericName': _readString(
          rawMedicine,
          <String>['genericName'],
        ),
        'strength': _readString(
          rawMedicine,
          <String>['strength'],
        ),
        'dosageForm': _readString(
          rawMedicine,
          <String>['dosageForm'],
        ),
        'quantity': int.tryParse(
              _readString(
                rawMedicine,
                <String>['quantity'],
              ),
            ) ??
            1,
        'unit': _readString(
          rawMedicine,
          <String>['unit'],
        ),
        'instructions': _readString(
          rawMedicine,
          <String>['instructions'],
        ),
      });
    }

    return medicines;
  }

  void _showMessageDetails(Map<String, dynamic> message) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _MessageDetailsSheet(
          message: message,
          appointment: _appointment,
        );
      },
    );
  }

  String _extractCallId(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is Map<String, dynamic>) {
      final dynamic call = data['call'];

      if (call is Map<String, dynamic>) {
        final String callId = _readString(
          call,
          <String>['_id', 'id'],
        );

        if (callId.trim().isNotEmpty) {
          return callId;
        }
      }

      final dynamic payload = data['payload'];

      if (payload is Map<String, dynamic>) {
        return _readString(
          payload,
          <String>['callId', 'call_id', 'id'],
        );
      }
    }

    final dynamic call = response['call'];

    if (call is Map<String, dynamic>) {
      return _readString(
        call,
        <String>['_id', 'id'],
      );
    }

    return '';
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
    final Map<String, dynamic>? appointment = _appointment;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Appointment Chat',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading || _isSending ? null : _loadMessages,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _ChatHeader(
              appointment: appointment,
              isOnlineAppointment: _isOnlineAppointment,
              isCreatingPrescription: _isCreatingPrescription,
              isStartingVideoCall: _isStartingVideoCall,
              onSendPrescription:
                  _isSending ? null : _openPrescriptionCreator,
              onStartVideoCall: _isSending || _isStartingVideoCall
                  ? null
                  : _sendVideoCallInviteAndOpen,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMessages,
                child: _buildMessageList(),
              ),
            ),
            _MessageComposer(
              controller: _messageController,
              isSending: _isSending,
              isOnlineAppointment: _isOnlineAppointment,
              isStartingVideoCall: _isStartingVideoCall,
              onSend: _sendTextMessage,
              onSendPrescription: _openPrescriptionCreator,
              onStartVideoCall: _sendVideoCallInviteAndOpen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          _ErrorCard(
            message: _errorMessage!,
            onRetry: _loadMessages,
          ),
        ],
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: const <Widget>[
          _EmptyChatState(),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      itemCount: _messages.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> message = _messages[index];

        return _MessageBubble(
          message: message,
          onTap: () {
            _showMessageDetails(message);
          },
        );
      },
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.appointment,
    required this.isOnlineAppointment,
    required this.isCreatingPrescription,
    required this.isStartingVideoCall,
    required this.onSendPrescription,
    required this.onStartVideoCall,
  });

  final Map<String, dynamic>? appointment;
  final bool isOnlineAppointment;
  final bool isCreatingPrescription;
  final bool isStartingVideoCall;
  final VoidCallback? onSendPrescription;
  final VoidCallback? onStartVideoCall;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> safeAppointment =
        appointment ?? <String, dynamic>{};

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isOnlineAppointment
                  ? const Color(0xFFDBEAFE)
                  : const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isOnlineAppointment
                  ? Icons.video_call_rounded
                  : Icons.person_rounded,
              color: isOnlineAppointment
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF0EA5E9),
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _patientName(safeAppointment),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_prettyService(_readString(safeAppointment, <String>['serviceType']))} • ${_prettyAppointmentType(_readString(safeAppointment, <String>['appointmentType']))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Schedule: ${_formatDateTimeText(_readString(safeAppointment, <String>['scheduledAt']))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _HeaderActionButtons(
            isOnlineAppointment: isOnlineAppointment,
            isCreatingPrescription: isCreatingPrescription,
            isStartingVideoCall: isStartingVideoCall,
            onSendPrescription: onSendPrescription,
            onStartVideoCall: onStartVideoCall,
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButtons extends StatelessWidget {
  const _HeaderActionButtons({
    required this.isOnlineAppointment,
    required this.isCreatingPrescription,
    required this.isStartingVideoCall,
    required this.onSendPrescription,
    required this.onStartVideoCall,
  });

  final bool isOnlineAppointment;
  final bool isCreatingPrescription;
  final bool isStartingVideoCall;
  final VoidCallback? onSendPrescription;
  final VoidCallback? onStartVideoCall;

  @override
  Widget build(BuildContext context) {
    if (!isOnlineAppointment) {
      return SizedBox(
        width: 92,
        height: 42,
        child: _SmallHeaderButton(
          label: 'Rx QR',
          icon: Icons.qr_code_2_rounded,
          color: const Color(0xFF16A34A),
          isLoading: isCreatingPrescription,
          onTap: isCreatingPrescription ? null : onSendPrescription,
        ),
      );
    }

    return SizedBox(
      width: 104,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _SmallHeaderButton(
            label: 'Video',
            icon: Icons.video_call_rounded,
            color: const Color(0xFF2563EB),
            isLoading: isStartingVideoCall,
            onTap: isStartingVideoCall ? null : onStartVideoCall,
          ),
          const SizedBox(height: 7),
          _SmallHeaderButton(
            label: 'Rx QR',
            icon: Icons.qr_code_2_rounded,
            color: const Color(0xFF16A34A),
            isLoading: isCreatingPrescription,
            onTap: isCreatingPrescription ? null : onSendPrescription,
          ),
        ],
      ),
    );
  }
}

class _SmallHeaderButton extends StatelessWidget {
  const _SmallHeaderButton({
    required this.label,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.zero,
          minimumSize: const Size(92, 40),
          maximumSize: const Size(104, 40),
        ),
        onPressed: onTap,
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.isOnlineAppointment,
    required this.isStartingVideoCall,
    required this.onSend,
    required this.onSendPrescription,
    required this.onStartVideoCall,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool isOnlineAppointment;
  final bool isStartingVideoCall;
  final VoidCallback onSend;
  final VoidCallback onSendPrescription;
  final VoidCallback onStartVideoCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (isOnlineAppointment)
            IconButton(
              tooltip: 'Start Video Call',
              onPressed:
                  isSending || isStartingVideoCall ? null : onStartVideoCall,
              icon: const Icon(
                Icons.video_call_rounded,
                color: Color(0xFF2563EB),
              ),
            ),
          IconButton(
            tooltip: 'Create Prescription QR',
            onPressed: isSending ? null : onSendPrescription,
            icon: const Icon(
              Icons.medication_rounded,
              color: Color(0xFF16A34A),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              enabled: !isSending,
              decoration: InputDecoration(
                hintText: 'Message patient...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: Color(0xFFE5E7EB),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: Color(0xFFE5E7EB),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: Color(0xFF0EA5E9),
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (_) {
                if (!isSending) {
                  onSend();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            height: 46,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: isSending
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
              ),
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onTap,
  });

  final Map<String, dynamic> message;
  final VoidCallback onTap;

  String get _messageType {
    return _readString(message, <String>['messageType']);
  }

  bool get _isPrescriptionQr => _messageType == 'prescription_qr';

  bool get _isVideoCall => _messageType == 'video_call';

  Color get _bubbleColor {
    if (_isPrescriptionQr) return const Color(0xFFDCFCE7);
    if (_isVideoCall) return const Color(0xFFDBEAFE);

    return const Color(0xFFE0F2FE);
  }

  Color get _textColor {
    if (_isPrescriptionQr) return const Color(0xFF14532D);
    if (_isVideoCall) return const Color(0xFF1E40AF);

    return const Color(0xFF075985);
  }

  @override
  Widget build(BuildContext context) {
    final String body = _readString(message, <String>['body']);
    final String sentAt = _formatDateTimeText(
      _readString(message, <String>['sentAt', 'createdAt']),
    );

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: _bubbleColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(6),
            ),
            child: InkWell(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(6),
              ),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_isPrescriptionQr || _isVideoCall) ...<Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _isVideoCall
                                ? Icons.video_call_rounded
                                : Icons.qr_code_2_rounded,
                            color: _textColor,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isVideoCall
                                ? 'Video Call Invite'
                                : 'Prescription QR Sent',
                            style: TextStyle(
                              color: _textColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      body.trim().isEmpty ? 'No message body.' : body,
                      style: TextStyle(
                        color: _textColor,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sentAt,
                      style: TextStyle(
                        color: _textColor.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageDetailsSheet extends StatelessWidget {
  const _MessageDetailsSheet({
    required this.message,
    required this.appointment,
  });

  final Map<String, dynamic> message;
  final Map<String, dynamic>? appointment;

  bool get _isPrescriptionQr {
    return _readString(message, <String>['messageType']) == 'prescription_qr';
  }

  bool get _isVideoCall {
    return _readString(message, <String>['messageType']) == 'video_call';
  }

  @override
  Widget build(BuildContext context) {
    final String qrPayload = _readString(
      message,
      <String>['prescriptionQrPayload'],
    );

    final String videoChannelName = _readString(
      message,
      <String>['videoChannelName'],
    );

    final String body = _readString(message, <String>['body']);

    return DraggableScrollableSheet(
      initialChildSize: (_isPrescriptionQr || _isVideoCall) ? 0.82 : 0.45,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
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
              const SizedBox(height: 20),
              Text(
                _isVideoCall
                    ? 'Video Call Invite'
                    : _isPrescriptionQr
                        ? 'Prescription QR Message'
                        : 'Message',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body.trim().isEmpty ? 'No message body.' : body,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_isVideoCall && videoChannelName.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                _VideoCallCard(videoChannelName: videoChannelName),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      '/video-call',
                      arguments: <String, dynamic>{
                        'appointmentId': _readString(
                          appointment ?? <String, dynamic>{},
                          <String>['_id', 'id'],
                        ),
                        'channelName': videoChannelName,
                        'callId': _readString(
                          message,
                          <String>['callId', 'videoCallId'],
                        ),
                        'patientName': _patientName(
                          appointment ?? <String, dynamic>{},
                        ),
                        'appointment': appointment ?? <String, dynamic>{},
                      },
                    );
                  },
                  icon: const Icon(Icons.video_call_rounded),
                  label: const Text('Join Video Call'),
                ),
              ],
              if (_isPrescriptionQr && qrPayload.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                _PrescriptionQrCard(qrPayload: qrPayload),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VideoCallCard extends StatelessWidget {
  const _VideoCallCard({
    required this.videoChannelName,
  });

  final String videoChannelName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.video_call_rounded,
            color: Color(0xFF2563EB),
            size: 54,
          ),
          const SizedBox(height: 10),
          const Text(
            'Video Consultation',
            style: TextStyle(
              color: Color(0xFF1D4ED8),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Channel: $videoChannelName',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1E40AF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrescriptionQrCard extends StatelessWidget {
  const _PrescriptionQrCard({
    required this.qrPayload,
  });

  final String qrPayload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFBBF7D0),
        ),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'Prescription QR',
            style: TextStyle(
              color: Color(0xFF14532D),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Card(
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
                Icons.chat_bubble_outline_rounded,
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
              'Send instructions, start a video call, or create a prescription QR for the patient.',
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
              'Unable to load chat',
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

    return 'Unknown patient';
  }

  return parts.join(' ');
}

String _patientUserId(Map<String, dynamic> appointment) {
  final dynamic requestedBy = appointment['requestedBy'];

  if (requestedBy is Map<String, dynamic>) {
    return _readString(
      requestedBy,
      <String>['_id', 'id'],
    );
  }

  if (requestedBy is String) {
    return requestedBy.trim();
  }

  return _readString(
    appointment,
    <String>[
      'requestedBy',
      'requestedById',
      'publicUser',
      'publicUserId',
      'patientUser',
      'patientUserId',
    ],
  );
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

String _formatDateTime(DateTime dateTime) {
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

String _readMedicineId(dynamic value) {
  if (value == null) {
    return '';
  }

  if (value is Map<String, dynamic>) {
    return _readString(value, <String>['_id', 'id']);
  }

  return value.toString().trim();
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