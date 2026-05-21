import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';
import '../auth/auth_provider.dart';

class CreateHealthWorkerScreen extends StatefulWidget {
  const CreateHealthWorkerScreen({super.key});

  static const String routeName = '/create-health-worker';

  @override
  State<CreateHealthWorkerScreen> createState() =>
      _CreateHealthWorkerScreenState();
}

class _CreateHealthWorkerScreenState extends State<CreateHealthWorkerScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  late final ApiClient _apiClient;

  bool _isSaving = false;
  bool _isLoadingOptions = false;
  bool _passwordVisible = false;
  bool _usePhoneAsPublicRhuContact = true;

  String _selectedRole = 'barangay_health_worker';
  String? _selectedRhuId;
  int? _selectedBarangayNumber;

  List<_RhuOption> _rhus = <_RhuOption>[];
  List<_BarangayRecord> _barangayRecords = <_BarangayRecord>[];
  Set<String> _occupiedBarangayIds = <String>{};
  Set<int> _occupiedBarangayNumbers = <int>{};
  Set<String> _occupiedRhuAdminRhuIds = <String>{};

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _normalizeSelectedRoleForLoggedInUser();
      _loadOptions();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _apiClient.close();
    super.dispose();
  }

  bool get _isRhuAdminAccount {
    return _selectedRole == 'rhu_admin';
  }

  bool get _isHealthWorkerAccount {
    return _selectedRole == 'barangay_health_worker';
  }

  bool get _isPharmacistAccount {
    return _selectedRole == 'pharmacist';
  }

  bool get _needsBarangay {
    return _isHealthWorkerAccount;
  }

  bool get _loggedInIsRhuAdmin {
    final String role = context.read<AuthProvider>().user?.role ?? '';
    return role == 'rhu_admin';
  }

  String get _roleLabel {
    if (_isRhuAdminAccount) {
      return 'RHU Admin';
    }

    if (_isPharmacistAccount) {
      return 'Pharmacist';
    }

    return 'Barangay Health Worker';
  }

  String get _position {
    if (_isRhuAdminAccount) {
      return 'RHU Admin';
    }

    if (_isPharmacistAccount) {
      return 'Pharmacist';
    }

    return 'Barangay Health Worker';
  }

  List<_AccountRoleOption> get _availableAccountTypes {
    if (_loggedInIsRhuAdmin) {
      return const <_AccountRoleOption>[
        _AccountRoleOption(
          value: 'barangay_health_worker',
          label: 'Barangay Health Worker',
        ),
        _AccountRoleOption(
          value: 'pharmacist',
          label: 'Pharmacist',
        ),
      ];
    }

    return const <_AccountRoleOption>[
      _AccountRoleOption(
        value: 'rhu_admin',
        label: 'RHU Admin',
      ),
      _AccountRoleOption(
        value: 'barangay_health_worker',
        label: 'Barangay Health Worker',
      ),
      _AccountRoleOption(
        value: 'pharmacist',
        label: 'Pharmacist',
      ),
    ];
  }

  _RhuOption? get _selectedRhu {
    final String? rhuId = _selectedRhuId;

    if (rhuId == null || rhuId.trim().isEmpty) {
      return null;
    }

    for (final _RhuOption rhu in _rhus) {
      if (rhu.id == rhuId) {
        return rhu;
      }
    }

    return null;
  }

  List<_RhuOption> get _availableRhusForCurrentRole {
    final AuthProvider authProvider = context.read<AuthProvider>();
    final String? loggedInRhuId = authProvider.user?.rhuId;

    List<_RhuOption> baseRhus = _rhus;

    if (_loggedInIsRhuAdmin &&
        loggedInRhuId != null &&
        loggedInRhuId.trim().isNotEmpty) {
      final List<_RhuOption> assignedOnly = _rhus.where((_RhuOption rhu) {
        return rhu.id == loggedInRhuId;
      }).toList();

      if (assignedOnly.isNotEmpty) {
        baseRhus = assignedOnly;
      } else {
        baseRhus = <_RhuOption>[
          _RhuOption(
            id: loggedInRhuId,
            name: authProvider.assignedLocation,
            municipality: authProvider.assignedLocation,
            code: '',
          ),
        ];
      }
    }

    if (!_isRhuAdminAccount) {
      return baseRhus;
    }

    return baseRhus.where((_RhuOption rhu) {
      return !_occupiedRhuAdminRhuIds.contains(rhu.id);
    }).toList();
  }

  int get _barangayCountForSelectedRhu {
    final _RhuOption? rhu = _selectedRhu;

    if (rhu == null) {
      return 0;
    }

    return _barangayCountForRhuName(rhu.name);
  }

  List<int> get _availableBarangayNumbers {
    final int count = _barangayCountForSelectedRhu;

    if (!_needsBarangay || count <= 0) {
      return <int>[];
    }

    final List<int> numbers = <int>[];

    for (int number = 1; number <= count; number++) {
      if (!_occupiedBarangayNumbers.contains(number)) {
        numbers.add(number);
      }
    }

    return numbers;
  }

  String get _selectedRhuName {
    return _selectedRhu?.name ?? 'No RHU selected';
  }

  String get _selectedBarangayName {
    if (_isRhuAdminAccount) {
      return 'Not required for RHU Admin';
    }

    if (_isPharmacistAccount) {
      return 'Not required for Pharmacist';
    }

    final int? number = _selectedBarangayNumber;

    if (number == null) {
      return 'No barangay selected';
    }

    return _barangayDisplayNameForCurrentRhu(number);
  }

  String _barangayDisplayNameForCurrentRhu(int number) {
    final String? selectedRhuId = _selectedRhuId;

    if (selectedRhuId != null && selectedRhuId.trim().isNotEmpty) {
      for (final _BarangayRecord barangay in _barangayRecords) {
        if (barangay.rhuId == selectedRhuId && barangay.number == number) {
          if (barangay.name.trim().isNotEmpty) {
            return barangay.name;
          }
        }
      }
    }

    return _barangayDisplayNameFromRhuName(_selectedRhuName, number);
  }

  void _normalizeSelectedRoleForLoggedInUser() {
    final List<_AccountRoleOption> availableTypes = _availableAccountTypes;

    final bool selectedRoleAllowed = availableTypes.any(
      (_AccountRoleOption option) {
        return option.value == _selectedRole;
      },
    );

    if (!selectedRoleAllowed && availableTypes.isNotEmpty) {
      _selectedRole = availableTypes.first.value;
    }
  }

  Future<void> _loadOptions() async {
    final AuthProvider authProvider = context.read<AuthProvider>();
    final String? assignedRhuId = authProvider.user?.rhuId;
    final bool loggedInIsRhuAdmin = authProvider.user?.role == 'rhu_admin';

    setState(() {
      _isLoadingOptions = true;
    });

    try {
      final List<dynamic> rawRhus = _extractList(
        await _apiClient.get(
          '/api/rhus',
          requiresAuth: true,
        ),
      );

      List<dynamic> rawBarangays = <dynamic>[];

      try {
        rawBarangays = _extractList(
          await _apiClient.get(
            '/api/barangays',
            requiresAuth: true,
          ),
        );
      } catch (_) {
        rawBarangays = <dynamic>[];
      }

      List<dynamic> rawUsers = <dynamic>[];

      try {
        rawUsers = _extractList(
          await _apiClient.get(
            '/api/users',
            requiresAuth: true,
          ),
        );
      } catch (_) {
        rawUsers = <dynamic>[];
      }

      final List<_RhuOption> rhus = rawRhus
          .whereType<Map<String, dynamic>>()
          .map(_RhuOption.fromJson)
          .where((_RhuOption rhu) => rhu.id.trim().isNotEmpty)
          .toList();

      final List<_BarangayRecord> barangayRecords = rawBarangays
          .whereType<Map<String, dynamic>>()
          .map(_BarangayRecord.fromJson)
          .where((_BarangayRecord barangay) {
        return barangay.id.trim().isNotEmpty &&
            barangay.rhuId.trim().isNotEmpty;
      }).toList();

      final Set<String> occupiedRhuAdminRhuIds = <String>{};
      final Set<String> occupiedBarangayIds = <String>{};

      for (final dynamic rawUser in rawUsers) {
        if (rawUser is! Map<String, dynamic>) {
          continue;
        }

        final _UserAssignment user = _UserAssignment.fromJson(rawUser);

        if (user.role == 'rhu_admin' && user.rhuId.trim().isNotEmpty) {
          occupiedRhuAdminRhuIds.add(user.rhuId);
        }

        if (user.role == 'barangay_health_worker' &&
            user.barangayId.trim().isNotEmpty) {
          occupiedBarangayIds.add(user.barangayId);
        }
      }

      String? selectedRhuId = _selectedRhuId;

      if (loggedInIsRhuAdmin &&
          assignedRhuId != null &&
          assignedRhuId.trim().isNotEmpty) {
        selectedRhuId = assignedRhuId;
      }

      selectedRhuId ??= rhus.isNotEmpty ? rhus.first.id : assignedRhuId;

      final Set<int> occupiedNumbers = _occupiedNumbersForRhu(
        selectedRhuId: selectedRhuId,
        barangayRecords: barangayRecords,
        occupiedBarangayIds: occupiedBarangayIds,
      );

      int? selectedBarangayNumber = _selectedBarangayNumber;

      if (_needsBarangay) {
        if (selectedBarangayNumber == null ||
            occupiedNumbers.contains(selectedBarangayNumber)) {
          selectedBarangayNumber = _firstAvailableBarangayNumber(
            selectedRhuId: selectedRhuId,
            occupiedNumbers: occupiedNumbers,
            rhus: rhus,
          );
        }
      } else {
        selectedBarangayNumber = null;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _rhus = rhus;
        _barangayRecords = barangayRecords;
        _occupiedBarangayIds = occupiedBarangayIds;
        _occupiedRhuAdminRhuIds = occupiedRhuAdminRhuIds;
        _selectedRhuId = selectedRhuId;
        _occupiedBarangayNumbers = occupiedNumbers;
        _selectedBarangayNumber = selectedBarangayNumber;
      });

      _normalizeSelectionsAfterLoad();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to load RHU, barangay, or user list.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOptions = false;
        });
      }
    }
  }

  void _normalizeSelectionsAfterLoad() {
    _normalizeSelectedRoleForLoggedInUser();

    final List<_RhuOption> availableRhus = _availableRhusForCurrentRole;

    if (_selectedRhuId == null ||
        !availableRhus.any((_RhuOption rhu) => rhu.id == _selectedRhuId)) {
      _selectedRhuId = availableRhus.isEmpty ? null : availableRhus.first.id;
    }

    _occupiedBarangayNumbers = _occupiedNumbersForCurrentSelection();

    if (!_needsBarangay) {
      _selectedBarangayNumber = null;
      setState(() {});
      return;
    }

    if (_selectedBarangayNumber == null ||
        _occupiedBarangayNumbers.contains(_selectedBarangayNumber)) {
      _selectedBarangayNumber = _firstAvailableBarangayNumber(
        selectedRhuId: _selectedRhuId,
        occupiedNumbers: _occupiedBarangayNumbers,
        rhus: _rhus,
      );
    }

    setState(() {});
  }

  Set<int> _occupiedNumbersForCurrentSelection() {
    return _occupiedNumbersForRhu(
      selectedRhuId: _selectedRhuId,
      barangayRecords: _barangayRecords,
      occupiedBarangayIds: _occupiedBarangayIds,
    );
  }

  Set<int> _occupiedNumbersForRhu({
    required String? selectedRhuId,
    required List<_BarangayRecord> barangayRecords,
    required Set<String> occupiedBarangayIds,
  }) {
    if (selectedRhuId == null || selectedRhuId.trim().isEmpty) {
      return <int>{};
    }

    final Set<int> occupiedNumbers = <int>{};

    for (final String barangayId in occupiedBarangayIds) {
      for (final _BarangayRecord barangay in barangayRecords) {
        if (barangay.id == barangayId && barangay.rhuId == selectedRhuId) {
          if (barangay.number > 0) {
            occupiedNumbers.add(barangay.number);
          }

          break;
        }
      }
    }

    return occupiedNumbers;
  }

  int? _firstAvailableBarangayNumber({
    required String? selectedRhuId,
    required Set<int> occupiedNumbers,
    required List<_RhuOption> rhus,
  }) {
    if (selectedRhuId == null || selectedRhuId.trim().isEmpty) {
      return null;
    }

    _RhuOption? selectedRhu;

    for (final _RhuOption rhu in rhus) {
      if (rhu.id == selectedRhuId) {
        selectedRhu = rhu;
        break;
      }
    }

    if (selectedRhu == null) {
      return null;
    }

    final int count = _barangayCountForRhuName(selectedRhu.name);

    for (int number = 1; number <= count; number++) {
      if (!occupiedNumbers.contains(number)) {
        return number;
      }
    }

    return null;
  }

  List<dynamic> _extractList(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      final dynamic rhus = data['rhus'];
      final dynamic barangays = data['barangays'];
      final dynamic users = data['users'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (rhus is List) return rhus;
      if (barangays is List) return barangays;
      if (users is List) return users;
      if (results is List) return results;
      if (docs is List) return docs;
      if (items is List) return items;
    }

    final dynamic rhus = response['rhus'];
    final dynamic barangays = response['barangays'];
    final dynamic users = response['users'];

    if (rhus is List) return rhus;
    if (barangays is List) return barangays;
    if (users is List) return users;

    return <dynamic>[];
  }

  Future<void> _updateRhuPublicContactIfNeeded() async {
    if (!_isRhuAdminAccount) {
      return;
    }

    if (!_usePhoneAsPublicRhuContact) {
      return;
    }

    final String? rhuId = _selectedRhuId;
    final String phoneNumber = _phoneController.text.trim();

    if (rhuId == null || rhuId.trim().isEmpty) {
      return;
    }

    if (phoneNumber.isEmpty) {
      return;
    }

    await _apiClient.patch(
      '/api/rhus/$rhuId',
      requiresAuth: true,
      body: <String, dynamic>{
        'contactNumber': phoneNumber,
      },
    );
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

    if (_isRhuAdminAccount &&
        _occupiedRhuAdminRhuIds.contains(_selectedRhuId)) {
      _showError('This RHU already has an assigned RHU Admin.');
      return;
    }

    if (_needsBarangay) {
      if (_selectedBarangayNumber == null) {
        _showError('Please select a barangay.');
        return;
      }

      if (_occupiedBarangayNumbers.contains(_selectedBarangayNumber)) {
        _showError(
          'This barangay already has an assigned health worker.',
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? barangayId;

      if (_needsBarangay) {
        barangayId = await _findOrCreateBarangayId(
          rhuId: _selectedRhuId!,
          barangayNumber: _selectedBarangayNumber!,
        );
      }

      final Map<String, dynamic> body = <String, dynamic>{
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'role': _selectedRole,
        'position': _position,
        'rhu': _selectedRhuId,
      };

      if (barangayId != null && barangayId.trim().isNotEmpty) {
        body['barangay'] = barangayId;
      }

      await _apiClient.post(
        _endpointForRole(),
        requiresAuth: true,
        body: body,
      );

      await _updateRhuPublicContactIfNeeded();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_roleLabel account created successfully.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );

      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to create $_roleLabel account.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<String> _findOrCreateBarangayId({
    required String rhuId,
    required int barangayNumber,
  }) async {
    for (final _BarangayRecord barangay in _barangayRecords) {
      if (barangay.rhuId == rhuId && barangay.number == barangayNumber) {
        return barangay.id;
      }
    }

    final _RhuOption? rhu = _selectedRhu;

    if (rhu == null) {
      throw const ApiException(
        message: 'Selected RHU was not found.',
        statusCode: 400,
      );
    }

    final String barangayName = _barangayDisplayNameForCurrentRhu(
      barangayNumber,
    );

    final Map<String, dynamic> response = await _apiClient.post(
      '/api/barangays',
      requiresAuth: true,
      body: <String, dynamic>{
        'name': barangayName,
        'code': '${rhu.safeCode}_barangay_$barangayNumber',
        'rhu': rhu.id,
        'municipality': rhu.municipality,
        'province': 'Tawi-Tawi',
        'address': '$barangayName, ${rhu.municipality}, Tawi-Tawi',
        'contactNumber': _phoneController.text.trim(),
      },
    );

    final Map<String, dynamic> data = _extractMap(response);

    final _BarangayRecord created = _BarangayRecord.fromJson(
      data,
      forcedNumber: barangayNumber,
    );

    if (created.id.trim().isEmpty) {
      throw const ApiException(
        message: 'Barangay was created but no ID was returned.',
        statusCode: 500,
      );
    }

    setState(() {
      _barangayRecords.add(created);
    });

    return created.id;
  }

  Map<String, dynamic> _extractMap(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    final dynamic barangay = response['barangay'];

    if (barangay is Map<String, dynamic>) {
      return barangay;
    }

    return response;
  }

  String _endpointForRole() {
    if (_selectedRole == 'rhu_admin') {
      return '/api/users';
    }

    if (_selectedRole == 'pharmacist') {
      return '/api/users/pharmacist';
    }

    return '/api/users/health-worker';
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

  String? _emailValidator(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Email is required.';
    }

    if (!text.contains('@') || !text.contains('.')) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _passwordValidator(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Password is required.';
    }

    if (text.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = context.watch<AuthProvider>();

    final List<_AccountRoleOption> accountTypes = _availableAccountTypes;
    final List<_RhuOption> rhusForDropdown = _availableRhusForCurrentRole;
    final List<int> barangayNumbers = _availableBarangayNumbers;

    final bool selectedRoleStillAvailable = accountTypes.any(
      (_AccountRoleOption option) {
        return option.value == _selectedRole;
      },
    );

    final bool selectedRhuStillAvailable = rhusForDropdown.any(
      (_RhuOption rhu) {
        return rhu.id == _selectedRhuId;
      },
    );

    final bool selectedBarangayStillAvailable =
        _selectedBarangayNumber != null &&
            barangayNumbers.contains(_selectedBarangayNumber);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Staff Account',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadOptions,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _HeaderCard(
                assignedLocation: authProvider.assignedLocation,
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: <Widget>[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value:
                              selectedRoleStillAvailable ? _selectedRole : null,
                          decoration: const InputDecoration(
                            labelText: 'Account type',
                            prefixIcon: Icon(
                              Icons.admin_panel_settings_rounded,
                            ),
                          ),
                          items: accountTypes.map(
                            (_AccountRoleOption option) {
                              return DropdownMenuItem<String>(
                                value: option.value,
                                child: Text(option.label),
                              );
                            },
                          ).toList(),
                          onChanged: _isSaving
                              ? null
                              : (String? value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _selectedRole = value;

                                    final List<_RhuOption> availableRhus =
                                        _availableRhusForCurrentRole;

                                    if (_selectedRhuId == null ||
                                        !availableRhus.any(
                                          (_RhuOption rhu) {
                                            return rhu.id == _selectedRhuId;
                                          },
                                        )) {
                                      _selectedRhuId = availableRhus.isEmpty
                                          ? null
                                          : availableRhus.first.id;
                                    }

                                    if (_needsBarangay) {
                                      _occupiedBarangayNumbers =
                                          _occupiedNumbersForCurrentSelection();

                                      _selectedBarangayNumber =
                                          _firstAvailableBarangayNumber(
                                        selectedRhuId: _selectedRhuId,
                                        occupiedNumbers:
                                            _occupiedBarangayNumbers,
                                        rhus: _rhus,
                                      );
                                    } else {
                                      _selectedBarangayNumber = null;
                                      _occupiedBarangayNumbers = <int>{};
                                    }
                                  });
                                },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _fullNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            hintText: 'Example: Juan Dela Cruz',
                            prefixIcon: Icon(Icons.person_rounded),
                          ),
                          validator: (String? value) {
                            return _requiredValidator(value, 'Full name');
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            hintText: 'Example: staff@example.com',
                            prefixIcon: Icon(Icons.email_rounded),
                          ),
                          validator: _emailValidator,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_passwordVisible,
                          decoration: InputDecoration(
                            labelText: 'Temporary password',
                            hintText: 'Minimum 8 characters',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                            ),
                          ),
                          validator: _passwordValidator,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone number optional',
                            hintText: 'Example: 09123456789',
                            prefixIcon: Icon(Icons.phone_rounded),
                          ),
                        ),
                        if (_isRhuAdminAccount) ...<Widget>[
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _usePhoneAsPublicRhuContact
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: CheckboxListTile(
                              value: _usePhoneAsPublicRhuContact,
                              onChanged: _isSaving
                                  ? null
                                  : (bool? value) {
                                      setState(() {
                                        _usePhoneAsPublicRhuContact =
                                            value ?? false;
                                      });
                                    },
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                'Use this as public RHU contact number',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: const Text(
                                'This number will appear in the public appointment form.',
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _AssignmentNote(
                          roleLabel: _roleLabel,
                          position: _position,
                          rhuName: _selectedRhuName,
                          barangayName: _selectedBarangayName,
                        ),
                        const SizedBox(height: 14),
                        if (_isLoadingOptions)
                          const _LoadingOptionsBox()
                        else ...<Widget>[
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedRhuStillAvailable
                                ? _selectedRhuId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Assigned RHU',
                              prefixIcon: Icon(Icons.local_hospital_rounded),
                            ),
                            items: rhusForDropdown.map((_RhuOption rhu) {
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
                                return 'Assigned RHU is required.';
                              }

                              return null;
                            },
                            onChanged: _isSaving || _loggedInIsRhuAdmin
                                ? null
                                : (String? value) {
                                    if (value == null) {
                                      return;
                                    }

                                    setState(() {
                                      _selectedRhuId = value;

                                      if (_needsBarangay) {
                                        _occupiedBarangayNumbers =
                                            _occupiedNumbersForCurrentSelection();

                                        _selectedBarangayNumber =
                                            _firstAvailableBarangayNumber(
                                          selectedRhuId: value,
                                          occupiedNumbers:
                                              _occupiedBarangayNumbers,
                                          rhus: _rhus,
                                        );
                                      } else {
                                        _selectedBarangayNumber = null;
                                        _occupiedBarangayNumbers = <int>{};
                                      }
                                    });
                                  },
                          ),
                          if (_isRhuAdminAccount && rhusForDropdown.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: _WarningBox(
                                message:
                                    'All RHUs already have assigned RHU Admin accounts.',
                              ),
                            ),
                          if (_needsBarangay) ...<Widget>[
                            const SizedBox(height: 14),
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: selectedBarangayStillAvailable
                                  ? _selectedBarangayNumber
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Assigned Barangay',
                                prefixIcon: Icon(Icons.location_city_rounded),
                              ),
                              items: barangayNumbers.map((int number) {
                                return DropdownMenuItem<int>(
                                  value: number,
                                  child: Text(
                                    _barangayDisplayNameForCurrentRhu(number),
                                  ),
                                );
                              }).toList(),
                              validator: (int? value) {
                                if (!_needsBarangay) {
                                  return null;
                                }

                                if (value == null) {
                                  return 'Assigned barangay is required.';
                                }

                                return null;
                              },
                              onChanged: _isSaving
                                  ? null
                                  : (int? value) {
                                      setState(() {
                                        _selectedBarangayNumber = value;
                                      });
                                    },
                            ),
                            if (_barangayCountForSelectedRhu == 0)
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: _WarningBox(
                                  message:
                                      'This RHU is not yet matched to a barangay count. Check the RHU name.',
                                ),
                              ),
                            if (_barangayCountForSelectedRhu > 0 &&
                                barangayNumbers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: _WarningBox(
                                  message:
                                      'All barangays under this RHU already have assigned health worker accounts.',
                                ),
                              ),
                          ],
                        ],
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
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: Text(
                  _isSaving ? 'Creating Account...' : 'Create $_roleLabel',
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
      ),
    );
  }
}

