import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_exception.dart';
import '../../data/repositories/event_repository.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  static const String routeName = '/create-event';

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _maxParticipantsController =
      TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _requirementsController =
      TextEditingController();

  final EventRepository _eventRepository = EventRepository();

  String _type = 'medical_mission';
  String _status = 'open';
  String _audienceScope = 'public';
  bool _registrationRequired = false;
  bool _isSaving = false;

  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1, hours: 2));

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _maxParticipantsController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _requirementsController.dispose();
    super.dispose();
  }

  List<String> _readRequirements() {
    return _requirementsController.text
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _pickStartDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDate),
    );

    if (pickedTime == null) {
      return;
    }

    final DateTime newStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _startDate = newStart;

      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate.add(const Duration(hours: 2));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endDate),
    );

    if (pickedTime == null) {
      return;
    }

    final DateTime newEnd = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _endDate = newEnd;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be after start date.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final AuthProvider authProvider = context.read<AuthProvider>();

      final String? rhuId = authProvider.user?.rhuId;
      final String? barangayId = authProvider.user?.barangayId;

      if (rhuId == null || rhuId.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'RHU is required. This account is not assigned to an RHU.',
            ),
            backgroundColor: Color(0xFFDC2626),
          ),
        );

        setState(() {
          _isSaving = false;
        });

        return;
      }

      await _eventRepository.createEvent(
        title: _titleController.text,
        description: _descriptionController.text,
        type: _type,
        status: _status,
        audienceScope: _audienceScope,
        rhuId: rhuId,
        barangayId: barangayId,
        locationName: _locationController.text,
        address: _addressController.text,
        startDate: _startDate,
        endDate: _endDate,
        registrationRequired: _registrationRequired,
        maxParticipants:
            int.tryParse(_maxParticipantsController.text.trim()) ?? 0,
        contactPerson: _contactPersonController.text,
        contactNumber: _contactNumberController.text,
        requirements: _readRequirements(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event created successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _addressController.clear();
      _maxParticipantsController.clear();
      _contactPersonController.clear();
      _contactNumberController.clear();
      _requirementsController.clear();

      setState(() {
        _type = 'medical_mission';
        _status = 'open';
        _audienceScope = 'public';
        _registrationRequired = false;
        _startDate = DateTime.now().add(const Duration(days: 1));
        _endDate = DateTime.now().add(const Duration(days: 1, hours: 2));
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to create event.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Event',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const _CreateEventHeader(),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Event title',
                          hintText: 'Example: Medical Mission in Bongao',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (String? value) {
                          final String text = value?.trim() ?? '';

                          if (text.isEmpty) {
                            return 'Event title is required.';
                          }

                          if (text.length < 4) {
                            return 'Event title is too short.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 4,
                        maxLines: 7,
                        decoration: const InputDecoration(
                          labelText: 'Event description',
                          hintText: 'Describe the health event or activity.',
                          prefixIcon: Icon(Icons.description_rounded),
                          alignLabelWithHint: true,
                        ),
                        validator: (String? value) {
                          final String text = value?.trim() ?? '';

                          if (text.isEmpty) {
                            return 'Event description is required.';
                          }

                          if (text.length < 10) {
                            return 'Description is too short.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _type,
                        decoration: const InputDecoration(
                          labelText: 'Event type',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'medical_mission',
                            child: Text('Medical Mission'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'vaccination',
                            child: Text('Vaccination'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'deworming',
                            child: Text('Deworming'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'seminar',
                            child: Text('Seminar'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'health_checkup',
                            child: Text('Health Checkup'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value == null) return;

                          setState(() {
                            _type = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          prefixIcon: Icon(Icons.publish_rounded),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'open',
                            child: Text('Open'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'draft',
                            child: Text('Draft'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'closed',
                            child: Text('Closed'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'cancelled',
                            child: Text('Cancelled'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value == null) return;

                          setState(() {
                            _status = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _audienceScope,
                        decoration: const InputDecoration(
                          labelText: 'Audience',
                          prefixIcon: Icon(Icons.people_rounded),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'public',
                            child: Text('Public'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'staff',
                            child: Text('Staff Only'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'rhu',
                            child: Text('RHU Level'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'barangay',
                            child: Text('Barangay Level'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value == null) return;

                          setState(() {
                            _audienceScope = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location name',
                          hintText: 'Example: Bongao RHU',
                          prefixIcon: Icon(Icons.location_city_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          hintText: 'Example: Bongao, Tawi-Tawi',
                          prefixIcon: Icon(Icons.location_on_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _DatePickerTile(
                        title: 'Start date',
                        value: _formatDate(_startDate),
                        icon: Icons.play_circle_rounded,
                        onTap: _pickStartDate,
                      ),
                      const SizedBox(height: 10),
                      _DatePickerTile(
                        title: 'End date',
                        value: _formatDate(_endDate),
                        icon: Icons.stop_circle_rounded,
                        onTap: _pickEndDate,
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: _registrationRequired,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Registration required',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Turn on if residents must register for this event.',
                        ),
                        onChanged: (bool value) {
                          setState(() {
                            _registrationRequired = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _maxParticipantsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max participants optional',
                          hintText: 'Example: 100',
                          prefixIcon: Icon(Icons.groups_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _contactPersonController,
                        decoration: const InputDecoration(
                          labelText: 'Contact person optional',
                          hintText: 'Example: RHU Staff',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _contactNumberController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact number optional',
                          hintText: 'Example: 09123456789',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _requirementsController,
                        decoration: const InputDecoration(
                          labelText: 'Requirements optional',
                          hintText: 'Example: ID, Face Mask, Water',
                          prefixIcon: Icon(Icons.checklist_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _isSaving ? 'Creating Event...' : 'Create Event',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () {
                      Navigator.of(context).pop();
                    },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateEventHeader extends StatelessWidget {
  const _CreateEventHeader();

  @override
  Widget build(BuildContext context) {
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
      child: const Row(
        children: <Widget>[
          Icon(
            Icons.event_rounded,
            color: Colors.white,
            size: 34,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Create RHU Event',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Publish medical missions, vaccination schedules, seminars, and public health activities.',
                  style: TextStyle(
                    color: Color(0xFFE0F2F1),
                    height: 1.45,
                    fontWeight: FontWeight.w500,
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

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: title,
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