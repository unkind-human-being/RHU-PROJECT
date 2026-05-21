import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';
import '../auth/auth_provider.dart';

class CreatePrescriptionScreen extends StatefulWidget {
  const CreatePrescriptionScreen({super.key});

  static const String routeName = '/create-prescription';

  @override
  State<CreatePrescriptionScreen> createState() =>
      _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState extends State<CreatePrescriptionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleInitialController =
      TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _doctorNameController = TextEditingController(
    text: 'DR. Alnidzfar-nadz D. Jericho',
  );
  final TextEditingController _quantityController =
      TextEditingController(text: '10');
  final TextEditingController _instructionsController =
      TextEditingController();

  late final ApiClient _apiClient;

  bool _isLoadingMedicines = false;
  bool _isSaving = false;
  bool _didApplyRouteArguments = false;

  String _selectedSex = 'male';
  String? _selectedMedicineId;
  String _appointmentId = '';
  String _patientUserId = '';
  String _rhuId = '';
  String _appointmentService = '';
  String _appointmentType = '';

  DateTime _expiresAt = DateTime.now().add(const Duration(days: 1));

  List<_MedicineOption> _medicines = <_MedicineOption>[];
  Map<String, dynamic>? _createdPrescription;

  bool get _hasAppointmentContext {
    return _appointmentId.trim().isNotEmpty ||
        _patientUserId.trim().isNotEmpty ||
        _appointmentService.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMedicines();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didApplyRouteArguments) {
      return;
    }

    _didApplyRouteArguments = true;
    _applyRouteArguments();
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _middleInitialController.dispose();
    _ageController.dispose();
    _contactNumberController.dispose();
    _diagnosisController.dispose();
    _doctorNameController.dispose();
    _quantityController.dispose();
    _instructionsController.dispose();
    _apiClient.close();

