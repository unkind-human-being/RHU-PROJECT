import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class ManageAppointmentsScreen extends StatefulWidget {
  const ManageAppointmentsScreen({super.key});

  static const String routeName = '/manage-appointments';

  @override
  State<ManageAppointmentsScreen> createState() =>
      _ManageAppointmentsScreenState();
}

class _ManageAppointmentsScreenState extends State<ManageAppointmentsScreen> {
  late final ApiClient _apiClient;

  bool _isLoading = false;
  bool _isUpdating = false;

  String _selectedStatus = 'pending';
  String? _errorMessage;

  List<Map<String, dynamic>> _appointments = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAppointments();
    });
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/appointments',
        requiresAuth: true,
        queryParameters: <String, dynamic>{
          if (_selectedStatus != 'all') 'status': _selectedStatus,
          'limit': 100,
        },
      );

      final List<dynamic> rawAppointments = _extractList(response);

      final List<Map<String, dynamic>> appointments = rawAppointments
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _appointments = appointments;
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
        _errorMessage = 'Unable to load appointment requests.';
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
      final dynamic appointments = data['appointments'];
      final dynamic records = data['records'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (appointments is List) return appointments;
      if (records is List) return records;
      if (results is List) return results;
      if (docs is List) return docs;
      if (items is List) return items;
    }

    final dynamic appointments = response['appointments'];

    if (appointments is List) {
      return appointments;
    }

    return <dynamic>[];
  }

  Map<String, dynamic> _extractMap(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    return response;
  }

  void _setStatusFilter(String status) {
    setState(() {
      _selectedStatus = status;
    });

    _loadAppointments();
  }

  Future<void> _acceptAppointment(Map<String, dynamic> appointment) async {
    final _AcceptAppointmentInput? input =
        await showDialog<_AcceptAppointmentInput>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _AcceptAppointmentDialog(
          appointment: appointment,
        );
      },
    );

    if (input == null) {
      return;
    }

    final String appointmentId = _readString(
      appointment,
      <String>['_id', 'id'],
    );

    if (appointmentId.trim().isEmpty) {
      _showError('Appointment ID was not found.');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.patch(
        '/api/appointments/$appointmentId/accept',
        requiresAuth: true,
        body: <String, dynamic>{
          'scheduledAt': input.scheduledAt.toIso8601String(),
          if (input.scheduledEndAt != null)
            'scheduledEndAt': input.scheduledEndAt!.toIso8601String(),
          if (input.qrExpiresAt != null)
            'qrExpiresAt': input.qrExpiresAt!.toIso8601String(),
          'adminNotes': input.adminNotes,
        },
      );

      final Map<String, dynamic> updatedAppointment = _extractMap(response);

      if (!mounted) {
        return;
      }

      _replaceAppointment(updatedAppointment);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment accepted successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      _showAppointmentDetails(updatedAppointment);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to accept appointment.');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _rejectAppointment(Map<String, dynamic> appointment) async {
    final TextEditingController reasonController = TextEditingController();

    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Reject Appointment',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SizedBox(
            width: 460,
            child: TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason optional',
                hintText: 'Example: RHU unavailable on the requested date.',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () {
                Navigator.of(context).pop(reasonController.text.trim());
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Reject'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null) {
      return;
    }

    final String appointmentId = _readString(
      appointment,
      <String>['_id', 'id'],
    );

    if (appointmentId.trim().isEmpty) {
      _showError('Appointment ID was not found.');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.patch(
        '/api/appointments/$appointmentId/reject',
        requiresAuth: true,
        body: <String, dynamic>{
          'rejectionReason': reason,
        },
      );

      final Map<String, dynamic> updatedAppointment = _extractMap(response);

      if (!mounted) {
        return;
      }

      _replaceAppointment(updatedAppointment);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment rejected.'),
          backgroundColor: Color(0xFFDC2626),
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

      _showError('Unable to reject appointment.');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _completeAppointment(Map<String, dynamic> appointment) async {
    final _CompleteAppointmentInput? input =
        await showDialog<_CompleteAppointmentInput>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _CompleteAppointmentDialog(
          appointment: appointment,
        );
      },
    );

    if (input == null) {
      return;
    }

    final String appointmentId = _readString(
      appointment,
      <String>['_id', 'id'],
    );

    if (appointmentId.trim().isEmpty) {
      _showError('Appointment ID was not found.');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.patch(
        '/api/appointments/$appointmentId/complete',
        requiresAuth: true,
        body: input.toJson(),
      );

      final Map<String, dynamic> updatedAppointment = _extractMap(response);

      if (!mounted) {
        return;
      }

      _replaceAppointment(updatedAppointment);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consultation completed successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      _showAppointmentDetails(updatedAppointment);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to complete consultation.');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _replaceAppointment(Map<String, dynamic> updatedAppointment) {
    final String updatedId = _readString(
      updatedAppointment,
      <String>['_id', 'id'],
    );

    setState(() {
      final int index = _appointments.indexWhere(
        (Map<String, dynamic> item) {
          return _readString(item, <String>['_id', 'id']) == updatedId;
        },
      );

      if (index >= 0) {
        _appointments[index] = updatedAppointment;
      } else {
        _appointments.insert(0, updatedAppointment);
      }

      if (_selectedStatus != 'all') {
        _appointments = _appointments.where((Map<String, dynamic> item) {
          return _readString(item, <String>['status']) == _selectedStatus;
        }).toList();
      }
    });
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    final Map<String, dynamic> appointmentForChat =
        Map<String, dynamic>.from(appointment);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _AppointmentDetailsSheet(
          appointment: appointment,
          isUpdating: _isUpdating,
          onAccept: () {
            Navigator.of(sheetContext).pop();
            _acceptAppointment(appointment);
          },
          onReject: () {
            Navigator.of(sheetContext).pop();
            _rejectAppointment(appointment);
          },
          onComplete: () {
            Navigator.of(sheetContext).pop();
            _completeAppointment(appointment);
          },
          onOpenChat: () {
            Navigator.of(sheetContext).pop();

            Future<void>.delayed(
              const Duration(milliseconds: 180),
              () {
                if (!mounted) {
                  return;
                }

                Navigator.of(context).pushNamed(
                  '/appointment-chat',
                  arguments: appointmentForChat,
                );
              },
            );
          },
        );
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
    final int visibleCount = _appointments.length;

    final int pendingCount = _appointments.where((Map<String, dynamic> item) {
      return _readString(item, <String>['status']) == 'pending';
    }).length;

    final int acceptedCount = _appointments.where((Map<String, dynamic> item) {
      return _readString(item, <String>['status']) == 'accepted';
    }).length;

    final int completedCount = _appointments.where((Map<String, dynamic> item) {
      return _readString(item, <String>['status']) == 'completed';
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF9),
      appBar: AppBar(
        title: const Text(
          'Appointment Requests',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading || _isUpdating ? null : _loadAppointments,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAppointments,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _HeaderCard(
                    visibleCount: visibleCount,
                    pendingCount: pendingCount,
                    acceptedCount: acceptedCount,
                    completedCount: completedCount,
                    selectedStatus: _selectedStatus,
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StatusFilterHeaderDelegate(
                  selectedStatus: _selectedStatus,
                  onChanged: _setStatusFilter,
                ),
              ),
              if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _ErrorCard(
                      message: _errorMessage!,
                      onRetry: _loadAppointments,
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
              else if (_appointments.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _EmptyState(),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: _appointments.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> appointment =
                        _appointments[index];

                    return Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: index == 0 ? 12 : 0,
                        bottom: 12,
                      ),
                      child: _AppointmentCard(
                        appointment: appointment,
                        isUpdating: _isUpdating,
                        onTap: () {
                          _showAppointmentDetails(appointment);
                        },
                        onAccept: () {
                          _acceptAppointment(appointment);
                        },
                        onReject: () {
                          _rejectAppointment(appointment);
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

class _AcceptAppointmentInput {
  const _AcceptAppointmentInput({
    required this.scheduledAt,
    required this.adminNotes,
    this.scheduledEndAt,
    this.qrExpiresAt,
  });

  final DateTime scheduledAt;
  final DateTime? scheduledEndAt;
  final DateTime? qrExpiresAt;
  final String adminNotes;
}

class _CompleteAppointmentInput {
  const _CompleteAppointmentInput({
    required this.consultationDiagnosis,
    required this.consultationNotes,
    required this.followUpInstructions,
    required this.adminNotes,
    this.followUpDate,
  });

  final String consultationDiagnosis;
  final String consultationNotes;
  final String followUpInstructions;
  final String adminNotes;
  final DateTime? followUpDate;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'consultationDiagnosis': consultationDiagnosis,
      'consultationNotes': consultationNotes,
      'followUpInstructions': followUpInstructions,
      'adminNotes': adminNotes,
      'followUpDate': followUpDate?.toIso8601String(),
    };
  }
}

class _AcceptAppointmentDialog extends StatefulWidget {
  const _AcceptAppointmentDialog({
    required this.appointment,
  });

  final Map<String, dynamic> appointment;

  @override
  State<_AcceptAppointmentDialog> createState() =>
      _AcceptAppointmentDialogState();
}

class _AcceptAppointmentDialogState extends State<_AcceptAppointmentDialog> {
  final TextEditingController _adminNotesController = TextEditingController();

  late DateTime _scheduledAt;
  late DateTime _scheduledEndAt;
  late DateTime _qrExpiresAt;

  bool get _isWalkIn {
    return _readString(widget.appointment, <String>['appointmentType']) ==
        'walk_in';
  }

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();

    _scheduledAt = now.add(const Duration(days: 1));
    _scheduledAt = DateTime(
      _scheduledAt.year,
      _scheduledAt.month,
      _scheduledAt.day,
      9,
      0,
    );

    _scheduledEndAt = _scheduledAt.add(const Duration(minutes: 30));
    _qrExpiresAt = _scheduledAt.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _adminNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledAt() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );

    if (date == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );

    if (time == null) {
      return;
    }

    final DateTime newScheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      _scheduledAt = newScheduledAt;
      _scheduledEndAt = newScheduledAt.add(const Duration(minutes: 30));

      if (_isWalkIn) {
        _qrExpiresAt = newScheduledAt.add(const Duration(hours: 2));
      }
    });
  }

  Future<void> _pickQrExpiresAt() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _qrExpiresAt,
      firstDate: _scheduledAt,
      lastDate: _scheduledAt.add(const Duration(days: 7)),
    );

    if (date == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_qrExpiresAt),
    );

    if (time == null) {
      return;
    }

    setState(() {
      _qrExpiresAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    Navigator.of(context).pop(
      _AcceptAppointmentInput(
        scheduledAt: _scheduledAt,
        scheduledEndAt: _scheduledEndAt,
        qrExpiresAt: _isWalkIn ? _qrExpiresAt : null,
        adminNotes: _adminNotesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String typeLabel = _prettyAppointmentType(
      _readString(widget.appointment, <String>['appointmentType']),
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: const Text(
        'Accept Appointment',
        style: TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _DialogInfoBox(
                icon: _isWalkIn
                    ? Icons.meeting_room_rounded
                    : Icons.video_call_rounded,
                title: typeLabel,
                subtitle: _isWalkIn
                    ? 'A walk-in QR ticket will be generated after acceptance.'
                    : 'Online consultation will be scheduled and chat/video will be available.',
                color: _isWalkIn
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF2563EB),
              ),
              const SizedBox(height: 14),
              _PickerTile(
                label: 'Schedule date/time',
                value: _formatDateTime(_scheduledAt),
                icon: Icons.event_rounded,
                onTap: _pickScheduledAt,
              ),
              const SizedBox(height: 12),
              _PickerTile(
                label: 'Estimated end time',
                value: _formatDateTime(_scheduledEndAt),
                icon: Icons.schedule_rounded,
                onTap: null,
              ),
              if (_isWalkIn) ...<Widget>[
                const SizedBox(height: 12),
                _PickerTile(
                  label: 'QR ticket expires',
                  value: _formatDateTime(_qrExpiresAt),
                  icon: Icons.qr_code_2_rounded,
                  onTap: _pickQrExpiresAt,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _adminNotesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Admin notes optional',
                  hintText: 'Example: Please arrive 15 minutes early.',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Accept'),
        ),
      ],
    );
  }
}

class _CompleteAppointmentDialog extends StatefulWidget {
  const _CompleteAppointmentDialog({
    required this.appointment,
  });

  final Map<String, dynamic> appointment;

  @override
  State<_CompleteAppointmentDialog> createState() =>
      _CompleteAppointmentDialogState();
}

class _CompleteAppointmentDialogState
    extends State<_CompleteAppointmentDialog> {
  late final TextEditingController _diagnosisController;
  late final TextEditingController _notesController;
  late final TextEditingController _followUpInstructionsController;
  late final TextEditingController _adminNotesController;

  DateTime? _followUpDate;

  @override
  void initState() {
    super.initState();

    _diagnosisController = TextEditingController(
      text: _readString(
        widget.appointment,
        <String>['consultationDiagnosis'],
      ),
    );

    _notesController = TextEditingController(
      text: _readString(
        widget.appointment,
        <String>['consultationNotes'],
      ),
    );

    _followUpInstructionsController = TextEditingController(
      text: _readString(
        widget.appointment,
        <String>['followUpInstructions'],
      ),
    );

    _adminNotesController = TextEditingController(
      text: _readString(
        widget.appointment,
        <String>['adminNotes'],
      ),
    );

    final String savedFollowUpDate = _readString(
      widget.appointment,
      <String>['followUpDate'],
    );

    if (savedFollowUpDate.trim().isNotEmpty) {
      try {
        _followUpDate = DateTime.parse(savedFollowUpDate).toLocal();
      } catch (_) {
        _followUpDate = null;
      }
    }
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    _followUpInstructionsController.dispose();
    _adminNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickFollowUpDate() async {
    final DateTime now = DateTime.now();

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _followUpDate == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay.fromDateTime(_followUpDate!),
    );

    if (time == null) {
      return;
    }

    setState(() {
      _followUpDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _clearFollowUpDate() {
    setState(() {
      _followUpDate = null;
    });
  }

  void _submit() {
    final String diagnosis = _diagnosisController.text.trim();
    final String notes = _notesController.text.trim();

    if (diagnosis.isEmpty && notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add diagnosis or consultation notes.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );

      return;
    }

    Navigator.of(context).pop(
      _CompleteAppointmentInput(
        consultationDiagnosis: diagnosis,
        consultationNotes: notes,
        followUpInstructions: _followUpInstructionsController.text.trim(),
        adminNotes: _adminNotesController.text.trim(),
        followUpDate: _followUpDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 22,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
      ),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      title: const Text(
        'Complete Consultation',
        style: TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _DialogInfoBox(
                icon: Icons.assignment_turned_in_rounded,
                title: _patientName(widget.appointment),
                subtitle:
                    'Add the consultation result before marking this appointment as completed.',
                color: const Color(0xFF16A34A),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _diagnosisController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis / assessment',
                  hintText: 'Example: Acute upper respiratory tract infection',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.medical_information_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Consultation notes',
                  hintText:
                      'Write findings, advice, treatment discussion, or consultation summary.',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _followUpInstructionsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Follow-up instructions optional',
                  hintText:
                      'Example: Return after 3 days if fever continues. Drink water and rest.',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.follow_the_signs_rounded),
                ),
              ),
              const SizedBox(height: 12),
              _PickerTile(
                label: 'Follow-up date optional',
                value: _followUpDate == null
                    ? 'No follow-up date'
                    : _formatDateTime(_followUpDate!),
                icon: Icons.event_repeat_rounded,
                onTap: _pickFollowUpDate,
              ),
              if (_followUpDate != null) ...<Widget>[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _clearFollowUpDate,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Clear follow-up date'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _adminNotesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Admin notes optional',
                  hintText: 'Internal RHU notes.',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.admin_panel_settings_rounded),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
          ),
          onPressed: _submit,
          icon: const Icon(Icons.done_all_rounded),
          label: const Text('Complete'),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.visibleCount,
    required this.pendingCount,
    required this.acceptedCount,
    required this.completedCount,
    required this.selectedStatus,
  });

  final int visibleCount;
  final int pendingCount;
  final int acceptedCount;
  final int completedCount;
  final String selectedStatus;

  @override
  Widget build(BuildContext context) {
    final String filterLabel =
        selectedStatus == 'all' ? 'All records' : '${_prettyEnum(selectedStatus)} records';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0F766E),
            Color(0xFF115E59),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'RHU Appointment Center',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      filterLabel,
                      style: const TextStyle(
                        color: Color(0xFFE0F2F1),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Review patient requests, view uploaded patient photos, schedule visits, open consultation chat, send prescription QR, and complete consultations.',
            style: TextStyle(
              color: Color(0xFFE0F2F1),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderMetric(
                  label: 'Visible',
                  value: visibleCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Pending',
                  value: pendingCount.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderMetric(
                  label: 'Accepted',
                  value: acceptedCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Completed',
                  value: completedCount.toString(),
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
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE0F2F1),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StatusFilterHeaderDelegate({
    required this.selectedStatus,
    required this.onChanged,
  });

  final String selectedStatus;
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
      color: const Color(0xFFF6FAF9),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _FilterChipButton(
            label: 'Pending',
            value: 'pending',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Accepted',
            value: 'accepted',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Completed',
            value: 'completed',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Rejected',
            value: 'rejected',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'All',
            value: 'all',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StatusFilterHeaderDelegate oldDelegate) {
    return oldDelegate.selectedStatus != selectedStatus;
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
        selectedColor: const Color(0xFF0F766E),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF0F766E),
          fontWeight: FontWeight.w900,
        ),
        side: BorderSide(
          color: selected ? const Color(0xFF0F766E) : const Color(0xFF99F6E4),
        ),
        onSelected: (_) {
          onChanged(value);
        },
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.isUpdating,
    required this.onTap,
    required this.onAccept,
    required this.onReject,
  });

  final Map<String, dynamic> appointment;
  final bool isUpdating;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  bool get _isPending {
    return _readString(appointment, <String>['status']) == 'pending';
  }

  bool get _isAccepted {
    return _readString(appointment, <String>['status']) == 'accepted';
  }

  bool get _isCompleted {
    return _readString(appointment, <String>['status']) == 'completed';
  }

  @override
  Widget build(BuildContext context) {
    final String status = _readString(appointment, <String>['status']);
    final String appointmentType = _readString(
      appointment,
      <String>['appointmentType'],
    );

    final Color accentColor = _statusColor(status);

    final bool shouldDisplayPhotoOnCard = _isPending || _isAccepted;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.18),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  _PatientPhotoAvatar(
                    appointment: appointment,
                    showPhoto: shouldDisplayPhotoOnCard,
                    fallbackIcon: appointmentType == 'walk_in'
                        ? Icons.meeting_room_rounded
                        : Icons.video_call_rounded,
                    size: 58,
                    borderRadius: 20,
                    accentColor: accentColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _patientName(appointment),
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
                          '${_prettyService(_readString(appointment, <String>['serviceType']))} • ${_prettyAppointmentType(appointmentType)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (shouldDisplayPhotoOnCard &&
                            _patientPhotoUrl(appointment).trim().isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Photo uploaded',
                              style: TextStyle(
                                color: Color(0xFF0F766E),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 14),
              _InfoLine(
                label: 'Concern',
                value: _fallback(
                  _readString(appointment, <String>['healthConcern']),
                ),
              ),
              _InfoLine(
                label: 'Contact',
                value: _fallback(
                  _readString(appointment, <String>['contactNumber']),
                ),
              ),
              _InfoLine(
                label: _isAccepted || _isCompleted ? 'Scheduled' : 'Preferred',
                value: _isAccepted || _isCompleted
                    ? _formatDateTimeText(
                        _readString(appointment, <String>['scheduledAt']),
                      )
                    : '${_formatDateTimeText(_readString(appointment, <String>['preferredDate']))} • ${_fallback(_readString(appointment, <String>['preferredTime']))}',
              ),
              if (_isCompleted)
                _InfoLine(
                  label: 'Diagnosis',
                  value: _fallback(
                    _readString(
                      appointment,
                      <String>['consultationDiagnosis'],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('Details'),
                    ),
                  ),
                  if (_isPending) ...<Widget>[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isUpdating ? null : onAccept,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Accept'),
                      ),
                    ),
                  ],
                ],
              ),
              if (_isPending) ...<Widget>[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: isUpdating ? null : onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject Appointment'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentDetailsSheet extends StatelessWidget {
  const _AppointmentDetailsSheet({
    required this.appointment,
    required this.isUpdating,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
    required this.onOpenChat,
  });

  final Map<String, dynamic> appointment;
  final bool isUpdating;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onComplete;
  final VoidCallback onOpenChat;

  bool get _isPending {
    return _readString(appointment, <String>['status']) == 'pending';
  }

  bool get _isAccepted {
    return _readString(appointment, <String>['status']) == 'accepted';
  }

  bool get _isCompleted {
    return _readString(appointment, <String>['status']) == 'completed';
  }

  @override
  Widget build(BuildContext context) {
    final String qrPayload = _readString(
      appointment,
      <String>['qrPayload'],
    );

    final String appointmentType = _readString(
      appointment,
      <String>['appointmentType'],
    );

    final String status = _readString(
      appointment,
      <String>['status'],
    );

    final Color accentColor = _statusColor(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.96,
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
              _DetailsHero(
                appointment: appointment,
                accentColor: accentColor,
              ),
              const SizedBox(height: 18),
              _DetailsSection(
                title: 'Patient Information',
                icon: Icons.person_rounded,
                color: const Color(0xFF0EA5E9),
                children: <Widget>[
                  _InfoLine(
                    label: 'Age / Sex',
                    value:
                        '${_fallback(_readString(appointment, <String>['patientAge']))} • ${_prettySex(_readString(appointment, <String>['patientSex']))}',
                  ),
                  _InfoLine(
                    label: 'Religion',
                    value: _prettyEnum(
                      _readString(appointment, <String>['religion']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Civil Status',
                    value: _prettyEnum(
                      _readString(appointment, <String>['civilStatus']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Contact',
                    value: _fallback(
                      _readString(appointment, <String>['contactNumber']),
                    ),
                  ),
                  if (_patientPhotoUrl(appointment).trim().isNotEmpty)
                    _InfoLine(
                      label: 'Photo',
                      value: 'Uploaded - tap patient photo to view',
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsSection(
                title: 'Health Concern',
                icon: Icons.medical_information_rounded,
                color: const Color(0xFFEF4444),
                children: <Widget>[
                  _InfoLine(
                    label: 'Main Issue',
                    value: _fallback(
                      _readString(appointment, <String>['healthConcern']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Symptoms',
                    value: _fallback(
                      _readString(appointment, <String>['symptomsDescription']),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsSection(
                title: 'Schedule',
                icon: Icons.event_rounded,
                color: const Color(0xFFF59E0B),
                children: <Widget>[
                  _InfoLine(
                    label: 'Preferred',
                    value:
                        '${_formatDateTimeText(_readString(appointment, <String>['preferredDate']))} • ${_fallback(_readString(appointment, <String>['preferredTime']))}',
                  ),
                  _InfoLine(
                    label: 'Scheduled',
                    value: _formatDateTimeText(
                      _readString(appointment, <String>['scheduledAt']),
                    ),
                  ),
                  if (appointmentType == 'walk_in')
                    _InfoLine(
                      label: 'QR Expires',
                      value: _formatDateTimeText(
                        _readString(appointment, <String>['qrExpiresAt']),
                      ),
                    ),
                  _InfoLine(
                    label: 'Admin Notes',
                    value: _fallback(
                      _readString(appointment, <String>['adminNotes']),
                    ),
                  ),
                ],
              ),
              if (_isCompleted) ...<Widget>[
                const SizedBox(height: 16),
                _ConsultationResultBox(
                  appointment: appointment,
                ),
              ],
              if (qrPayload.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                _QrTicketBox(
                  qrPayload: qrPayload,
                  qrToken: _readString(appointment, <String>['qrToken']),
                ),
              ],
              const SizedBox(height: 20),
              if (_isPending)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isUpdating ? null : onReject,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isUpdating ? null : onAccept,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              if (_isAccepted) ...<Widget>[
                FilledButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: const Text('Open Consultation Chat'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: isUpdating ? null : onComplete,
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Complete Consultation'),
                ),
              ],
              if (_isCompleted)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Done'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailsHero extends StatelessWidget {
  const _DetailsHero({
    required this.appointment,
    required this.accentColor,
  });

  final Map<String, dynamic> appointment;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final String appointmentType = _readString(
      appointment,
      <String>['appointmentType'],
    );

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: <Widget>[
          _PatientPhotoAvatar(
            appointment: appointment,
            showPhoto: true,
            fallbackIcon: appointmentType == 'walk_in'
                ? Icons.meeting_room_rounded
                : Icons.video_call_rounded,
            size: 72,
            borderRadius: 24,
            accentColor: accentColor,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _patientName(appointment),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_prettyService(_readString(appointment, <String>['serviceType']))} • ${_prettyAppointmentType(appointmentType)}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(
            status: _readString(appointment, <String>['status']),
          ),
        ],
      ),
    );
  }
}

class _PatientPhotoAvatar extends StatelessWidget {
  const _PatientPhotoAvatar({
    required this.appointment,
    required this.showPhoto,
    required this.fallbackIcon,
    required this.size,
    required this.borderRadius,
    required this.accentColor,
  });

  final Map<String, dynamic> appointment;
  final bool showPhoto;
  final IconData fallbackIcon;
  final double size;
  final double borderRadius;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final String photoUrl = _patientPhotoUrl(appointment);

    if (!showPhoto || photoUrl.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(
          fallbackIcon,
          color: accentColor,
          size: size * 0.52,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _showPatientPhotoViewer(
          context: context,
          appointment: appointment,
        );
      },
      child: Stack(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              width: size,
              height: size,
              color: const Color(0xFFEFF6FF),
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                loadingBuilder: (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? loadingProgress,
                ) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) {
                  return Icon(
                    fallbackIcon,
                    color: const Color(0xFF64748B),
                    size: size * 0.52,
                  );
                },
              ),
            ),
          ),
          Positioned(
            right: 3,
            bottom: 3,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.zoom_in_rounded,
                color: accentColor,
                size: size * 0.18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showPatientPhotoViewer({
  required BuildContext context,
  required Map<String, dynamic> appointment,
}) {
  final String photoUrl = _patientPhotoUrl(appointment);

  if (photoUrl.trim().isEmpty) {
    return;
  }

  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                color: const Color(0xFF0F766E),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _patientName(appointment),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 4,
                  child: Image.network(
                    photoUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return const Padding(
                        padding: EdgeInsets.all(30),
                        child: Text('Unable to load patient photo.'),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ConsultationResultBox extends StatelessWidget {
  const _ConsultationResultBox({
    required this.appointment,
  });

  final Map<String, dynamic> appointment;

  @override
  Widget build(BuildContext context) {
    return _DetailsSection(
      title: 'Consultation Result',
      icon: Icons.assignment_turned_in_rounded,
      color: const Color(0xFF16A34A),
      children: <Widget>[
        _InfoLine(
          label: 'Diagnosis',
          value: _fallback(
            _readString(appointment, <String>['consultationDiagnosis']),
          ),
        ),
        _InfoLine(
          label: 'Notes',
          value: _fallback(
            _readString(appointment, <String>['consultationNotes']),
          ),
        ),
        _InfoLine(
          label: 'Follow-up',
          value: _fallback(
            _readString(appointment, <String>['followUpInstructions']),
          ),
        ),
        _InfoLine(
          label: 'Follow-up Date',
          value: _formatDateTimeText(
            _readString(appointment, <String>['followUpDate']),
          ),
        ),
        _InfoLine(
          label: 'Completed',
          value: _formatDateTimeText(
            _readString(appointment, <String>['completedAt']),
          ),
        ),
      ],
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _QrTicketBox extends StatelessWidget {
  const _QrTicketBox({
    required this.qrPayload,
    required this.qrToken,
  });

  final String qrPayload;
  final String qrToken;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'Walk-in QR Ticket',
            style: TextStyle(
              color: Color(0xFF1E3A8A),
              fontSize: 17,
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
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            qrToken,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogInfoBox extends StatelessWidget {
  const _DialogInfoBox({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color foreground = _statusColor(status);
    final Color background = foreground.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _prettyEnum(status),
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w900,
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
            width: 106,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
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
              child: Text('Loading appointment requests...'),
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
            _EmptyIcon(),
            SizedBox(height: 16),
            Text(
              'No appointments found',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Appointment requests will appear here based on the selected filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyIcon extends StatelessWidget {
  const _EmptyIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFCCFBF1),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Icon(
        Icons.event_busy_rounded,
        color: Color(0xFF0F766E),
        size: 38,
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
            const Text(
              'Unable to load appointments',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
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

Color _statusColor(String status) {
  switch (status) {
    case 'accepted':
      return const Color(0xFF2563EB);
    case 'completed':
      return const Color(0xFF16A34A);
    case 'rejected':
    case 'cancelled':
    case 'expired':
      return const Color(0xFFDC2626);
    case 'pending':
    default:
      return const Color(0xFFD97706);
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
    return 'Unknown patient';
  }

  return parts.join(' ');
}

String _patientPhotoUrl(Map<String, dynamic> appointment) {
  return _readString(
    appointment,
    <String>['patientPhotoUrl', 'photoUrl', 'imageUrl'],
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

String _prettySex(String value) {
  switch (value) {
    case 'male':
      return 'Male';
    case 'female':
      return 'Female';
    case 'prefer_not_to_say':
      return 'Prefer not to say';
    default:
      return _fallback(value);
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

String _fallback(String value) {
  if (value.trim().isEmpty || value.trim() == 'null') {
    return 'N/A';
  }

  return value.trim();
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