class _AccountRoleOption {
  const _AccountRoleOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

class _RhuOption {
  const _RhuOption({
    required this.id,
    required this.name,
    required this.municipality,
    required this.code,
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

    final String municipality = _readString(
      json,
      <String>[
        'municipality',
        'city',
      ],
    );

    final String code = _readString(
      json,
      <String>[
        'code',
        'rhuCode',
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
      municipality: municipality.isEmpty
          ? _municipalityFromRhuName(name)
          : municipality,
      code: code,
    );
  }

  final String id;
  final String name;
  final String municipality;
  final String code;

  String get safeCode {
    if (code.trim().isNotEmpty) {
      return code.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    }

    return municipality.trim().toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '_',
        );
  }
}

class _BarangayRecord {
  const _BarangayRecord({
    required this.id,
    required this.name,
    required this.rhuId,
    required this.number,
  });

  factory _BarangayRecord.fromJson(
    Map<String, dynamic> json, {
    int? forcedNumber,
  }) {
    final String name = _readString(
      json,
      <String>[
        'name',
        'barangayName',
      ],
    );

    return _BarangayRecord(
      id: _readString(
        json,
        <String>[
          '_id',
          'id',
        ],
      ),
      name: name,
      rhuId: _readRelationIdFromKeys(
        json,
        <String>[
          'rhu',
          'rhuId',
          'assignedRhu',
          'assignedRhuId',
        ],
      ),
      number: forcedNumber ?? _numberFromBarangayNameOrFields(json, name),
    );
  }

