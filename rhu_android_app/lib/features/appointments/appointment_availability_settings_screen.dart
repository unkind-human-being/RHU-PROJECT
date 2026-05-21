import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class AppointmentAvailabilitySettingsScreen extends StatefulWidget {
  const AppointmentAvailabilitySettingsScreen({super.key});

  static const String routeName = '/appointment-settings';

  @override
  State<AppointmentAvailabilitySettingsScreen> createState() =>
      _AppointmentAvailabilitySettingsScreenState();
}

class _AppointmentAvailabilitySettingsScreenState
    extends State<AppointmentAvailabilitySettingsScreen> {
  late final ApiClient _apiClient;

  final TextEditingController _unavailableReasonController =
      TextEditingController();
  final TextEditingController _instructionsController =
      TextEditingController();
  final TextEditingController _maxWalkInController =
      TextEditingController(text: '50');
  final TextEditingController _maxOnlineController =
      TextEditingController(text: '20');

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  bool _isAcceptingAppointments = true;
  bool _allowWalkIn = true;
  bool _allowOnline = true;

  String _walkInStartTime = '08:00';
  String _walkInEndTime = '17:00';
  String _onlineStartTime = '08:00';
  String _onlineEndTime = '17:00';

  final Map<String, bool> _days = <String, bool>{
    'monday': true,
    'tuesday': true,
    'wednesday': true,
    'thursday': true,
    'friday': true,
    'saturday': false,
    'sunday': false,
  };

  Map<String, dynamic>? _setting;

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  @override
  void dispose() {
    _unavailableReasonController.dispose();
    _instructionsController.dispose();
    _maxWalkInController.dispose();
    _maxOnlineController.dispose();
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/appointment-settings/my',
        requiresAuth: true,
      );

      final Map<String, dynamic> setting = _extractMap(response);

      if (!mounted) {
        return;
      }

      _applySetting(setting);

      setState(() {
        _setting = setting;
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
        _errorMessage = 'Unable to load appointment availability settings.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _extractMap(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    return response;
  }

  void _applySetting(Map<String, dynamic> setting) {
    _isAcceptingAppointments = _readBool(
      setting,
      'isAcceptingAppointments',
      fallback: true,
    );
    _allowWalkIn = _readBool(setting, 'allowWalkIn', fallback: true);
    _allowOnline = _readBool(setting, 'allowOnline', fallback: true);

    _walkInStartTime = _readString(
      setting,
      <String>['walkInStartTime'],
      fallback: '08:00',
    );
    _walkInEndTime = _readString(
      setting,
      <String>['walkInEndTime'],
      fallback: '17:00',
    );
    _onlineStartTime = _readString(
      setting,
      <String>['onlineStartTime'],
      fallback: '08:00',
    );
    _onlineEndTime = _readString(
      setting,
      <String>['onlineEndTime'],
      fallback: '17:00',
    );

    for (final String day in _days.keys) {
      _days[day] = _readBool(setting, day, fallback: _days[day] ?? false);
    }

    _unavailableReasonController.text = _readString(
      setting,
      <String>['unavailableReason'],
    );
    _instructionsController.text = _readString(
      setting,
      <String>['instructionsForPatients'],
      fallback:
          'Please wait for RHU approval. If accepted, your schedule and QR ticket will appear in your account.',
    );
    _maxWalkInController.text = _readString(
      setting,
      <String>['maxWalkInPerDay'],
      fallback: '50',
    );
    _maxOnlineController.text = _readString(
      setting,
      <String>['maxOnlinePerDay'],
      fallback: '20',
    );
  }

  Future<void> _saveSettings() async {
    FocusScope.of(context).unfocus();

    final int maxWalkIn = int.tryParse(_maxWalkInController.text.trim()) ?? 0;
    final int maxOnline = int.tryParse(_maxOnlineController.text.trim()) ?? 0;

    if (maxWalkIn < 0 || maxOnline < 0) {
      _showError('Maximum appointments cannot be negative.');
      return;
    }

    if (!_allowWalkIn && !_allowOnline && _isAcceptingAppointments) {
      _showError(
        'Turn on at least Walk-in or Online, or turn off accepting appointments.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> body = <String, dynamic>{
        'isAcceptingAppointments': _isAcceptingAppointments,
        'allowWalkIn': _allowWalkIn,
        'allowOnline': _allowOnline,
        'unavailableReason': _unavailableReasonController.text.trim(),
        'walkInStartTime': _walkInStartTime,
        'walkInEndTime': _walkInEndTime,
        'onlineStartTime': _onlineStartTime,
        'onlineEndTime': _onlineEndTime,
        'monday': _days['monday'] ?? false,
        'tuesday': _days['tuesday'] ?? false,
        'wednesday': _days['wednesday'] ?? false,
        'thursday': _days['thursday'] ?? false,
        'friday': _days['friday'] ?? false,
        'saturday': _days['saturday'] ?? false,
        'sunday': _days['sunday'] ?? false,
        'maxWalkInPerDay': maxWalkIn,
        'maxOnlinePerDay': maxOnline,
        'instructionsForPatients': _instructionsController.text.trim(),
      };

      final Map<String, dynamic> response = await _apiClient.patch(
        '/api/appointment-settings/my',
        requiresAuth: true,
        body: body,
      );

      final Map<String, dynamic> setting = _extractMap(response);

      if (!mounted) {
        return;
      }

      _applySetting(setting);

      setState(() {
        _setting = setting;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment availability updated.'),
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

      _showError('Unable to save appointment availability settings.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickTime({
    required String currentTime,
    required ValueChanged<String> onChanged,
  }) async {
    final TimeOfDay initialTime = _parseTimeOfDay(currentTime);

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime == null) {
      return;
    }

    final String formattedTime =
        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

    onChanged(formattedTime);
  }

  TimeOfDay _parseTimeOfDay(String time) {
    final List<String> parts = time.split(':');

    if (parts.length != 2) {
      return const TimeOfDay(hour: 8, minute: 0);
    }

    final int hour = int.tryParse(parts[0]) ?? 8;
    final int minute = int.tryParse(parts[1]) ?? 0;

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return const TimeOfDay(hour: 8, minute: 0);
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  void _setAllWeekdays(bool value) {
    setState(() {
      _days['monday'] = value;
      _days['tuesday'] = value;
      _days['wednesday'] = value;
      _days['thursday'] = value;
      _days['friday'] = value;
    });
  }

  void _setAllDays(bool value) {
    setState(() {
      for (final String day in _days.keys) {
        _days[day] = value;
      }
    });
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
    final String rhuName = _readRhuName(_setting);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Appointment Availability',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading || _isSaving ? null : _loadSettings,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Color(0xFFE5E7EB),
              ),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
              ),
              onPressed: _isLoading || _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save Availability'),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSettings,
          child: _buildBody(rhuName),
        ),
      ),
    );
  }

  Widget _buildBody(String rhuName) {
    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          _ErrorCard(
            message: _errorMessage!,
            onRetry: _loadSettings,
          ),
        ],
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: <Widget>[
        _HeaderCard(
          rhuName: rhuName,
          isAcceptingAppointments: _isAcceptingAppointments,
          allowWalkIn: _allowWalkIn,
          allowOnline: _allowOnline,
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Main Availability',
          icon: Icons.toggle_on_rounded,
          children: <Widget>[
            _SwitchTile(
              title: 'Accepting appointments',
              subtitle:
                  'Turn this off when the RHU is not available for public appointment requests.',
              value: _isAcceptingAppointments,
              onChanged: _isSaving
                  ? null
                  : (bool value) {
                      setState(() {
                        _isAcceptingAppointments = value;
                      });
                    },
            ),
            const SizedBox(height: 10),
            _SwitchTile(
              title: 'Allow walk-in requests',
              subtitle: 'Public users can choose walk-in appointments.',
              value: _allowWalkIn,
              onChanged: _isSaving
                  ? null
                  : (bool value) {
                      setState(() {
                        _allowWalkIn = value;
                      });
                    },
            ),
            const SizedBox(height: 10),
            _SwitchTile(
              title: 'Allow online consultation',
              subtitle: 'Public users can choose online consultation.',
              value: _allowOnline,
              onChanged: _isSaving
                  ? null
                  : (bool value) {
                      setState(() {
                        _allowOnline = value;
                      });
                    },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Available Days',
          icon: Icons.calendar_month_rounded,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ActionChip(
                  avatar: const Icon(Icons.work_rounded),
                  label: const Text('Weekdays ON'),
                  onPressed: _isSaving
                      ? null
                      : () {
                          _setAllWeekdays(true);
                        },
                ),
                ActionChip(
                  avatar: const Icon(Icons.clear_rounded),
                  label: const Text('Weekdays OFF'),
                  onPressed: _isSaving
                      ? null
                      : () {
                          _setAllWeekdays(false);
                        },
                ),
                ActionChip(
                  avatar: const Icon(Icons.done_all_rounded),
                  label: const Text('All Days ON'),
                  onPressed: _isSaving
                      ? null
                      : () {
                          _setAllDays(true);
                        },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DaySwitch(
              title: 'Monday',
              value: _days['monday'] ?? false,
              onChanged: _setDayValue('monday'),
            ),
            _DaySwitch(
              title: 'Tuesday',
              value: _days['tuesday'] ?? false,
              onChanged: _setDayValue('tuesday'),
            ),
            _DaySwitch(
              title: 'Wednesday',
              value: _days['wednesday'] ?? false,
              onChanged: _setDayValue('wednesday'),
            ),
            _DaySwitch(
              title: 'Thursday',
              value: _days['thursday'] ?? false,
              onChanged: _setDayValue('thursday'),
            ),
            _DaySwitch(
              title: 'Friday',
              value: _days['friday'] ?? false,
              onChanged: _setDayValue('friday'),
            ),
            _DaySwitch(
              title: 'Saturday',
              value: _days['saturday'] ?? false,
              onChanged: _setDayValue('saturday'),
            ),
            _DaySwitch(
              title: 'Sunday',
              value: _days['sunday'] ?? false,
              onChanged: _setDayValue('sunday'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Walk-in Schedule',
          icon: Icons.meeting_room_rounded,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _TimePickerBox(
                    label: 'Start',
                    value: _formatTimeLabel(_walkInStartTime),
                    onTap: _isSaving
                        ? null
                        : () {
                            _pickTime(
                              currentTime: _walkInStartTime,
                              onChanged: (String value) {
                                setState(() {
                                  _walkInStartTime = value;
                                });
                              },
                            );
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimePickerBox(
                    label: 'End',
                    value: _formatTimeLabel(_walkInEndTime),
                    onTap: _isSaving
                        ? null
                        : () {
                            _pickTime(
                              currentTime: _walkInEndTime,
                              onChanged: (String value) {
                                setState(() {
                                  _walkInEndTime = value;
                                });
                              },
                            );
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxWalkInController,
              keyboardType: TextInputType.number,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                labelText: 'Max walk-in per day',
                prefixIcon: Icon(Icons.groups_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Online Consultation Schedule',
          icon: Icons.video_call_rounded,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _TimePickerBox(
                    label: 'Start',
                    value: _formatTimeLabel(_onlineStartTime),
                    onTap: _isSaving
                        ? null
                        : () {
                            _pickTime(
                              currentTime: _onlineStartTime,
                              onChanged: (String value) {
                                setState(() {
                                  _onlineStartTime = value;
                                });
                              },
                            );
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimePickerBox(
                    label: 'End',
                    value: _formatTimeLabel(_onlineEndTime),
                    onTap: _isSaving
                        ? null
                        : () {
                            _pickTime(
                              currentTime: _onlineEndTime,
                              onChanged: (String value) {
                                setState(() {
                                  _onlineEndTime = value;
                                });
                              },
                            );
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxOnlineController,
              keyboardType: TextInputType.number,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                labelText: 'Max online per day',
                prefixIcon: Icon(Icons.video_chat_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Public Instructions',
          icon: Icons.info_outline_rounded,
          children: <Widget>[
            TextField(
              controller: _instructionsController,
              maxLines: 4,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                labelText: 'Instructions for public users',
                hintText: 'Example: Please bring valid ID for walk-in.',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _unavailableReasonController,
              maxLines: 3,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                labelText: 'Unavailable reason optional',
                hintText:
                    'Example: RHU appointment requests are closed today due to medical mission.',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.warning_amber_rounded),
              ),
            ),
          ],
        ),
      ],
    );
  }

  ValueChanged<bool>? _setDayValue(String day) {
    if (_isSaving) {
      return null;
    }

    return (bool value) {
      setState(() {
        _days[day] = value;
      });
    };
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.rhuName,
    required this.isAcceptingAppointments,
    required this.allowWalkIn,
    required this.allowOnline,
  });

  final String rhuName;
  final bool isAcceptingAppointments;
  final bool allowWalkIn;
  final bool allowOnline;

  @override
  Widget build(BuildContext context) {
    final String statusText = isAcceptingAppointments ? 'OPEN' : 'CLOSED';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isAcceptingAppointments
              ? const <Color>[
                  Color(0xFF0F766E),
                  Color(0xFF115E59),
                ]
              : const <Color>[
                  Color(0xFFDC2626),
                  Color(0xFF991B1B),
                ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (isAcceptingAppointments
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFDC2626))
                .withValues(alpha: 0.18),
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
              const Icon(
                Icons.event_available_rounded,
                color: Colors.white,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rhuName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Control what public users can request from this RHU.',
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
                child: _HeaderBadge(
                  label: 'Walk-in',
                  value: allowWalkIn ? 'ON' : 'OFF',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderBadge(
                  label: 'Online',
                  value: allowOnline ? 'ON' : 'OFF',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
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
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  icon,
                  color: const Color(0xFF0F766E),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: value ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: value ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB),
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(subtitle),
        activeColor: const Color(0xFF16A34A),
      ),
    );
  }
}

class _DaySwitch extends StatelessWidget {
  const _DaySwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
      activeColor: const Color(0xFF16A34A),
    );
  }
}

class _TimePickerBox extends StatelessWidget {
  const _TimePickerBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule_rounded),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
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
              'Unable to load settings',
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

String _readRhuName(Map<String, dynamic>? setting) {
  if (setting == null) {
    return 'RHU Appointment Settings';
  }

  final dynamic rhu = setting['rhu'];

  if (rhu is Map<String, dynamic>) {
    final String name = _readString(
      rhu,
      <String>['name', 'municipality'],
    );

    if (name.trim().isNotEmpty) {
      return name;
    }
  }

  return 'RHU Appointment Settings';
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

String _formatTimeLabel(String value) {
  final List<String> parts = value.split(':');

  if (parts.length != 2) {
    return value;
  }

  final int hour = int.tryParse(parts[0]) ?? 0;
  final int minute = int.tryParse(parts[1]) ?? 0;

  final int hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final String period = hour >= 12 ? 'PM' : 'AM';

  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}
