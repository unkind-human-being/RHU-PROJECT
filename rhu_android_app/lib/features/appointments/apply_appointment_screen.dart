import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';
import '../auth/auth_provider.dart';

class ApplyAppointmentScreen extends StatefulWidget {
  const ApplyAppointmentScreen({
    super.key,
    this.preselectedRhuId,
  });

  static const String routeName = '/apply-appointment';

  final String? preselectedRhuId;

  @override
  State<ApplyAppointmentScreen> createState() => _ApplyAppointmentScreenState();
}

class _ApplyAppointmentScreenState extends State<ApplyAppointmentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleInitialController =
      TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _healthConcernController =
      TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _birthCertificateUrlController =
      TextEditingController();

  late final TokenStorageService _tokenStorageService;
  late final ApiClient _apiClient;

  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoadingRhus = false;
  bool _isLoadingAppointmentSetting = false;
  bool _isSubmitting = false;
  bool _isUploadingBirthCertificate = false;
  bool _confirmationChecked = false;

  XFile? _selectedBirthCertificateImage;
  String? _selectedRhuId;
  _AppointmentSetting? _appointmentSetting;

  String _selectedServiceType = 'medical_consultation';
  String _selectedAppointmentType = 'walk_in';
  String _selectedSex = 'male';
  String _selectedReligion = 'islam';
  String _selectedCivilStatus = 'single';

  List<_RhuOption> _rhus = <_RhuOption>[];

  bool get _isOnlineAppointment => _selectedAppointmentType == 'online';

  bool get _hasBirthCertificate {
    return _selectedBirthCertificateImage != null ||
        _birthCertificateUrlController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();

    _tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: _tokenStorageService.getToken,
    );

    final String? preselectedRhuId = widget.preselectedRhuId;

    if (preselectedRhuId != null && preselectedRhuId.trim().isNotEmpty) {
      _selectedRhuId = preselectedRhuId.trim();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRhus();
    });
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _middleInitialController.dispose();
    _ageController.dispose();
    _contactNumberController.dispose();
    _healthConcernController.dispose();
    _symptomsController.dispose();
    _birthCertificateUrlController.dispose();
    _apiClient.close();

    super.dispose();
  }

  _RhuOption? get _selectedRhu {
    final String? selectedRhuId = _selectedRhuId;

    if (selectedRhuId == null || selectedRhuId.trim().isEmpty) {
      return null;
    }

    for (final _RhuOption rhu in _rhus) {
      if (rhu.id == selectedRhuId) {
        return rhu;
      }
    }

    return null;
  }

  List<DropdownMenuItem<String>> get _appointmentTypeItems {
    final _AppointmentSetting? setting = _appointmentSetting;

    if (setting == null) {
      return const <DropdownMenuItem<String>>[
        DropdownMenuItem<String>(
          value: 'walk_in',
          child: Text('Walk-in'),
        ),
        DropdownMenuItem<String>(
          value: 'online',
          child: Text('Online Consultation'),
        ),
      ];
    }

    if (!setting.isAcceptingAppointments) {
      return const <DropdownMenuItem<String>>[];
    }

    final List<DropdownMenuItem<String>> items = <DropdownMenuItem<String>>[];

    if (setting.allowWalkIn) {
      items.add(
        const DropdownMenuItem<String>(
          value: 'walk_in',
          child: Text('Walk-in'),
        ),
      );
    }

    if (setting.allowOnline) {
      items.add(
        const DropdownMenuItem<String>(
          value: 'online',
          child: Text('Online Consultation'),
        ),
      );
    }

    return items;
  }

  bool get _canSubmitAppointment {
    final _AppointmentSetting? setting = _appointmentSetting;

    if (setting == null) {
      return true;
    }

    if (!setting.isAcceptingAppointments) {
      return false;
    }

    if (_selectedAppointmentType == 'walk_in') {
      return setting.allowWalkIn;
    }

    if (_selectedAppointmentType == 'online') {
      return setting.allowOnline;
    }

    return false;
  }

  Future<void> _loadRhus() async {
    setState(() {
      _isLoadingRhus = true;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/rhus',
        requiresAuth: true,
      );

      final List<dynamic> rawRhus = _extractList(response);

      final List<_RhuOption> rhus = rawRhus
          .whereType<Map<String, dynamic>>()
          .map(_RhuOption.fromJson)
          .where((_RhuOption rhu) => rhu.id.trim().isNotEmpty)
          .toList();

      String? nextSelectedRhuId = _selectedRhuId;

      final bool selectedRhuExists = rhus.any((_RhuOption rhu) {
        return rhu.id == nextSelectedRhuId;
      });

      if (!selectedRhuExists) {
        nextSelectedRhuId = rhus.isEmpty ? null : rhus.first.id;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _rhus = rhus;
        _selectedRhuId = nextSelectedRhuId;
      });

      if (nextSelectedRhuId != null && nextSelectedRhuId.trim().isNotEmpty) {
        await _loadAppointmentSetting(nextSelectedRhuId);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to load RHU list.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRhus = false;
        });
      }
    }
  }

  Future<void> _loadAppointmentSetting(String rhuId) async {
    setState(() {
      _isLoadingAppointmentSetting = true;
      _appointmentSetting = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/appointment-settings/rhu/${Uri.encodeComponent(rhuId)}',
        requiresAuth: true,
      );

      final Map<String, dynamic> data = _extractMap(response);
      final _AppointmentSetting setting = _AppointmentSetting.fromJson(data);

      if (!mounted) {
        return;
      }

      setState(() {
        _appointmentSetting = setting;

        if (!setting.isAcceptingAppointments) {
          _selectedAppointmentType = '';
        } else if (_selectedAppointmentType == 'walk_in' &&
            !setting.allowWalkIn &&
            setting.allowOnline) {
          _selectedAppointmentType = 'online';
        } else if (_selectedAppointmentType == 'online' &&
            !setting.allowOnline &&
            setting.allowWalkIn) {
          _selectedAppointmentType = 'walk_in';
          _clearBirthCertificate();
        } else if (_selectedAppointmentType.trim().isEmpty) {
          if (setting.allowWalkIn) {
            _selectedAppointmentType = 'walk_in';
            _clearBirthCertificate();
          } else if (setting.allowOnline) {
            _selectedAppointmentType = 'online';
          }
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _appointmentSetting = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAppointmentSetting = false;
        });
      }
    }
  }

  void _changeAppointmentType(String value) {
    setState(() {
      _selectedAppointmentType = value;

      if (value != 'online') {
        _clearBirthCertificate();
      }
    });
  }

  Future<void> _pickBirthCertificate(ImageSource source) async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (pickedImage == null) {
        return;
      }

      setState(() {
        _selectedBirthCertificateImage = pickedImage;
        _birthCertificateUrlController.clear();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to pick birth certificate image.');
    }
  }

  void _clearBirthCertificate() {
    _selectedBirthCertificateImage = null;
    _birthCertificateUrlController.clear();
  }

  void _removeBirthCertificate() {
    setState(() {
      _clearBirthCertificate();
    });
  }

  Future<String> _uploadBirthCertificateIfNeeded() async {
    if (!_isOnlineAppointment) {
      return '';
    }

    final String existingUrl = _birthCertificateUrlController.text.trim();

    if (existingUrl.isNotEmpty && _selectedBirthCertificateImage == null) {
      return existingUrl;
    }

    final XFile? selectedImage = _selectedBirthCertificateImage;

    if (selectedImage == null) {
      return '';
    }

    setState(() {
      _isUploadingBirthCertificate = true;
    });

    try {
      final String? token = await _tokenStorageService.getToken();

      if (token == null || token.trim().isEmpty) {
        throw const _UploadFailure('Authentication token is missing.');
      }

      final Uri uploadUri = Uri.parse(
        '$_apiBaseUrl/api/uploads/appointment-photo',
      );

      final http.MultipartRequest request = http.MultipartRequest(
        'POST',
        uploadUri,
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          selectedImage.path,
        ),
      );

      final http.StreamedResponse streamedResponse = await request.send();
      final String responseBody = await streamedResponse.stream.bytesToString();

      dynamic decoded;

      try {
        decoded = jsonDecode(responseBody);
      } catch (_) {
        decoded = null;
      }

      final bool successStatus =
          streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300;

      if (!successStatus) {
        String message = 'Unable to upload birth certificate.';

        if (decoded is Map<String, dynamic>) {
          final dynamic serverMessage = decoded['message'];

          if (serverMessage != null &&
              serverMessage.toString().trim().isNotEmpty) {
            message = serverMessage.toString();
          }
        }

        throw _UploadFailure(message);
      }

      if (decoded is! Map<String, dynamic>) {
        throw const _UploadFailure('Invalid upload response from server.');
      }

      final dynamic data = decoded['data'];
      String uploadedUrl = '';

      if (data is Map<String, dynamic>) {
        uploadedUrl = _readString(
          data,
          <String>['url', 'secureUrl', 'secure_url'],
        );
      }

      if (uploadedUrl.trim().isEmpty) {
        uploadedUrl = _readString(
          decoded,
          <String>['url', 'secureUrl', 'secure_url'],
        );
      }

      if (uploadedUrl.trim().isEmpty) {
        throw const _UploadFailure('Cloudinary URL was not returned.');
      }

      if (mounted) {
        setState(() {
          _birthCertificateUrlController.text = uploadedUrl;
        });
      }

      return uploadedUrl;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingBirthCertificate = false;
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
      final dynamic rhus = data['rhus'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (rhus is List) return rhus;
      if (results is List) return results;
      if (docs is List) return docs;
      if (items is List) return items;
    }

    final dynamic rhus = response['rhus'];

    if (rhus is List) {
      return rhus;
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
      return 'Age is required.';
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

  int _readAge() {
    return int.tryParse(_ageController.text.trim()) ?? 0;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRhuId == null || _selectedRhuId!.trim().isEmpty) {
      _showError('Please select an RHU.');
      return;
    }

    if (!_canSubmitAppointment) {
      final _AppointmentSetting? setting = _appointmentSetting;

      if (setting != null && !setting.isAcceptingAppointments) {
        _showError(
          setting.unavailableReason.trim().isEmpty
              ? 'This RHU is not accepting appointments right now.'
              : setting.unavailableReason,
        );
      } else {
        _showError('Selected appointment type is not available for this RHU.');
      }

      return;
    }

    if (_isOnlineAppointment && !_hasBirthCertificate) {
      _showError(
        'Patient birth certificate is required for online consultation.',
      );
      return;
    }

    if (!_confirmationChecked) {
      _showError(
        'Please confirm that this appointment request is real and correct.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final String uploadedBirthCertificateUrl =
          await _uploadBirthCertificateIfNeeded();

      final Map<String, dynamic> body = <String, dynamic>{
        'rhu': _selectedRhuId,
        'serviceType': _selectedServiceType,
        'appointmentType': _selectedAppointmentType,
        'patientLastName': _lastNameController.text.trim(),
        'patientFirstName': _firstNameController.text.trim(),
        'patientMiddleInitial': _middleInitialController.text.trim(),
        'patientAge': _readAge(),
        'patientSex': _selectedSex,
        'religion': _selectedReligion,
        'civilStatus': _selectedCivilStatus,
        'contactNumber': _contactNumberController.text.trim(),
        'patientPhotoUrl': uploadedBirthCertificateUrl,
        'healthConcern': _healthConcernController.text.trim(),
        'symptomsDescription': _symptomsController.text.trim(),
        'confirmationChecked': _confirmationChecked,
      };

      await _apiClient.post(
        '/api/appointments',
        requiresAuth: true,
        body: body,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment request submitted successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      Navigator.of(context).pop(true);
    } on _UploadFailure catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to submit appointment request.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
    final AuthProvider authProvider = context.watch<AuthProvider>();

    final bool selectedRhuStillAvailable = _rhus.any(
      (_RhuOption rhu) {
        return rhu.id == _selectedRhuId;
      },
    );

    final List<DropdownMenuItem<String>> appointmentTypeItems =
        _appointmentTypeItems;

    final bool selectedTypeStillAvailable = appointmentTypeItems.any(
      (DropdownMenuItem<String> item) {
        return item.value == _selectedAppointmentType;
      },
    );

    final bool isBusy = _isSubmitting || _isUploadingBirthCertificate;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Apply Appointment',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadRhus();

            final String? selectedRhuId = _selectedRhuId;

            if (selectedRhuId != null && selectedRhuId.trim().isNotEmpty) {
              await _loadAppointmentSetting(selectedRhuId);
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _HeaderCard(
                userEmail: authProvider.user?.email ?? 'Public User',
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: <Widget>[
                        const _SectionLabel(
                          title: 'RHU and Service',
                          icon: Icons.local_hospital_rounded,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingRhus)
                          const _LoadingBox()
                        else
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedRhuStillAvailable
                                ? _selectedRhuId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Choose RHU',
                              prefixIcon: Icon(Icons.local_hospital_rounded),
                            ),
                            items: _rhus.map((_RhuOption rhu) {
                              return DropdownMenuItem<String>(
                                value: rhu.id,
                                child: Text(
                                  rhu.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            validator: (String? value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'RHU is required.';
                              }

                              return null;
                            },
                            onChanged: isBusy
                                ? null
                                : (String? value) {
                                    setState(() {
                                      _selectedRhuId = value;
                                    });

                                    if (value != null &&
                                        value.trim().isNotEmpty) {
                                      _loadAppointmentSetting(value);
                                    }
                                  },
                          ),
                        if (_selectedRhu != null) ...<Widget>[
                          const SizedBox(height: 10),
                          _SelectedRhuNote(rhu: _selectedRhu!),
                          const SizedBox(height: 10),
                          if (_isLoadingAppointmentSetting)
                            const _AppointmentSettingLoadingNote()
                          else if (_appointmentSetting != null)
                            _AppointmentAvailabilityNote(
                              setting: _appointmentSetting!,
                            ),
                        ],
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedServiceType,
                          decoration: const InputDecoration(
                            labelText: 'Service needed',
                            prefixIcon: Icon(Icons.medical_services_rounded),
                          ),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: 'medical_consultation',
                              child: Text('Medical Consultation'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'maternal_care',
                              child: Text('Maternal Care'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'family_planning',
                              child: Text('Family Planning'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'screening_prevention',
                              child: Text('Screening & Prevention'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'dental_services',
                              child: Text('Dental Services'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'immunization',
                              child: Text('Immunization'),
                            ),
                          ],
                          onChanged: isBusy
                              ? null
                              : (String? value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _selectedServiceType = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 14),
                        if (appointmentTypeItems.isEmpty)
                          const _ClosedAppointmentTypeBox()
                        else
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedTypeStillAvailable
                                ? _selectedAppointmentType
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Appointment type',
                              prefixIcon: Icon(Icons.event_available_rounded),
                            ),
                            items: appointmentTypeItems,
                            validator: (String? value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Appointment type is required.';
                              }

                              return null;
                            },
                            onChanged: isBusy
                                ? null
                                : (String? value) {
                                    if (value == null) {
                                      return;
                                    }

                                    _changeAppointmentType(value);
                                  },
                          ),
                        if (_isOnlineAppointment) ...<Widget>[
                          const SizedBox(height: 16),
                          _BirthCertificatePickerCard(
                            selectedImage: _selectedBirthCertificateImage,
                            uploadedImageUrl:
                                _birthCertificateUrlController.text.trim(),
                            isUploading: _isUploadingBirthCertificate,
                            isDisabled: isBusy,
                            onTakePhoto: () {
                              _pickBirthCertificate(ImageSource.camera);
                            },
                            onChooseGallery: () {
                              _pickBirthCertificate(ImageSource.gallery);
                            },
                            onRemove: _removeBirthCertificate,
                          ),
                        ] else ...<Widget>[
                          const SizedBox(height: 12),
                          const _WalkInNoUploadNote(),
                        ],
                        const SizedBox(height: 22),
                        const _SectionLabel(
                          title: 'Patient Information',
                          icon: Icons.person_rounded,
                          color: Color(0xFF0EA5E9),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Patient last name',
                            prefixIcon: Icon(Icons.person_rounded),
                          ),
                          validator: (String? value) {
                            return _requiredValidator(value, 'Last name');
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _firstNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Patient first name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (String? value) {
                            return _requiredValidator(value, 'First name');
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _middleInitialController,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 10,
                          decoration: const InputDecoration(
                            labelText: 'Middle initial optional',
                            prefixIcon: Icon(Icons.badge_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Age',
                            prefixIcon: Icon(Icons.cake_rounded),
                          ),
                          validator: _ageValidator,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedSex,
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
                          onChanged: isBusy
                              ? null
                              : (String? value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _selectedSex = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedReligion,
                          decoration: const InputDecoration(
                            labelText: 'Religion',
                            prefixIcon: Icon(Icons.account_balance_rounded),
                          ),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: 'islam',
                              child: Text('Islam'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'christianity',
                              child: Text('Christianity'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'other',
                              child: Text('Other'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'prefer_not_to_say',
                              child: Text('Prefer not to say'),
                            ),
                          ],
                          onChanged: isBusy
                              ? null
                              : (String? value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _selectedReligion = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedCivilStatus,
                          decoration: const InputDecoration(
                            labelText: 'Civil status',
                            prefixIcon: Icon(Icons.family_restroom_rounded),
                          ),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: 'single',
                              child: Text('Single'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'married',
                              child: Text('Married'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'widowed',
                              child: Text('Widowed'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'separated',
                              child: Text('Separated'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'prefer_not_to_say',
                              child: Text('Prefer not to say'),
                            ),
                          ],
                          onChanged: isBusy
                              ? null
                              : (String? value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _selectedCivilStatus = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _contactNumberController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Contact number',
                            hintText: 'Example: 09123456789',
                            prefixIcon: Icon(Icons.phone_rounded),
                          ),
                          validator: (String? value) {
                            return _requiredValidator(value, 'Contact number');
                          },
                        ),
                        const SizedBox(height: 22),
                        const _SectionLabel(
                          title: 'Health Concern',
                          icon: Icons.healing_rounded,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _healthConcernController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Main issue / concern',
                            hintText: 'Example: Fever and headache',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.healing_rounded),
                          ),
                          validator: (String? value) {
                            return _requiredValidator(
                              value,
                              'Health concern',
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _symptomsController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Symptoms / description optional',
                            hintText: 'Example: Fever for 2 days with body pain.',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _ConfirmationBox(
                          value: _confirmationChecked,
                          onChanged: isBusy
                              ? null
                              : (bool? value) {
                                  setState(() {
                                    _confirmationChecked = value ?? false;
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: isBusy || !_canSubmitAppointment ? null : _submit,
                icon: isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isUploadingBirthCertificate
                      ? 'Uploading Birth Certificate...'
                      : _isSubmitting
                          ? 'Submitting Request...'
                          : 'Submit Appointment Request',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () {
                        Navigator.of(context).pop(false);
                      },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadFailure implements Exception {
  const _UploadFailure(this.message);

  final String message;
}

class _BirthCertificatePickerCard extends StatelessWidget {
  const _BirthCertificatePickerCard({
    required this.selectedImage,
    required this.uploadedImageUrl,
    required this.isUploading,
    required this.isDisabled,
    required this.onTakePhoto,
    required this.onChooseGallery,
    required this.onRemove,
  });

  final XFile? selectedImage;
  final String uploadedImageUrl;
  final bool isUploading;
  final bool isDisabled;
  final VoidCallback onTakePhoto;
  final VoidCallback onChooseGallery;
  final VoidCallback onRemove;

  bool get _hasImage {
    return selectedImage != null || uploadedImageUrl.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _hasImage ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _BirthCertificatePreview(
                selectedImage: selectedImage,
                uploadedImageUrl: uploadedImageUrl,
                isUploading: isUploading,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Patient Birth Certificate',
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Required',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _hasImage
                          ? 'Birth certificate selected. It will be uploaded before submission.'
                          : 'Required for online consultation. Take a clear photo or choose from gallery.',
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isDisabled ? null : onTakePhoto,
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Take Photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isDisabled ? null : onChooseGallery,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          if (_hasImage) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: isDisabled ? null : onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove Birth Certificate'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BirthCertificatePreview extends StatelessWidget {
  const _BirthCertificatePreview({
    required this.selectedImage,
    required this.uploadedImageUrl,
    required this.isUploading,
  });

  final XFile? selectedImage;
  final String uploadedImageUrl;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (selectedImage != null) {
      child = Image.file(
        File(selectedImage!.path),
        width: 92,
        height: 92,
        fit: BoxFit.cover,
      );
    } else if (uploadedImageUrl.trim().isNotEmpty) {
      child = Image.network(
        uploadedImageUrl,
        width: 92,
        height: 92,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return const Icon(
            Icons.broken_image_rounded,
            color: Color(0xFF92400E),
            size: 36,
          );
        },
      );
    } else {
      child = const Icon(
        Icons.file_upload_rounded,
        color: Color(0xFFF59E0B),
        size: 38,
      );
    }

    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 92,
            height: 92,
            color: const Color(0xFFFFF7ED),
            alignment: Alignment.center,
            child: child,
          ),
        ),
        if (isUploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WalkInNoUploadNote extends StatelessWidget {
  const _WalkInNoUploadNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFBBF7D0),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Walk-in appointment does not require a birth certificate upload.',
              style: TextStyle(
                color: Color(0xFF166534),
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RhuOption {
  const _RhuOption({
    required this.id,
    required this.name,
    required this.municipality,
    required this.contactNumber,
  });

  factory _RhuOption.fromJson(Map<String, dynamic> json) {
    final String name = _readString(
      json,
      <String>[
        'name',
        'rhuName',
        'officeName',
      ],
    );

    return _RhuOption(
      id: _readString(
        json,
        <String>[
          '_id',
          'id',
        ],
      ),
      name: name.isEmpty ? 'Unnamed RHU' : name,
      municipality: _readString(
        json,
        <String>[
          'municipality',
          'city',
        ],
      ),
      contactNumber: _readString(
        json,
        <String>[
          'contactNumber',
          'phoneNumber',
          'phone',
        ],
      ),
    );
  }

  final String id;
  final String name;
  final String municipality;
  final String contactNumber;
}

class _AppointmentSetting {
  const _AppointmentSetting({
    required this.isAcceptingAppointments,
    required this.allowWalkIn,
    required this.allowOnline,
    required this.unavailableReason,
    required this.walkInStartTime,
    required this.walkInEndTime,
    required this.onlineStartTime,
    required this.onlineEndTime,
    required this.instructionsForPatients,
  });

  factory _AppointmentSetting.fromJson(Map<String, dynamic> json) {
    return _AppointmentSetting(
      isAcceptingAppointments: _readBool(
        json,
        'isAcceptingAppointments',
        fallback: true,
      ),
      allowWalkIn: _readBool(json, 'allowWalkIn', fallback: true),
      allowOnline: _readBool(json, 'allowOnline', fallback: true),
      unavailableReason: _readString(json, <String>['unavailableReason']),
      walkInStartTime: _readString(
        json,
        <String>['walkInStartTime'],
        fallback: '08:00',
      ),
      walkInEndTime: _readString(
        json,
        <String>['walkInEndTime'],
        fallback: '17:00',
      ),
      onlineStartTime: _readString(
        json,
        <String>['onlineStartTime'],
        fallback: '08:00',
      ),
      onlineEndTime: _readString(
        json,
        <String>['onlineEndTime'],
        fallback: '17:00',
      ),
      instructionsForPatients: _readString(
        json,
        <String>['instructionsForPatients'],
      ),
    );
  }

  final bool isAcceptingAppointments;
  final bool allowWalkIn;
  final bool allowOnline;
  final String unavailableReason;
  final String walkInStartTime;
  final String walkInEndTime;
  final String onlineStartTime;
  final String onlineEndTime;
  final String instructionsForPatients;
}

class _AppointmentSettingLoadingNote extends StatelessWidget {
  const _AppointmentSettingLoadingNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: const Row(
        children: <Widget>[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Checking RHU appointment availability...',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentAvailabilityNote extends StatelessWidget {
  const _AppointmentAvailabilityNote({
    required this.setting,
  });

  final _AppointmentSetting setting;

  @override
  Widget build(BuildContext context) {
    final bool open = setting.isAcceptingAppointments;

    final String statusText = open
        ? 'This RHU is accepting appointments.'
        : (setting.unavailableReason.trim().isEmpty
            ? 'This RHU is not accepting appointments right now.'
            : setting.unavailableReason);

    final List<String> availableTypes = <String>[];

    if (setting.allowWalkIn) {
      availableTypes.add(
        'Walk-in: ${_formatTimeLabel(setting.walkInStartTime)} - ${_formatTimeLabel(setting.walkInEndTime)}',
      );
    }

    if (setting.allowOnline) {
      availableTypes.add(
        'Online: ${_formatTimeLabel(setting.onlineStartTime)} - ${_formatTimeLabel(setting.onlineEndTime)}',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: open ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: open ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                open ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: open ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color:
                        open ? const Color(0xFF166534) : const Color(0xFF991B1B),
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (open && availableTypes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              availableTypes.join('\n'),
              style: const TextStyle(
                color: Color(0xFF166534),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
          if (setting.instructionsForPatients.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              setting.instructionsForPatients,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClosedAppointmentTypeBox extends StatelessWidget {
  const _ClosedAppointmentTypeBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFECACA),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.event_busy_rounded,
            color: Color(0xFFDC2626),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No appointment type is currently available for this RHU.',
              style: TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.userEmail,
  });

  final String userEmail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.18),
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
              Icons.event_available_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Apply Appointment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose an RHU service and add patient details. Birth certificate is required only for online consultation.',
                  style: TextStyle(
                    color: Color(0xFFDBEAFE),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  userEmail,
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

class _SelectedRhuNote extends StatelessWidget {
  const _SelectedRhuNote({
    required this.rhu,
  });

  final _RhuOption rhu;

  @override
  Widget build(BuildContext context) {
    final String municipality =
        rhu.municipality.trim().isEmpty ? 'Municipality not set' : rhu.municipality;

    final String contact = rhu.contactNumber.trim().isEmpty
        ? 'No contact number listed'
        : rhu.contactNumber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${rhu.name}\n$municipality\n$contact',
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
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
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmationBox extends StatelessWidget {
  const _ConfirmationBox({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: value ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(
          'I confirm this request is real.',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: const Text(
          'I confirm that the information is correct and I am not submitting spam or fake appointment data.',
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
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 14),
            Expanded(
              child: Text('Loading RHU list...'),
            ),
          ],
        ),
      ),
    );
  }
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