  final String id;
  final String name;
  final String rhuId;
  final int number;
}

class _UserAssignment {
  const _UserAssignment({
    required this.role,
    required this.rhuId,
    required this.barangayId,
  });

  factory _UserAssignment.fromJson(Map<String, dynamic> json) {
    return _UserAssignment(
      role: _readString(
        json,
        <String>[
          'role',
          'userRole',
        ],
      ),
      rhuId: _readRelationIdFromKeys(
        json,
        <String>[
          'rhu',
          'rhuId',
          'assignedRhu',
          'assignedRhuId',
        ],
      ),
      barangayId: _readRelationIdFromKeys(
        json,
        <String>[
          'barangay',
          'barangayId',
          'assignedBarangay',
          'assignedBarangayId',
        ],
      ),
    );
  }

  final String role;
  final String rhuId;
  final String barangayId;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.assignedLocation,
  });

  final String assignedLocation;

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
              Icons.person_add_alt_1_rounded,
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
                  'Create Staff Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create RHU admin, barangay health worker, or pharmacist accounts without manually typing database IDs.',
                  style: TextStyle(
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

class _AssignmentNote extends StatelessWidget {
  const _AssignmentNote({
    required this.roleLabel,
    required this.position,
    required this.rhuName,
    required this.barangayName,
  });

  final String roleLabel;
  final String position;
  final String rhuName;
  final String barangayName;

  @override
  Widget build(BuildContext context) {
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
              'Account type: $roleLabel\n'
              'Position: $position\n'
              'Assigned RHU: $rhuName\n'
              'Assigned Barangay: $barangayName\n\n'
              'Real barangay names are shown. Database IDs are hidden and sent automatically.',
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingOptionsBox extends StatelessWidget {
  const _LoadingOptionsBox();

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
              child: Text('Loading RHU, barangay, and user list...'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF92400E),
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

String _barangayDisplayNameFromRhuName(String rhuName, int number) {
  final List<String> names = _barangayNamesForRhuName(rhuName);

  if (number > 0 && number <= names.length) {
    return names[number - 1];
  }

  return 'Barangay $number';
}

List<String> _barangayNamesForRhuName(String rhuName) {
  final String text = rhuName.toLowerCase();

  if (text.contains('simunul')) {
    return const <String>[
      'Bagid',
      'Bakong',
      'Boheh Indangan (Tubig Indangan)',
      'Doh-Tong',
      'Maruwa',
      'Mongkay',
      'Pagasinan',
      'Panglima Mastul',
      'Sukah-Bulan',
      'Tampakan (Poblacion)',
      'Tonggusong',
      'Ubol',
      'Timundon',
      'Manuk Mangkaw',
      'Luuk Datan',
    ];
  }

  if (text.contains('languyan')) {
    return const <String>[
      'Bakong',
      'Bas-bas Proper',
      'Basnunuk',
      'Darussalam',
      'Languyan Proper (Poblacion)',
      'Maraning',
      'Simalak',
      'Tuhog-Tuhog',
      'Tumahubong',
      'Tumbagaan',
      'Parang Pantay',
      'Adnin',
      'Bakaw-bakaw',
      'BasLikud',
      'Jakarta (Lookan Latuan)',
      'Kalupag',
      'Kiniktal',
      'Marang-marang',
      'Sikullis',
      'Tubig Dakula (Bohe Mahiya)',
    ];
  }

  if (text.contains('mapun')) {
    return const <String>[
      'Boki',
      'Duhul Batu',
      'Iruk-Iruk',
      'Guppah',
      'Kompang',
      'Liyubud (Poblacion)',
      'Lubbak Parang',
      'Lupa Pula',
      'Mahalu',
      'Pawan',
      'Sapah',
      'Sikub',
      'Tabulian',
      'Tanduan',
      'Umus Mataha',
    ];
  }

  if (text.contains('turtle')) {
    return const <String>[
      'Poblacion',
      'Likud Bakkaw',
    ];
  }

  if (text.contains('sitangkai')) {
    return const <String>[
      'Poblacion',
      'Panglima Alari',
      'Datu Puti',
      'South Larap',
      'Sipangkot',
      'Imam Sapie',
      'Tongmageng',
      'Tungusong',
      'North Larap',
    ];
  }

  if (text.contains('south') && text.contains('ubian')) {
    return const <String>[
      'Babagan',
      'Bengkol',
      'Bintawlan',
      'Bohe',
      'Bubuan',
      'Bunay Bunay Tong',
      'Bunay Bunay Lookan',
      'Bunay Bunay Center',
      'Lahad Dampung',
      'East Talisay',
      'Nunuk',
      'Laitan',
      'Lambi-Lambian',
      'Laud',
      'Likud Tabawan',
      'Nusa-Nusa',
      'Nusa',
      'Pampang',
      'Putat',
      'Sollogan',
      'Talisay',
      'Tampakan Dampong',
      'Tinda-Tindahan',
      'Tong Tampakan',
      'Tubig Dayang Center',
      'Tubig Dayang Riverside',
      'Tubig Dayang',
      'Tukkai',
      'Unas-Unas',
      'Likud Dampong',
      'Tangngah',
    ];
  }

  if (text.contains('sapa')) {
    return const <String>[
      'Baldatal Islam',
      'Butun',
      'Dalo-dalo',
      'Kohec',
      'Lakit-lakit',
      'Latuan',
      'Look Natuh',
      'Lookan Banaran',
      'Lookan Latuan',
      'Malanta',
      'Mantabuan Tabunan',
      'Nunuk Likud Sikubong',
      'Palate Gadjaminah',
      'Pamasan',
      'Sapa-Sapa (Poblacion)',
      'Sapaat',
      'Sukah-sukah',
      'Tabunan Likud Sikubong',
      'Tangngah',
      'Tapian Bohe North',
      'Tapian Bohe South',
      'Tonggusong Banaran',
      'Tup-tup Banaran',
    ];
  }

  if (text.contains('sibutu')) {
    return const <String>[
      'Ambulong Sapal',
      'Datu Amilhamja Jaafar',
      'Hadji Imam Bidin',
      'Hadji Mohtar Sulayman',
      'Hadji Taha',
      'Imam Hadji Mohammad',
      'Ligayan',
      'Nunukan',
      'Sheik Makdum',
      'Sibutu (Poblacion)',
      'Talisay',
      'Tandu Banak',
      'Taungoh',
      'Tongehat',
      'Tongsibalo',
      'Ungus-ungus',
    ];
  }

  if (text.contains('bongao')) {
    return const <String>[
      'Bongao Poblacion (sentro)',
      'Ipil',
      'Kamagong',
      'Karungdong',
      'Lagasan',
      'Lakit Lakit',
      'Lamion',
      'Lapid Lapid',
      'Lato Lato',
      'Luuk Pandan',
      'Luuk Tulay',
      'Malassa',
      'Mandulan',
      'Masantong',
      'Montay Montay',
      'Nalil',
      'Pababag',
      'Pag-asa',
      'Pagasinan',
      'Pagatpat',
      'Pahut',
      'Pakias',
      'Paniongan',
      'Pasiagan',
      'Sanga-sanga',
      'Silubog',
      'Simandagit',
      'Sumangat',
      'Tarawakan',
      'Tongsinah',
      'Tubig Basag',
      'Tubig Tanah',
      'Tubig-Boh',
      'Tubig-Mampallam',
      'Ungus-ungus',
    ];
  }

  if (text.contains('panglima') && text.contains('sugala')) {
    return const <String>[
      'Balimbing Proper',
      'Batu-batu (Bato-Bato / Poblacion)',
      'Bauno Garing',
      'Belatan Halu',
      'Buan',
      'Dungon',
      'Karaha',
      'Kulape',
      'Liyaburan',
      'Luuk Buntal',
      'Magsaggaw',
      'Malacca',
      'Parangan',
      'Sumangday',
      'Tabunan',
      'Tundon',
      'Tungbangkaw',
    ];
  }

  if (text.contains('tandubas')) {
    return const <String>[
      'Baliungan',
      'Ballak',
      'Butun',
      'Himbah',
      'Kakoong',
      'Kalang-kalang',
      'Kepeng',
      'Lahay-lahay',
      'Naungan',
      'Salamat',
      'Sallangan',
      'Sapa',
      'Sibakloon',
      'Silantup',
      'Tandubato',
      'Tangngah',
      'Tapian',
      'Tapian Sukah',
      'Taruk',
      'Tongbangkaw',
    ];
  }

  return const <String>[];
}

int _barangayCountForRhuName(String name) {
  final String text = name.toLowerCase();

  if (text.contains('bongao')) return 35;
  if (text.contains('sibutu')) return 16;
  if (text.contains('panglima') && text.contains('sugala')) return 17;
  if (text.contains('sapa')) return 23;
  if (text.contains('simunul')) return 15;
  if (text.contains('tandubas')) return 20;
  if (text.contains('turtle')) return 2;
  if (text.contains('south') && text.contains('ubian')) return 31;
  if (text.contains('sitangkai')) return 9;
  if (text.contains('languyan')) return 20;
  if (text.contains('mapun')) return 15;

  return 0;
}

String _municipalityFromRhuName(String name) {
  final String text = name.toLowerCase();

  if (text.contains('bongao')) return 'Bongao';
  if (text.contains('sibutu')) return 'Sibutu';
  if (text.contains('panglima') && text.contains('sugala')) {
    return 'Panglima Sugala';
  }
  if (text.contains('sapa')) return 'Sapa-Sapa';
  if (text.contains('simunul')) return 'Simunul';
  if (text.contains('tandubas')) return 'Tandubas';
  if (text.contains('turtle')) return 'Turtle Islands';
  if (text.contains('south') && text.contains('ubian')) return 'South Ubian';
  if (text.contains('sitangkai')) return 'Sitangkai';
  if (text.contains('languyan')) return 'Languyan';
  if (text.contains('mapun')) return 'Mapun';

  return name.replaceAll('Rural Health Unit', '').trim();
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

    final String text = value.toString().trim();

    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }

  return '';
}

int _readInt(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value == null) {
      continue;
    }

    if (value is int) {
      return value;
    }

    final int? parsed = int.tryParse(value.toString());

    if (parsed != null) {
      return parsed;
    }
  }

  return 0;
}

String _readRelationIdFromKeys(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final String key in keys) {
    final dynamic value = json[key];
    final String id = _readRelationId(value);

    if (id.trim().isNotEmpty) {
      return id;
    }
  }

  return '';
}

String _readRelationId(dynamic value) {
  if (value == null) {
    return '';
  }

  if (value is String) {
    return value.trim();
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

int _numberFromBarangayNameOrFields(
  Map<String, dynamic> json,
  String name,
) {
  final int fieldNumber = _readInt(
    json,
    <String>[
      'number',
      'barangayNumber',
      'sortOrder',
      'order',
    ],
  );

  if (fieldNumber > 0) {
    return fieldNumber;
  }

  final String code = _readString(
    json,
    <String>[
      'code',
      'barangayCode',
    ],
  );

  final RegExp codePattern = RegExp(r'barangay_(\d+)$');
  final RegExpMatch? codeMatch = codePattern.firstMatch(code);

  if (codeMatch != null) {
    final int? parsed = int.tryParse(codeMatch.group(1) ?? '');

    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }

  final RegExp numberPattern = RegExp(r'(\d+)');
  final RegExpMatch? match = numberPattern.firstMatch(name);

  if (match != null) {
    final int? parsed = int.tryParse(match.group(1) ?? '');

    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }

  return 0;
}