    super.dispose();
  }

  void _applyRouteArguments() {
    final Object? args = ModalRoute.of(context)?.settings.arguments;

    if (args == null) {
      return;
    }

    Map<String, dynamic> argumentMap = <String, dynamic>{};

    if (args is Map<String, dynamic>) {
      argumentMap = Map<String, dynamic>.from(args);
    } else {
      return;
    }

    final Map<String, dynamic> appointment =
        _extractAppointmentMap(argumentMap);

    _appointmentId = _firstNotEmpty(<String>[
      _readString(argumentMap, <String>['appointmentId']),
      _readString(appointment, <String>['_id', 'id']),
    ]);

    _patientUserId = _firstNotEmpty(<String>[
      _readUserId(argumentMap['patientUser']),
      _readUserId(argumentMap['requestedBy']),
      _readUserId(appointment['patientUser']),
      _readUserId(appointment['requestedBy']),
    ]);

    _rhuId = _firstNotEmpty(<String>[
      _readUserId(argumentMap['rhu']),
      _readUserId(appointment['rhu']),
    ]);

    _appointmentService = _firstNotEmpty(<String>[
      _readString(argumentMap, <String>['serviceType']),
      _readString(appointment, <String>['serviceType']),
    ]);

    _appointmentType = _firstNotEmpty(<String>[
      _readString(argumentMap, <String>['appointmentType']),
      _readString(appointment, <String>['appointmentType']),
    ]);

    _setControllerIfEmpty(
      _lastNameController,
      _firstNotEmpty(<String>[
        _readString(argumentMap, <String>['patientLastName']),
        _readString(appointment, <String>['patientLastName']),
      ]),
    );

    _setControllerIfEmpty(
      _firstNameController,
      _firstNotEmpty(<String>[
        _readString(argumentMap, <String>['patientFirstName']),
        _readString(appointment, <String>['patientFirstName']),
      ]),
    );

    _setControllerIfEmpty(
      _middleInitialController,
      _firstNotEmpty(<String>[
        _readString(argumentMap, <String>['patientMiddleInitial']),
        _readString(appointment, <String>['patientMiddleInitial']),
      ]),
    );

    _setControllerIfEmpty(
      _ageController,
      _firstNotEmpty(<String>[
        _readString(argumentMap, <String>['patientAge']),
        _readString(appointment, <String>['patientAge']),
      ]),
    );

    _setControllerIfEmpty(
      _contactNumberController,
      _firstNotEmpty(<String>[
        _readString(argumentMap, <String>['contactNumber']),
        _readString(appointment, <String>['contactNumber']),
        _readStringFromDynamic(
          argumentMap['patientUser'],
          <String>[
            'phoneNumber',
            'contactNumber',
          ],
        ),
        _readStringFromDynamic(
          appointment['requestedBy'],
          <String>[
            'phoneNumber',
            'contactNumber',
          ],
        ),
      ]),
    );

    final String sex = _firstNotEmpty(<String>[
      _readString(argumentMap, <String>['patientSex']),
      _readString(appointment, <String>['patientSex']),
    ]);

    if (<String>['male', 'female', 'prefer_not_to_say'].contains(sex)) {
      _selectedSex = sex;
    }

    _setControllerIfEmpty(
      _diagnosisController,
      _firstNotEmpty(<String>[
        _readString(argumentMap, <String>['diagnosis']),
        _readString(argumentMap, <String>['consultationDiagnosis']),
        _readString(argumentMap, <String>['consultationNotes']),
        _readString(appointment, <String>['consultationDiagnosis']),
        _readString(appointment, <String>['consultationNotes']),
        _readString(appointment, <String>['healthConcern']),
      ]),
    );
  }

  Map<String, dynamic> _extractAppointmentMap(Map<String, dynamic> args) {
    final dynamic appointment = args['appointment'];

    if (appointment is Map<String, dynamic>) {
      return Map<String, dynamic>.from(appointment);
    }

    final bool looksLikeAppointment =
        args.containsKey('_id') ||
        args.containsKey('id') ||
        args.containsKey('patientFirstName') ||
        args.containsKey('patientLastName') ||
        args.containsKey('serviceType') ||
        args.containsKey('appointmentType');

    if (looksLikeAppointment) {
      return args;
    }

    return <String, dynamic>{};
  }

  void _setControllerIfEmpty(
    TextEditingController controller,
    String value,
  ) {
    if (controller.text.trim().isNotEmpty) {
      return;
    }

    if (value.trim().isEmpty || value.trim() == 'null') {
      return;
    }

    controller.text = value.trim();
  }

  _MedicineOption? get _selectedMedicine {
    final String? selectedId = _selectedMedicineId;

    if (selectedId == null || selectedId.trim().isEmpty) {
      return null;
    }

    for (final _MedicineOption medicine in _medicines) {
      if (medicine.id == selectedId) {
        return medicine;
      }
    }

    return null;
  }

  String get _qrPayload {
    final Map<String, dynamic>? prescription = _createdPrescription;

    if (prescription == null) {
      return '';
    }

    final String payload = _readString(
      prescription,
      <String>[
        'qrPayload',
      ],
    );

    if (payload.trim().isNotEmpty) {
      return payload;
    }

    final String token = _readString(
      prescription,
      <String>[
        'qrToken',
      ],
    );

    if (token.trim().isEmpty) {
      return '';
    }

    return '{"type":"rhu_prescription_qr","token":"$token"}';
  }

  String get _qrToken {
    final Map<String, dynamic>? prescription = _createdPrescription;

    if (prescription == null) {
      return '';
    }

    return _readString(
      prescription,
      <String>[
        'qrToken',
      ],
    );
  }

  String get _patientFullName {
    final List<String> parts = <String>[
      _firstNameController.text.trim(),
      _middleInitialController.text.trim(),
      _lastNameController.text.trim(),
    ].where((String item) => item.trim().isNotEmpty).toList();

    if (parts.isEmpty) {
      return 'Patient';
    }

    return parts.join(' ');
  }

  Future<void> _loadMedicines() async {
    setState(() {
      _isLoadingMedicines = true;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/medicines',
        requiresAuth: true,
      );

      final List<dynamic> rawMedicines = _extractList(response);

      final List<_MedicineOption> medicines = rawMedicines
          .whereType<Map<String, dynamic>>()
          .map(_MedicineOption.fromJson)
          .where((_MedicineOption medicine) {
        return medicine.id.trim().isNotEmpty &&
            medicine.name.trim().isNotEmpty;
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _medicines = medicines;
        _selectedMedicineId ??= medicines.isEmpty ? null : medicines.first.id;
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

      _showError('Unable to load medicine list.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMedicines = false;
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
      final dynamic medicines = data['medicines'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (medicines is List) {
        return medicines;
      }

      if (results is List) {
        return results;
      }

      if (docs is List) {
        return docs;
      }

      if (items is List) {
        return items;
      }
    }

    final dynamic medicines = response['medicines'];

    if (medicines is List) {
      return medicines;
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

  Future<void> _pickExpirationDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _expiresAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 30),
      ),
    );

    if (pickedDate == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expiresAt),
    );

    if (pickedTime == null) {
      return;
    }

    setState(() {
      _expiresAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd hh:mm a').format(dateTime);
  }

  int? _readAge() {
    final String text = _ageController.text.trim();

    if (text.isEmpty) {
      return null;
    }

    return int.tryParse(text);
  }

  int _readQuantity() {
    return int.tryParse(_quantityController.text.trim()) ?? 1;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final _MedicineOption? selectedMedicine = _selectedMedicine;

    if (selectedMedicine == null) {
      _showError('Please select a medicine.');
      return;
    }

    setState(() {
      _isSaving = true;
      _createdPrescription = null;
    });

    try {
      final Map<String, dynamic> body = <String, dynamic>{
        if (_rhuId.trim().isNotEmpty) 'rhu': _rhuId.trim(),
        if (_appointmentId.trim().isNotEmpty)
          'appointment': _appointmentId.trim(),
        if (_patientUserId.trim().isNotEmpty)
          'patientUser': _patientUserId.trim(),
        'patientLastName': _lastNameController.text.trim(),
        'patientFirstName': _firstNameController.text.trim(),
        'patientMiddleInitial': _middleInitialController.text.trim(),
        'patientAge': _readAge(),
        'patientSex': _selectedSex,
        'contactNumber': _contactNumberController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'doctorName': _doctorNameController.text.trim(),
        'expiresAt': _expiresAt.toIso8601String(),
        'medicines': <Map<String, dynamic>>[
          <String, dynamic>{
            'medicine': selectedMedicine.id,
            'medicineName': selectedMedicine.name,
            'genericName': selectedMedicine.genericName,
            'strength': selectedMedicine.strength,
            'dosageForm': selectedMedicine.dosageForm,
            'quantity': _readQuantity(),
            'unit': selectedMedicine.unit,
            'instructions': _instructionsController.text.trim(),
          },
        ],
      };

      final Map<String, dynamic> response = await _apiClient.post(
        '/api/prescriptions',
        requiresAuth: true,
        body: body,
      );

      final Map<String, dynamic> createdPrescription = _extractMap(response);

      if (!mounted) {
        return;
      }

      setState(() {
        _createdPrescription = createdPrescription;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription QR created successfully.'),
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

      _showError('Unable to create prescription QR.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _copyQrToken() async {
    final String token = _qrToken;

    if (token.trim().isEmpty) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: token),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR token copied.'),
      ),
    );
  }

  void _useCreatedPrescription() {
    final Map<String, dynamic>? prescription = _createdPrescription;

    if (prescription == null) {
      return;
    }

    Navigator.of(context).pop(prescription);
  }

  void _resetForm() {
    setState(() {
      _createdPrescription = null;
      _quantityController.text = '10';
      _instructionsController.clear();
      _expiresAt = DateTime.now().add(const Duration(days: 1));

      if (!_hasAppointmentContext) {
        _lastNameController.clear();
        _firstNameController.clear();
        _middleInitialController.clear();
        _ageController.clear();
        _contactNumberController.clear();
        _diagnosisController.clear();
        _selectedSex = 'male';
      }
    });
  }

  Future<void> _handleBack() async {
    if (_createdPrescription != null) {
      Navigator.of(context).pop(_createdPrescription);
      return;
    }

    Navigator.of(context).pop(false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  String? _requiredValidator(String? value, String fieldName) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return '$fieldName is required.';
    }

    return null;
  }

  String? _ageValidator(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    final int? age = int.tryParse(text);

    if (age == null) {
      return 'Age must be a number.';
    }

    if (age < 0 || age > 130) {
      return 'Enter a valid age.';
    }

    return null;
  }

  String? _quantityValidator(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Quantity is required.';
    }

    final int? quantity = int.tryParse(text);

    if (quantity == null) {
      return 'Quantity must be a number.';
    }

    if (quantity <= 0) {
      return 'Quantity must be at least 1.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = context.watch<AuthProvider>();

    final bool selectedMedicineStillAvailable = _medicines.any(
      (_MedicineOption medicine) {
        return medicine.id == _selectedMedicineId;
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (
        bool didPop,
        Object? result,
      ) async {
        if (didPop) {
          return;
        }

        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6FAF9),
        appBar: AppBar(
          title: const Text(
            'Create Prescription QR',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadMedicines,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                _HeaderCard(
                  assignedLocation: authProvider.assignedLocation,
                  hasAppointmentContext: _hasAppointmentContext,
                ),
                if (_hasAppointmentContext) ...<Widget>[
                  const SizedBox(height: 14),
                  _AppointmentContextCard(
                    patientName: _patientFullName,
                    appointmentId: _appointmentId,
                    patientUserId: _patientUserId,
                    appointmentService: _appointmentService,
                    appointmentType: _appointmentType,
                  ),
                ],
                const SizedBox(height: 18),
                if (_createdPrescription != null)
                  _QrResultCard(
                    qrPayload: _qrPayload,
                    qrToken: _qrToken,
                    patientName: _patientFullName,
                    hasAppointmentContext: _hasAppointmentContext,
                    onCopy: _copyQrToken,
                    onUsePrescription: _useCreatedPrescription,
                    onCreateAnother: _resetForm,
                  )
                else
                  _PrescriptionFormCard(
                    formKey: _formKey,
                    lastNameController: _lastNameController,
                    firstNameController: _firstNameController,
                    middleInitialController: _middleInitialController,
                    ageController: _ageController,
                    contactNumberController: _contactNumberController,
                    diagnosisController: _diagnosisController,
                    doctorNameController: _doctorNameController,
                    quantityController: _quantityController,
                    instructionsController: _instructionsController,
                    selectedSex: _selectedSex,
                    isSaving: _isSaving,
                    isLoadingMedicines: _isLoadingMedicines,
                    selectedMedicineStillAvailable:
                        selectedMedicineStillAvailable,
                    selectedMedicineId: _selectedMedicineId,
                    medicines: _medicines,
                    expiresAtText: _formatDateTime(_expiresAt),
                    requiredValidator: _requiredValidator,
                    ageValidator: _ageValidator,
                    quantityValidator: _quantityValidator,
                    onSexChanged: (String value) {
                      setState(() {
                        _selectedSex = value;
                      });
                    },
                    onMedicineChanged: (String? value) {
                      setState(() {
                        _selectedMedicineId = value;
                      });
                    },
                    onPickExpirationDate: _pickExpirationDate,
                  ),
                const SizedBox(height: 20),
                if (_createdPrescription == null)
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
                        : const Icon(Icons.qr_code_2_rounded),
                    label: Text(
                      _isSaving
                          ? 'Creating Prescription...'
                          : _hasAppointmentContext
                              ? 'Create QR for Patient'
                              : 'Create Prescription QR',
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _handleBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(
                    _createdPrescription != null
                        ? _hasAppointmentContext
                            ? 'Return QR to Chat'
                            : 'Back'
                        : 'Back',
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrescriptionFormCard extends StatelessWidget {
  const _PrescriptionFormCard({
    required this.formKey,
    required this.lastNameController,
    required this.firstNameController,
    required this.middleInitialController,
    required this.ageController,
    required this.contactNumberController,
    required this.diagnosisController,
    required this.doctorNameController,
    required this.quantityController,
    required this.instructionsController,
    required this.selectedSex,
    required this.isSaving,
    required this.isLoadingMedicines,
    required this.selectedMedicineStillAvailable,
    required this.selectedMedicineId,
    required this.medicines,
    required this.expiresAtText,
    required this.requiredValidator,
    required this.ageValidator,
    required this.quantityValidator,
    required this.onSexChanged,
    required this.onMedicineChanged,
    required this.onPickExpirationDate,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController lastNameController;
  final TextEditingController firstNameController;
  final TextEditingController middleInitialController;
  final TextEditingController ageController;
  final TextEditingController contactNumberController;
  final TextEditingController diagnosisController;
  final TextEditingController doctorNameController;
  final TextEditingController quantityController;
  final TextEditingController instructionsController;
  final String selectedSex;
  final bool isSaving;
  final bool isLoadingMedicines;
  final bool selectedMedicineStillAvailable;
  final String? selectedMedicineId;
  final List<_MedicineOption> medicines;
  final String expiresAtText;
  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) ageValidator;
  final String? Function(String?) quantityValidator;
  final ValueChanged<String> onSexChanged;
  final ValueChanged<String?> onMedicineChanged;
  final VoidCallback? onPickExpirationDate;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(
          color: Color(0xFFD1FAE5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: formKey,
          child: Column(
            children: <Widget>[
              const _SectionHeader(
                title: 'Patient Information',
                subtitle: 'Confirm the patient details before creating the QR.',
                icon: Icons.person_rounded,
                color: Color(0xFF0EA5E9),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: lastNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Patient last name',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (String? value) {
                  return requiredValidator(
                    value,
                    'Patient last name',
                  );
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: firstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Patient first name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (String? value) {
                  return requiredValidator(
                    value,
                    'Patient first name',
                  );
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: middleInitialController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Middle initial optional',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
              ),
              const SizedBox(height: 2),
              TextFormField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age optional',
                  prefixIcon: Icon(Icons.cake_rounded),
                ),
                validator: ageValidator,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: selectedSex,
                decoration: const InputDecoration(
                  labelText: 'Sex',
                  prefixIcon: Icon(Icons.wc_rounded),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'male',
                    child: Text('Male'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'female',
                    child: Text('Female'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'prefer_not_to_say',
                    child: Text('Prefer not to say'),
                  ),
                ],
                onChanged: isSaving
                    ? null
                    : (String? value) {
                        if (value == null) {
                          return;
                        }

                        onSexChanged(value);
                      },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: contactNumberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact number optional',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
              ),
              const SizedBox(height: 22),
              const _SectionHeader(
                title: 'Consultation Details',
                subtitle:
                    'Diagnosis or notes will be included in the prescription record.',
                icon: Icons.description_rounded,
                color: Color(0xFF7C3AED),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: diagnosisController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis / notes',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.description_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: doctorNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Doctor name',
                  prefixIcon: Icon(Icons.medical_services_rounded),
                ),
                validator: (String? value) {
                  return requiredValidator(value, 'Doctor name');
                },
              ),
              const SizedBox(height: 22),
              const _SectionHeader(
                title: 'Medicine Prescription',
                subtitle: 'Choose medicine, quantity, and instructions.',
                icon: Icons.medication_rounded,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(height: 14),
              if (isLoadingMedicines)
                const _LoadingBox()
              else
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value:
                      selectedMedicineStillAvailable ? selectedMedicineId : null,
                  decoration: const InputDecoration(
                    labelText: 'Medicine',
                    prefixIcon: Icon(Icons.medication_rounded),
                  ),
                  items: medicines.map(
                    (_MedicineOption medicine) {
                      return DropdownMenuItem<String>(
                        value: medicine.id,
                        child: Text(
                          medicine.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ).toList(),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Medicine is required.';
                    }

                    return null;
                  },
                  onChanged: isSaving ? null : onMedicineChanged,
                ),
              const SizedBox(height: 14),
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
                validator: quantityValidator,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: instructionsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText:
                      'Example: Take 1 tablet every 6 hours as needed.',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 22),
              const _SectionHeader(
                title: 'QR Expiration',
                subtitle: 'After expiration, the pharmacy cannot claim this QR.',
                icon: Icons.event_rounded,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(height: 14),
              _DateTimeTile(
                title: 'QR expires at',
                value: expiresAtText,
                onTap: isSaving ? null : onPickExpirationDate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicineOption {
  const _MedicineOption({
    required this.id,
    required this.name,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.unit,
    required this.category,
  });

  factory _MedicineOption.fromJson(Map<String, dynamic> json) {
    return _MedicineOption(
      id: _readString(
        json,
        <String>[
          '_id',
          'id',
        ],
      ),
      name: _readString(
        json,
        <String>[
          'name',
          'medicineName',
        ],
      ),
      genericName: _readString(
        json,
        <String>[
          'genericName',
        ],
      ),
      strength: _readString(
        json,
        <String>[
          'strength',
        ],
      ),
      dosageForm: _readString(
        json,
        <String>[
          'dosageForm',
        ],
      ),
      unit: _readString(
        json,
        <String>[
          'unit',
        ],
      ),
      category: _readString(
        json,
        <String>[
          'category',
        ],
      ),
    );
  }

  final String id;
  final String name;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String unit;
  final String category;

  String get label {
    final List<String> parts = <String>[
      name,
      if (genericName.trim().isNotEmpty) genericName,
      if (strength.trim().isNotEmpty) strength,
      if (category.trim().isNotEmpty) category,
    ];

    return parts.join(' • ');
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.assignedLocation,
    required this.hasAppointmentContext,
  });

  final String assignedLocation;
  final bool hasAppointmentContext;

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
      child: Row(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  hasAppointmentContext
                      ? 'Prescription from Consultation'
                      : 'Prescription QR',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasAppointmentContext
                      ? 'Patient details were loaded from the appointment. Create the QR and return it to chat.'
                      : 'Create a QR code that the patient can use at the pharmacy.',
                  style: const TextStyle(
                    color: Color(0xFFE0F2F1),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  assignedLocation,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

class _AppointmentContextCard extends StatelessWidget {
  const _AppointmentContextCard({
    required this.patientName,
    required this.appointmentId,
    required this.patientUserId,
    required this.appointmentService,
    required this.appointmentType,
  });

  final String patientName;
  final String appointmentId;
  final String patientUserId;
  final String appointmentService;
  final String appointmentType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFA7F3D0),
        ),
      ),
      child: Column(
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.assignment_ind_rounded,
                color: Color(0xFF047857),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Linked Appointment',
                  style: TextStyle(
                    color: Color(0xFF064E3B),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _CompactInfoLine(
            label: 'Patient',
            value: patientName,
          ),
          _CompactInfoLine(
            label: 'Service',
            value: _prettyService(appointmentService),
          ),
          _CompactInfoLine(
            label: 'Type',
            value: _prettyAppointmentType(appointmentType),
          ),
          if (appointmentId.trim().isNotEmpty)
            _CompactInfoLine(
              label: 'Appointment',
              value: appointmentId,
            ),
          if (patientUserId.trim().isNotEmpty)
            _CompactInfoLine(
              label: 'Patient User',
              value: patientUserId,
            ),
        ],
      ),
    );
  }
}

class _QrResultCard extends StatelessWidget {
  const _QrResultCard({
    required this.qrPayload,
    required this.qrToken,
    required this.patientName,
    required this.hasAppointmentContext,
    required this.onCopy,
    required this.onUsePrescription,
    required this.onCreateAnother,
  });

  final String qrPayload;
  final String qrToken;
  final String patientName;
  final bool hasAppointmentContext;
  final VoidCallback onCopy;
  final VoidCallback onUsePrescription;
  final VoidCallback onCreateAnother;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(
          color: Color(0xFFBBF7D0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 52,
            ),
            const SizedBox(height: 10),
            Text(
              'Prescription QR Created',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasAppointmentContext
                  ? 'Return this QR to the consultation chat for $patientName.'
                  : 'Let the patient show this QR code to the pharmacist.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                ),
              ),
              child: QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 230,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(
              qrToken,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            if (hasAppointmentContext) ...<Widget>[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                  onPressed: onUsePrescription,
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Return QR to Chat'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy QR Token'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onCreateAnother,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  hasAppointmentContext
                      ? 'Create Another QR for Same Patient'
                      : 'Create Another Prescription',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: color,
            size: 25,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactInfoLine extends StatelessWidget {
  const _CompactInfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty || value.trim() == 'N/A') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 98,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF047857),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF064E3B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: title,
          prefixIcon: const Icon(Icons.event_rounded),
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

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 14),
            Expanded(
              child: Text('Loading medicine list...'),
            ),
          ],
        ),
      ),
    );
  }
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

String _firstNotEmpty(List<String> values) {
  for (final String value in values) {
    final String text = value.trim();

    if (text.isNotEmpty && text != 'null' && text != 'N/A') {
      return text;
    }
  }

  return '';
}

String _readUserId(dynamic value) {
  if (value == null) {
    return '';
  }

  if (value is Map<String, dynamic>) {
    return _readString(
      value,
      <String>[
        '_id',
        'id',
      ],
    );
  }

  return value.toString().trim();
}

String _readStringFromDynamic(
  dynamic value,
  List<String> keys,
) {
  if (value is Map<String, dynamic>) {
    return _readString(value, keys);
  }

  return '';
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
        <String>[
          '_id',
          'id',
          'name',
          'title',
          'fullName',
          'email',
        ],
      );

      if (nestedValue.trim().isNotEmpty && nestedValue != 'null') {
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