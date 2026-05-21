import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  static const String routeName = '/my-appointments';

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  late final ApiClient _apiClient;

  bool _isLoading = false;
  String? _errorMessage;

  String _selectedStatus = 'all';

  List<Map<String, dynamic>> _appointments = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyAppointments();
    });
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    final List<Map<String, dynamic>> appointments =
        List<Map<String, dynamic>>.from(_appointments);

    appointments.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final DateTime bDate = _readDateTime(
        b,
        <String>['scheduledAt', 'completedAt', 'createdAt'],
      );
      final DateTime aDate = _readDateTime(
        a,
        <String>['scheduledAt', 'completedAt', 'createdAt'],
      );

      return bDate.compareTo(aDate);
    });

    if (_selectedStatus == 'all') {
      return appointments;
    }

    return appointments.where((Map<String, dynamic> appointment) {
      return _readString(appointment, <String>['status']) == _selectedStatus;
    }).toList();
  }

  Future<void> _loadMyAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/appointments/my',
        requiresAuth: true,
        queryParameters: <String, dynamic>{
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
        _errorMessage = 'Unable to load your appointments.';
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

  void _setStatusFilter(String status) {
    setState(() {
      _selectedStatus = status;
    });
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _AppointmentDetailsSheet(
          appointment: appointment,
        );
      },
    );
  }

  int _countByStatus(String status) {
    return _appointments.where((Map<String, dynamic> item) {
      return _readString(item, <String>['status']) == status;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> filteredAppointments =
        _filteredAppointments;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        title: const Text(
          'My Appointments',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadMyAppointments,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMyAppointments,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _HeaderCard(
                    total: _appointments.length,
                    pending: _countByStatus('pending'),
                    accepted: _countByStatus('accepted'),
                    completed: _countByStatus('completed'),
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
                      onRetry: _loadMyAppointments,
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
              else if (filteredAppointments.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _EmptyState(),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: filteredAppointments.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> appointment =
                        filteredAppointments[index];

                    return Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: index == 0 ? 12 : 0,
                        bottom: 12,
                      ),
                      child: _AppointmentCard(
                        appointment: appointment,
                        onTap: () {
                          _showAppointmentDetails(appointment);
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.total,
    required this.pending,
    required this.accepted,
    required this.completed,
  });

  final int total;
  final int pending;
  final int accepted;
  final int completed;

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
          Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'My RHU Appointments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Schedules, QR tickets, and results',
                      style: TextStyle(
                        color: Color(0xFFE0F2FE),
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
            'Check your appointment status, walk-in QR ticket, online consultation updates, and completed consultation results from your RHU.',
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
                  value: total.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Pending',
                  value: pending.toString(),
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
                  value: accepted.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Completed',
                  value: completed.toString(),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
      color: const Color(0xFFEFF6FF),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _FilterChipButton(
            label: 'All',
            value: 'all',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
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

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.onTap,
  });

  final Map<String, dynamic> appointment;
  final VoidCallback onTap;

  bool get _isCompleted {
    return _readString(appointment, <String>['status']) == 'completed';
  }

  bool get _isAccepted {
    return _readString(appointment, <String>['status']) == 'accepted';
  }

  @override
  Widget build(BuildContext context) {
    final String status = _readString(appointment, <String>['status']);
    final String appointmentType = _readString(
      appointment,
      <String>['appointmentType'],
    );

    final bool hasQr = _readString(
      appointment,
      <String>['qrPayload'],
    ).trim().isNotEmpty;

    final Color accentColor = _statusColor(status);

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
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Icon(
                      appointmentType == 'walk_in'
                          ? Icons.meeting_room_rounded
                          : Icons.video_call_rounded,
                      color: accentColor,
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
                              appointment,
                              <String>['serviceType'],
                            ),
                          ),
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
                          '${_prettyAppointmentType(appointmentType)} • ${_patientName(appointment)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
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
                  _readString(
                    appointment,
                    <String>['healthConcern'],
                  ),
                ),
              ),
              _InfoLine(
                label: _isAccepted || _isCompleted ? 'Schedule' : 'Preferred',
                value: _isAccepted || _isCompleted
                    ? _formatScheduleText(
                        _readString(
                          appointment,
                          <String>['scheduledAt'],
                        ),
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
              if (hasQr)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: _QrNoticeLine(),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.visibility_rounded),
                  label: Text(
                    _isCompleted
                        ? 'View Consultation Result'
                        : hasQr
                            ? 'View QR Ticket'
                            : 'View Details',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrNoticeLine extends StatelessWidget {
  const _QrNoticeLine();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        Icon(
          Icons.qr_code_2_rounded,
          color: Color(0xFF0EA5E9),
          size: 20,
        ),
        SizedBox(width: 7),
        Expanded(
          child: Text(
            'Walk-in QR ticket is ready. Tap to view.',
            style: TextStyle(
              color: Color(0xFF075985),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppointmentDetailsSheet extends StatelessWidget {
  const _AppointmentDetailsSheet({
    required this.appointment,
  });

  final Map<String, dynamic> appointment;

  bool get _isCompleted {
    return _readString(appointment, <String>['status']) == 'completed';
  }

  @override
  Widget build(BuildContext context) {
    final String status = _readString(
      appointment,
      <String>['status'],
    );

    final String appointmentType = _readString(
      appointment,
      <String>['appointmentType'],
    );

    final String qrPayload = _readString(
      appointment,
      <String>['qrPayload'],
    );

    final Color accentColor = _statusColor(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.96,
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
              const SizedBox(height: 20),
              _AppointmentHero(
                appointment: appointment,
                accentColor: accentColor,
              ),
              const SizedBox(height: 18),
              _StatusInstructionBox(
                status: status,
                appointmentType: appointmentType,
                hasQr: qrPayload.trim().isNotEmpty,
              ),
              const SizedBox(height: 18),
              _DetailsSection(
                title: 'Patient Information',
                icon: Icons.person_rounded,
                color: const Color(0xFF0EA5E9),
                children: <Widget>[
                  _InfoLine(
                    label: 'Patient',
                    value: _patientName(appointment),
                  ),
                  _InfoLine(
                    label: 'Age / Sex',
                    value:
                        '${_fallback(_readString(appointment, <String>['patientAge']))} • ${_prettySex(_readString(appointment, <String>['patientSex']))}',
                  ),
                  _InfoLine(
                    label: 'Contact',
                    value: _fallback(
                      _readString(appointment, <String>['contactNumber']),
                    ),
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
                      _readString(
                        appointment,
                        <String>['symptomsDescription'],
                      ),
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
                    label: 'Scheduled',
                    value: _formatScheduleText(
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
                    label: 'RHU Notes',
                    value: _fallback(
                      _readString(appointment, <String>['adminNotes']),
                    ),
                  ),
                  if (status == 'rejected')
                    _InfoLine(
                      label: 'Reason',
                      value: _fallback(
                        _readString(appointment, <String>['rejectionReason']),
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
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                ),
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

class _AppointmentHero extends StatelessWidget {
  const _AppointmentHero({
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
          color: accentColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Icon(
              appointmentType == 'walk_in'
                  ? Icons.meeting_room_rounded
                  : Icons.video_call_rounded,
              color: accentColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _prettyService(
                    _readString(
                      appointment,
                      <String>['serviceType'],
                    ),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_prettyAppointmentType(appointmentType)} • ${_patientName(appointment)}',
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

class _StatusInstructionBox extends StatelessWidget {
  const _StatusInstructionBox({
    required this.status,
    required this.appointmentType,
    required this.hasQr,
  });

  final String status;
  final String appointmentType;
  final bool hasQr;

  @override
  Widget build(BuildContext context) {
    final String message;
    final IconData icon;
    final Color color;

    if (status == 'pending') {
      message = 'Your appointment request is waiting for RHU admin approval.';
      icon = Icons.hourglass_top_rounded;
      color = const Color(0xFFF59E0B);
    } else if (status == 'accepted' &&
        appointmentType == 'walk_in' &&
        hasQr) {
      message =
          'Your walk-in appointment was accepted. Show this QR ticket at the RHU office.';
      icon = Icons.qr_code_2_rounded;
      color = const Color(0xFF0EA5E9);
    } else if (status == 'accepted' && appointmentType == 'online') {
      message =
          'Your online consultation was accepted. RHU admin may send messages, video call invite, or prescription QR through your Messages screen.';
      icon = Icons.video_call_rounded;
      color = const Color(0xFF0EA5E9);
    } else if (status == 'rejected') {
      message = 'Your appointment request was rejected. Check the reason below.';
      icon = Icons.cancel_rounded;
      color = const Color(0xFFDC2626);
    } else if (status == 'completed') {
      message =
          'Your consultation is completed. Review the diagnosis, notes, and follow-up instructions below.';
      icon = Icons.done_all_rounded;
      color = const Color(0xFF16A34A);
    } else {
      message = 'Appointment status: ${_prettyEnum(status)}.';
      icon = Icons.info_outline_rounded;
      color = const Color(0xFF64748B);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
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
            _readString(
              appointment,
              <String>['consultationDiagnosis'],
            ),
          ),
        ),
        _InfoLine(
          label: 'Notes',
          value: _fallback(
            _readString(
              appointment,
              <String>['consultationNotes'],
            ),
          ),
        ),
        _InfoLine(
          label: 'Follow-up',
          value: _fallback(
            _readString(
              appointment,
              <String>['followUpInstructions'],
            ),
          ),
        ),
        _InfoLine(
          label: 'Follow-up Date',
          value: _formatDateTimeText(
            _readString(
              appointment,
              <String>['followUpDate'],
            ),
          ),
        ),
        _InfoLine(
          label: 'Completed At',
          value: _formatDateTimeText(
            _readString(
              appointment,
              <String>['completedAt'],
            ),
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
          color: const Color(0xFFBAE6FD),
        ),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'Walk-in QR Ticket',
            style: TextStyle(
              color: Color(0xFF075985),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Show this QR code when you arrive at the RHU office.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
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
            width: 112,
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
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 14),
            Expanded(
              child: Text('Loading your appointments...'),
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
                Icons.event_busy_rounded,
                color: Color(0xFF0EA5E9),
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No appointments found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Your appointment requests, QR tickets, and completed consultation results will appear here.',
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
              'Unable to load appointments',
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

String _formatScheduleText(String value) {
  if (value.trim().isEmpty || value.trim() == 'null') {
    return 'Waiting for RHU schedule';
  }

  return _formatDateTimeText(value);
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