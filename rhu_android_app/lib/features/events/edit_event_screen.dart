import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/event_model.dart';
import '../../data/repositories/event_repository.dart';

class EditEventArguments {
  const EditEventArguments({
    required this.event,
  });

  final EventModel event;
}

class EditEventScreen extends StatefulWidget {
  const EditEventScreen({
    super.key,
    required this.event,
  });

  static const String routeName = '/edit-event';

  final EventModel event;

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _addressController;
  late final TextEditingController _maxParticipantsController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _contactNumberController;
  late final TextEditingController _requirementsController;

  final EventRepository _eventRepository = EventRepository();

  String _type = 'medical_mission';
  String _status = 'open';
  String _audienceScope = 'public';

  bool _registrationRequired = false;
  bool _isSaving = false;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 2));

  @override
  void initState() {
    super.initState();

    final dynamic event = widget.event;

    _titleController = TextEditingController(
      text: _safeText(event.title),
    );

    _descriptionController = TextEditingController(
      text: _safeText(event.description),
    );

    _locationController = TextEditingController(
      text: _safeText(
        event.locationName,
        fallback: _safeText(event.locationDisplay),
      ),
    );

    _addressController = TextEditingController(
      text: _safeText(event.address),
    );

    _maxParticipantsController = TextEditingController(
      text: _readIntDynamic(event.maxParticipants, fallback: 0).toString(),
    );

    _contactPersonController = TextEditingController(
      text: _safeText(event.contactPerson),
    );

    _contactNumberController = TextEditingController(
      text: _safeText(event.contactNumber),
    );

    _requirementsController = TextEditingController(
      text: _readRequirements(event.requirements).join(', '),
    );

    _type = _normalizeDropdownValue(
      _safeText(event.type),
      allowedValues: <String>[
        'medical_mission',
        'vaccination',
        'deworming',
        'seminar',
        'health_checkup',
        'other',
      ],
      fallback: 'medical_mission',
    );

    _status = _normalizeDropdownValue(
      _safeText(event.status),
      allowedValues: <String>[
        'draft',
        'open',
        'closed',
        'completed',
        'cancelled',
      ],
      fallback: 'open',
    );

    _audienceScope = _normalizeDropdownValue(
      _safeText(event.audienceScope),
      allowedValues: <String>[
        'public',
        'staff',
        'rhu',
        'barangay',
      ],
      fallback: 'public',
    );

    _registrationRequired = _readBool(event.registrationRequired);

    _startDate = _readDateDynamic(
      event.startDate,
      fallback: DateTime.now(),
    );

    _endDate = _readDateDynamic(
      event.endDate,
      fallback: _startDate.add(const Duration(hours: 2)),
    );

    if (_endDate.isBefore(_startDate)) {
      _endDate = _startDate.add(const Duration(hours: 2));
    }
  }

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

  String _safeText(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }

    final String text = value.toString().trim();

    if (text.isEmpty || text == 'null') {
      return fallback;
    }

    return text;
  }

  bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final String text = value?.toString().trim().toLowerCase() ?? '';

    return text == 'true' || text == '1' || text == 'yes';
  }

  int _readIntDynamic(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    final int? parsed = int.tryParse(value?.toString() ?? '');

    return parsed ?? fallback;
  }

  DateTime _readDateDynamic(dynamic value, {required DateTime fallback}) {
    if (value is DateTime) {
      return value;
    }

    if (value == null) {
      return fallback;
    }

    final DateTime? parsed = DateTime.tryParse(value.toString());

    return parsed ?? fallback;
  }

  List<String> _readRequirements(dynamic value) {
    if (value is List) {
      return value
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }

    final String text = value?.toString().trim() ?? '';

    if (text.isEmpty || text == 'null') {
      return <String>[];
    }

    return text
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  String _normalizeDropdownValue(
    String value, {
    required List<String> allowedValues,
    required String fallback,
  }) {
    final String lower = value.trim().toLowerCase();

    if (allowedValues.contains(lower)) {
      return lower;
    }

    return fallback;
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
  }

  List<String> _readRequirementsFromInput() {
    return _requirementsController.text
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  int _readInt(TextEditingController controller) {
    return int.tryParse(controller.text.trim()) ?? 0;
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initialDateTime,
    required DateTime firstDate,
  }) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (pickedDate == null) {
      return null;
    }

    if (!mounted) {
      return null;
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
    );

    if (pickedTime == null) {
      return null;
    }

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _pickStartDate() async {
    final DateTime? picked = await _pickDateTime(
      initialDateTime: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _startDate = picked;

      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate.add(const Duration(hours: 2));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final DateTime? picked = await _pickDateTime(
      initialDateTime: _endDate,
      firstDate: _startDate,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _endDate = picked;
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

    final int maxParticipants = _readInt(_maxParticipantsController);

    if (maxParticipants < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Max participants cannot be negative.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _eventRepository.updateEvent(
        eventId: widget.event.id,
        title: _titleController.text,
        description: _descriptionController.text,
        type: _type,
        status: _status,
        audienceScope: _audienceScope,
        locationName: _locationController.text,
        address: _addressController.text,
        startDate: _startDate,
        endDate: _endDate,
        registrationRequired: _registrationRequired,
        maxParticipants: maxParticipants,
        contactPerson: _contactPersonController.text,
        contactNumber: _contactNumberController.text,
        requirements: _readRequirementsFromInput(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event updated successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      Navigator.of(context).pop(true);
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
          content: Text('Unable to update event.'),
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

  String? _requiredValidator(String? value, String fieldName) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return '$fieldName is required.';
    }

    return null;
  }

  String? _numberValidator(String? value, String fieldName) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    final int? number = int.tryParse(text);

    if (number == null) {
      return '$fieldName must be a number.';
    }

    if (number < 0) {
      return '$fieldName cannot be negative.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Event',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const _HeaderCard(),
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
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Event title',
                          hintText: 'Example: Free Medical Checkup',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (String? value) {
                          return _requiredValidator(value, 'Event title');
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 4,
                        maxLines: 7,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Event description',
                          hintText: 'Describe the event details.',
                          prefixIcon: Icon(Icons.description_rounded),
                          alignLabelWithHint: true,
                        ),
                        validator: (String? value) {
                          return _requiredValidator(
                            value,
                            'Event description',
                          );
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
                          DropdownMenuItem<String>(
                            value: 'other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }

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
                            value: 'draft',
                            child: Text('Draft'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'open',
                            child: Text('Open'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'closed',
                            child: Text('Closed'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'cancelled',
                            child: Text('Cancelled'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }

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
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _audienceScope = value;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'Schedule'),
                      const SizedBox(height: 12),
                      _DateTimePickerTile(
                        title: 'Start date and time',
                        value: _formatDateTime(_startDate),
                        icon: Icons.play_circle_rounded,
                        onTap: _pickStartDate,
                      ),
                      const SizedBox(height: 12),
                      _DateTimePickerTile(
                        title: 'End date and time',
                        value: _formatDateTime(_endDate),
                        icon: Icons.stop_circle_rounded,
                        onTap: _pickEndDate,
                      ),
                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'Location'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Location name',
                          hintText: 'Example: RHU Bongao',
                          prefixIcon: Icon(Icons.location_on_rounded),
                        ),
                        validator: (String? value) {
                          return _requiredValidator(value, 'Location name');
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _addressController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          hintText: 'Example: Poblacion, Bongao, Tawi-Tawi',
                          prefixIcon: Icon(Icons.map_rounded),
                        ),
                        validator: (String? value) {
                          return _requiredValidator(value, 'Address');
                        },
                      ),
                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'Registration'),
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
                          'Turn on if participants need to register.',
                        ),
                        onChanged: (bool value) {
                          setState(() {
                            _registrationRequired = value;
                          });
                        },
                      ),
                      TextFormField(
                        controller: _maxParticipantsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max participants',
                          hintText: 'Example: 50. Use 0 for no limit.',
                          prefixIcon: Icon(Icons.groups_rounded),
                        ),
                        validator: (String? value) {
                          return _numberValidator(value, 'Max participants');
                        },
                      ),
                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'Contact and Requirements'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contactPersonController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Contact person optional',
                          hintText: 'Example: Nurse Amina',
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
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Requirements optional',
                          hintText:
                              'Example: Valid ID, PhilHealth card, face mask',
                          prefixIcon: Icon(Icons.checklist_rounded),
                          alignLabelWithHint: true,
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
                _isSaving ? 'Saving Changes...' : 'Save Changes',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () {
                      Navigator.of(context).pop(false);
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

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
            Icons.edit_calendar_rounded,
            color: Colors.white,
            size: 34,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Edit Event',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Update schedule, location, status, audience, registration, and requirements.',
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _DateTimePickerTile extends StatelessWidget {
  const _DateTimePickerTile({
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
