import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class PatientViewScreen extends StatefulWidget {
  const PatientViewScreen({super.key});

  static const String routeName = '/patient-view';

  @override
  State<PatientViewScreen> createState() => _PatientViewScreenState();
}

class _PatientViewScreenState extends State<PatientViewScreen> {
  late final ApiClient _apiClient;

  bool _isLoading = false;
  String? _errorMessage;

  String _selectedType = 'all';
  String _selectedStatus = 'accepted';
  String _searchText = '';

  List<Map<String, dynamic>> _appointments = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPatients();
    });
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    return _appointments.where((Map<String, dynamic> appointment) {
      final String appointmentType = _readString(
        appointment,
        <String>['appointmentType'],
      );

      final String status = _readString(
        appointment,
        <String>['status'],
      );

      final String patientName = _patientName(appointment).toLowerCase();
      final String serviceType = _prettyService(
        _readString(appointment, <String>['serviceType']),
      ).toLowerCase();
      final String concern = _readString(
        appointment,
        <String>['healthConcern'],
      ).toLowerCase();
      final String diagnosis = _readString(
        appointment,
        <String>['consultationDiagnosis'],
      ).toLowerCase();
      final String notes = _readString(
        appointment,
        <String>['consultationNotes'],
      ).toLowerCase();
      final String contact = _readString(
        appointment,
        <String>['contactNumber'],
      ).toLowerCase();

      final String query = _searchText.trim().toLowerCase();

      final bool matchesType =
          _selectedType == 'all' || appointmentType == _selectedType;

      final bool matchesStatus =
          _selectedStatus == 'all' || status == _selectedStatus;

      final bool matchesSearch = query.isEmpty ||
          patientName.contains(query) ||
          serviceType.contains(query) ||
          concern.contains(query) ||
          diagnosis.contains(query) ||
          notes.contains(query) ||
          contact.contains(query);

      return matchesType && matchesStatus && matchesSearch;
    }).toList();
  }

  int _countByType(String type) {
    return _appointments.where((Map<String, dynamic> appointment) {
      return _readString(appointment, <String>['appointmentType']) == type;
    }).length;
  }

  int _countByStatus(String status) {
    return _appointments.where((Map<String, dynamic> appointment) {
      return _readString(appointment, <String>['status']) == status;
    }).length;
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/appointments',
        requiresAuth: true,
        queryParameters: <String, dynamic>{
          'limit': 200,
        },
      );

      final List<dynamic> rawAppointments = _extractList(response);

      final List<Map<String, dynamic>> appointments = rawAppointments
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();

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
        _errorMessage = 'Unable to load patient records.';
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

  void _showPatientDetails(Map<String, dynamic> appointment) {
    final BuildContext rootContext = context;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _PatientDetailsSheet(
          appointment: appointment,
          onOpenChat: () {
            Navigator.of(sheetContext).pop();

            Future<void>.delayed(const Duration(milliseconds: 180), () {
              if (!mounted) {
                return;
              }

              Navigator.of(rootContext).pushNamed(
                '/appointment-chat',
                arguments: Map<String, dynamic>.from(appointment),
              );
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> filteredAppointments =
        _filteredAppointments;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Patient View',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadPatients,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPatients,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _HeaderCard(
                    total: _appointments.length,
                    walkIn: _countByType('walk_in'),
                    online: _countByType('online'),
                    accepted: _countByStatus('accepted'),
                    completed: _countByStatus('completed'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: _SearchBox(
                    onChanged: (String value) {
                      setState(() {
                        _searchText = value;
                      });
                    },
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _FilterHeaderDelegate(
                  selectedType: _selectedType,
                  selectedStatus: _selectedStatus,
                  onTypeChanged: (String value) {
                    setState(() {
                      _selectedType = value;
                    });
                  },
                  onStatusChanged: (String value) {
                    setState(() {
                      _selectedStatus = value;
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
                      onRetry: _loadPatients,
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
                      child: _PatientCard(
                        appointment: appointment,
                        onTap: () {
                          _showPatientDetails(appointment);
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
    required this.walkIn,
    required this.online,
    required this.accepted,
    required this.completed,
  });

  final int total;
  final int walkIn;
  final int online;
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
            Color(0xFF7C3AED),
            Color(0xFF5B21B6),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
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
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'RHU Patient View',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Consultation records',
                      style: TextStyle(
                        color: Color(0xFFEDE9FE),
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
            'View walk-in and online patients, active consultations, and completed consultation results.',
            style: TextStyle(
              color: Color(0xFFEDE9FE),
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
                  label: 'Accepted',
                  value: accepted.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderMetric(
                  label: 'Completed',
                  value: completed.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Online',
                  value: online.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Walk-in',
                  value: walkIn.toString(),
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
      width: double.infinity,
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
              color: Color(0xFFEDE9FE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.onChanged,
  });

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search patient, contact, service, concern, diagnosis...',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterHeaderDelegate({
    required this.selectedType,
    required this.selectedStatus,
    required this.onTypeChanged,
    required this.onStatusChanged,
  });

  final String selectedType;
  final String selectedStatus;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  double get minExtent => 120;

  @override
  double get maxExtent => 120;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                _FilterChipButton(
                  label: 'All Types',
                  value: 'all',
                  selectedValue: selectedType,
                  onChanged: onTypeChanged,
                ),
                _FilterChipButton(
                  label: 'Walk-in',
                  value: 'walk_in',
                  selectedValue: selectedType,
                  onChanged: onTypeChanged,
                ),
                _FilterChipButton(
                  label: 'Online',
                  value: 'online',
                  selectedValue: selectedType,
                  onChanged: onTypeChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                _FilterChipButton(
                  label: 'Accepted',
                  value: 'accepted',
                  selectedValue: selectedStatus,
                  onChanged: onStatusChanged,
                ),
                _FilterChipButton(
                  label: 'Completed',
                  value: 'completed',
                  selectedValue: selectedStatus,
                  onChanged: onStatusChanged,
                ),
                _FilterChipButton(
                  label: 'Pending',
                  value: 'pending',
                  selectedValue: selectedStatus,
                  onChanged: onStatusChanged,
                ),
                _FilterChipButton(
                  label: 'Rejected',
                  value: 'rejected',
                  selectedValue: selectedStatus,
                  onChanged: onStatusChanged,
                ),
                _FilterChipButton(
                  label: 'All Status',
                  value: 'all',
                  selectedValue: selectedStatus,
                  onChanged: onStatusChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return oldDelegate.selectedType != selectedType ||
        oldDelegate.selectedStatus != selectedStatus;
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
        selectedColor: const Color(0xFF7C3AED),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF5B21B6),
          fontWeight: FontWeight.w900,
        ),
        side: BorderSide(
          color: selected ? const Color(0xFF7C3AED) : const Color(0xFFDDD6FE),
        ),
        onSelected: (_) {
          onChanged(value);
        },
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({
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
              color: accentColor.withValues(alpha: 0.16),
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
                      appointmentType == 'online'
                          ? Icons.video_call_rounded
                          : Icons.meeting_room_rounded,
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
                label: _isAccepted || _isCompleted ? 'Schedule' : 'Preferred',
                value: _isAccepted || _isCompleted
                    ? _formatDateTimeText(
                        _readString(appointment, <String>['scheduledAt']),
                      )
                    : '${_formatDateTimeText(_readString(appointment, <String>['preferredDate']))} • ${_fallback(_readString(appointment, <String>['preferredTime']))}',
              ),
              _InfoLine(
                label: 'Contact',
                value: _fallback(
                  _readString(appointment, <String>['contactNumber']),
                ),
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.visibility_rounded),
                  label: Text(
                    _isCompleted
                        ? 'View Consultation Result'
                        : 'View Patient Record',
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

class _PatientDetailsSheet extends StatelessWidget {
  const _PatientDetailsSheet({
    required this.appointment,
    required this.onOpenChat,
  });

  final Map<String, dynamic> appointment;
  final VoidCallback onOpenChat;

  bool get _isCompleted {
    return _readString(appointment, <String>['status']) == 'completed';
  }

  bool get _isAccepted {
    return _readString(appointment, <String>['status']) == 'accepted';
  }

  bool get _isOnline {
    return _readString(appointment, <String>['appointmentType']) == 'online';
  }

  @override
  Widget build(BuildContext context) {
    final String status = _readString(appointment, <String>['status']);
    final String appointmentType = _readString(
      appointment,
      <String>['appointmentType'],
    );

    final bool canOpenChat = _isAccepted && _isOnline;
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
              _PatientHero(
                appointment: appointment,
                accentColor: accentColor,
              ),
              const SizedBox(height: 16),
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
                  _InfoLine(
                    label: 'End Time',
                    value: _formatDateTimeText(
                      _readString(appointment, <String>['scheduledEndAt']),
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
              const SizedBox(height: 18),
              if (canOpenChat)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                  ),
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: const Text('Open Consultation Chat'),
                ),
              if (canOpenChat) const SizedBox(height: 10),
              OutlinedButton.icon(
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

class _PatientHero extends StatelessWidget {
  const _PatientHero({
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
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Icon(
              appointmentType == 'online'
                  ? Icons.video_call_rounded
                  : Icons.meeting_room_rounded,
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
          label: 'Completed By',
          value: _personLabel(appointment['completedBy']),
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
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 14),
            Expanded(
              child: Text('Loading patient records...'),
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
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            _EmptyIcon(),
            SizedBox(height: 16),
            Text(
              'No patients found',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Patient appointment records will appear here based on your selected filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                height: 1.4,
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
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Icon(
        Icons.groups_outlined,
        color: Color(0xFF7C3AED),
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
              'Unable to load patients',
              style: TextStyle(
                color: Color(0xFF111827),
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

String _personLabel(dynamic value) {
  if (value is Map<String, dynamic>) {
    return _fallback(
      _readString(
        value,
        <String>['fullName', 'name', 'email', '_id', 'id'],
      ),
    );
  }

  if (value == null) {
    return 'N/A';
  }

  return _fallback(value.toString());
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