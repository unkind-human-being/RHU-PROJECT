import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';
import '../../data/repositories/medicine_repository.dart';
import '../auth/auth_provider.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  static const String routeName = '/add-medicine';

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _currentStockController =
      TextEditingController(text: '100');

  final TextEditingController _minimumStockController =
      TextEditingController(text: '20');

  final TextEditingController _maximumStockController =
      TextEditingController(text: '500');

  final MedicineRepository _medicineRepository = MedicineRepository();

  late final ApiClient _apiClient;

  bool _isLoadingOptions = false;
  bool _isSaving = false;

  String? _selectedRhuId;
  String? _selectedBarangayId;

  _MedicinePreset _selectedMedicine = _medicinePresets.first;

  String _selectedBatchNumber = '';
  String _supplier = 'DOH Supply';
  String _remarks = 'Initial stock';

  DateTime _expirationDate = DateTime.now().add(const Duration(days: 365));

  List<_RhuOption> _rhus = <_RhuOption>[];
  List<_BarangayOption> _barangays = <_BarangayOption>[];
  List<String> _batchNumbers = <String>[];

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    _batchNumbers = _buildBatchNumbers();

    if (_batchNumbers.isNotEmpty) {
      _selectedBatchNumber = _batchNumbers.first;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRhuAndBarangayOptions();
    });
  }

  @override
  void dispose() {
    _currentStockController.dispose();
    _minimumStockController.dispose();
    _maximumStockController.dispose();
    _apiClient.close();
    super.dispose();
  }

  bool get _isIphoAdmin {
    final String role = context.read<AuthProvider>().user?.role ?? '';
    return role == 'ipho_admin';
  }

  bool get _isHealthWorker {
    final String role = context.read<AuthProvider>().user?.role ?? '';
    return role == 'barangay_health_worker';
  }

  List<_RhuOption> get _visibleRhus {
    final AuthProvider authProvider = context.read<AuthProvider>();
    final String? assignedRhuId = authProvider.user?.rhuId;

    if (_isIphoAdmin) {
      return _rhus;
    }

    if (assignedRhuId == null || assignedRhuId.trim().isEmpty) {
      return _rhus;
    }

    final List<_RhuOption> assignedOnly = _rhus.where(
      (_RhuOption rhu) {
        return rhu.id == assignedRhuId;
      },
    ).toList();

    if (assignedOnly.isNotEmpty) {
      return assignedOnly;
    }

    return <_RhuOption>[
      _RhuOption(
        id: assignedRhuId,
        name: authProvider.assignedLocation,
      ),
    ];
  }

  List<_BarangayOption> get _barangaysForSelectedRhu {
    final AuthProvider authProvider = context.read<AuthProvider>();
    final String? assignedBarangayId = authProvider.user?.barangayId;

    if (_selectedRhuId == null || _selectedRhuId!.trim().isEmpty) {
      return <_BarangayOption>[];
    }

    List<_BarangayOption> filtered = _barangays.where(
      (_BarangayOption barangay) {
        return barangay.rhuId == _selectedRhuId;
      },
    ).toList();

    if (_isHealthWorker &&
        assignedBarangayId != null &&
        assignedBarangayId.trim().isNotEmpty) {
      filtered = filtered.where(
        (_BarangayOption barangay) {
          return barangay.id == assignedBarangayId;
        },
      ).toList();

      if (filtered.isEmpty) {
        return <_BarangayOption>[
          _BarangayOption(
            id: assignedBarangayId,
            name: 'Assigned Barangay',
            rhuId: _selectedRhuId!,
          ),
        ];
      }
    }

    filtered.sort(
      (_BarangayOption a, _BarangayOption b) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      },
    );

    return filtered;
  }

  Future<void> _loadRhuAndBarangayOptions() async {
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

      final List<dynamic> rawBarangays = _extractList(
        await _apiClient.get(
          '/api/barangays',
          requiresAuth: true,
        ),
      );

      final List<_RhuOption> rhus = rawRhus
          .whereType<Map<String, dynamic>>()
          .map(_RhuOption.fromJson)
          .where((_RhuOption rhu) => rhu.id.trim().isNotEmpty)
          .toList();

      final List<_BarangayOption> barangays = rawBarangays
          .whereType<Map<String, dynamic>>()
          .map(_BarangayOption.fromJson)
          .where((_BarangayOption barangay) {
        return barangay.id.trim().isNotEmpty &&
            barangay.rhuId.trim().isNotEmpty;
      }).toList();

      final AuthProvider authProvider = context.read<AuthProvider>();

      String? selectedRhuId = _selectedRhuId;
      String? selectedBarangayId = _selectedBarangayId;

      final String? assignedRhuId = authProvider.user?.rhuId;
      final String? assignedBarangayId = authProvider.user?.barangayId;

      if (!_isIphoAdmin &&
          assignedRhuId != null &&
          assignedRhuId.trim().isNotEmpty) {
        selectedRhuId = assignedRhuId;
      }

      selectedRhuId ??= rhus.isNotEmpty ? rhus.first.id : assignedRhuId;

      if (_isHealthWorker &&
          assignedBarangayId != null &&
          assignedBarangayId.trim().isNotEmpty) {
        selectedBarangayId = assignedBarangayId;
      }

      if (selectedBarangayId == null || selectedBarangayId.trim().isEmpty) {
        final List<_BarangayOption> filtered = barangays.where(
          (_BarangayOption barangay) {
            return barangay.rhuId == selectedRhuId;
          },
        ).toList();

        if (filtered.isNotEmpty) {
          filtered.sort(
            (_BarangayOption a, _BarangayOption b) {
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            },
          );

          selectedBarangayId = filtered.first.id;
        }
      }

      setState(() {
        _rhus = rhus;
        _barangays = barangays;
        _selectedRhuId = selectedRhuId;
        _selectedBarangayId = selectedBarangayId;
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

      _showError('Unable to load RHU and barangay list.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOptions = false;
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
      final dynamic barangays = data['barangays'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (rhus is List) {
        return rhus;
      }

      if (barangays is List) {
        return barangays;
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

    final dynamic rhus = response['rhus'];
    final dynamic barangays = response['barangays'];

    if (rhus is List) {
      return rhus;
    }

    if (barangays is List) {
      return barangays;
    }

    return <dynamic>[];
  }

  List<String> _buildBatchNumbers() {
    final DateTime now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');

    return List<String>.generate(
      30,
      (int index) {
        final String number = (index + 1).toString().padLeft(3, '0');
        return 'BATCH-$year-$month-$number';
      },
    );
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  Future<void> _pickExpirationDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _expirationDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 3650),
      ),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _expirationDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });
  }

  int _readInt(TextEditingController controller) {
    return int.tryParse(controller.text.trim()) ?? 0;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRhuId == null || _selectedRhuId!.trim().isEmpty) {
      _showError('Assigned RHU is required.');
      return;
    }

    if (_selectedBarangayId == null || _selectedBarangayId!.trim().isEmpty) {
      _showError('Assigned barangay is required.');
      return;
    }

    final int currentStock = _readInt(_currentStockController);
    final int minimumStock = _readInt(_minimumStockController);
    final int maximumStock = _readInt(_maximumStockController);

    if (maximumStock < minimumStock) {
      _showError('Maximum stock level must be higher than minimum stock level.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _medicineRepository.createMedicine(
        name: _selectedMedicine.name,
        genericName: _selectedMedicine.genericName,
        brandName: _selectedMedicine.brandName,
        dosageForm: _selectedMedicine.dosageForm,
        strength: _selectedMedicine.strength,
        unit: _selectedMedicine.unit,
        category: _selectedMedicine.category,
        rhuId: _selectedRhuId!,
        barangayId: _selectedBarangayId!,
        currentStock: currentStock,
        minimumStockLevel: minimumStock,
        maximumStockLevel: maximumStock,
        batchNumber: _selectedBatchNumber,
        expirationDate: _expirationDate,
        supplier: _supplier,
        remarks: _remarks,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medicine stock record created successfully.'),
          backgroundColor: Color(0xFF16A34A),
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

      _showError('Unable to create medicine stock record.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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

  String? _numberValidator(String? value, String fieldName) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return '$fieldName is required.';
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
    final AuthProvider authProvider = context.watch<AuthProvider>();

    final List<_RhuOption> rhuOptions = _visibleRhus;
    final List<_BarangayOption> barangayOptions = _barangaysForSelectedRhu;

    final bool selectedRhuValid = rhuOptions.any(
      (_RhuOption rhu) {
        return rhu.id == _selectedRhuId;
      },
    );

    final bool selectedBarangayValid = barangayOptions.any(
      (_BarangayOption barangay) {
        return barangay.id == _selectedBarangayId;
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Medicine',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRhuAndBarangayOptions,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _HeaderCard(
                assignedLocation: authProvider.assignedLocation,
              ),
              const SizedBox(height: 18),
              if (_isLoadingOptions)
                const _LoadingOptionsBox()
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: <Widget>[
                          const _InfoBox(
                            message:
                                'RHU and barangay are selected here so the backend receives real MongoDB IDs. Users do not need to type IDs.',
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedRhuValid ? _selectedRhuId : null,
                            decoration: const InputDecoration(
                              labelText: 'Assigned RHU',
                              prefixIcon: Icon(Icons.local_hospital_rounded),
                            ),
                            items: rhuOptions.map((_RhuOption rhu) {
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
                            onChanged: _isSaving || !_isIphoAdmin
                                ? null
                                : (String? value) {
                                    setState(() {
                                      _selectedRhuId = value;

                                      final List<_BarangayOption> filtered =
                                          _barangays.where(
                                        (_BarangayOption barangay) {
                                          return barangay.rhuId == value;
                                        },
                                      ).toList();

                                      _selectedBarangayId = filtered.isEmpty
                                          ? null
                                          : filtered.first.id;
                                    });
                                  },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedBarangayValid
                                ? _selectedBarangayId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Assigned Barangay',
                              prefixIcon: Icon(Icons.location_city_rounded),
                            ),
                            items: barangayOptions.map(
                              (_BarangayOption barangay) {
                                return DropdownMenuItem<String>(
                                  value: barangay.id,
                                  child: Text(
                                    barangay.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ).toList(),
                            validator: (String? value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Assigned barangay is required.';
                              }

                              return null;
                            },
                            onChanged: _isSaving || _isHealthWorker
                                ? null
                                : (String? value) {
                                    setState(() {
                                      _selectedBarangayId = value;
                                    });
                                  },
                          ),
                          if (barangayOptions.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: _WarningBox(
                                message:
                                    'No barangays were found for this RHU. Create barangays first before adding medicine stock.',
                              ),
                            ),
                          const SizedBox(height: 18),
                          const _SectionLabel(title: 'Medicine Details'),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<_MedicinePreset>(
                            isExpanded: true,
                            value: _selectedMedicine,
                            decoration: const InputDecoration(
                              labelText: 'Medicine',
                              prefixIcon: Icon(Icons.medication_rounded),
                            ),
                            items: _medicinePresets.map(
                              (_MedicinePreset medicine) {
                                return DropdownMenuItem<_MedicinePreset>(
                                  value: medicine,
                                  child: Text(
                                    medicine.displayLabel,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ).toList(),
                            onChanged: _isSaving
                                ? null
                                : (_MedicinePreset? value) {
                                    if (value == null) {
                                      return;
                                    }

                                    setState(() {
                                      _selectedMedicine = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 12),
                          _MedicinePreviewCard(medicine: _selectedMedicine),
                          const SizedBox(height: 18),
                          const _SectionLabel(title: 'Stock Levels'),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _currentStockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Current stock',
                              hintText: 'Example: 100',
                              prefixIcon: Icon(Icons.numbers_rounded),
                            ),
                            validator: (String? value) {
                              return _numberValidator(value, 'Current stock');
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _minimumStockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Minimum stock level',
                              hintText: 'Example: 20',
                              prefixIcon: Icon(Icons.trending_down_rounded),
                            ),
                            validator: (String? value) {
                              return _numberValidator(
                                value,
                                'Minimum stock level',
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _maximumStockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Maximum stock level',
                              hintText: 'Example: 500',
                              prefixIcon: Icon(Icons.trending_up_rounded),
                            ),
                            validator: (String? value) {
                              return _numberValidator(
                                value,
                                'Maximum stock level',
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          const _SectionLabel(title: 'Batch Details'),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedBatchNumber,
                            decoration: const InputDecoration(
                              labelText: 'Batch number',
                              prefixIcon: Icon(Icons.qr_code_rounded),
                            ),
                            items: _batchNumbers.map((String batch) {
                              return DropdownMenuItem<String>(
                                value: batch,
                                child: Text(batch),
                              );
                            }).toList(),
                            onChanged: _isSaving
                                ? null
                                : (String? value) {
                                    if (value == null) {
                                      return;
                                    }

                                    setState(() {
                                      _selectedBatchNumber = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 14),
                          _DatePickerTile(
                            title: 'Expiration date',
                            value: _formatDate(_expirationDate),
                            icon: Icons.event_rounded,
                            onTap: _pickExpirationDate,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _supplier,
                            decoration: const InputDecoration(
                              labelText: 'Supplier',
                              prefixIcon: Icon(Icons.local_shipping_rounded),
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'DOH Supply',
                                child: Text('DOH Supply'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'IPHO Supply',
                                child: Text('IPHO Supply'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'RHU Stockroom',
                                child: Text('RHU Stockroom'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'Emergency Procurement',
                                child: Text('Emergency Procurement'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'Donation',
                                child: Text('Donation'),
                              ),
                            ],
                            onChanged: _isSaving
                                ? null
                                : (String? value) {
                                    if (value == null) {
                                      return;
                                    }

                                    setState(() {
                                      _supplier = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _remarks,
                            decoration: const InputDecoration(
                              labelText: 'Remarks',
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'Initial stock',
                                child: Text('Initial stock'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'Stock replenishment',
                                child: Text('Stock replenishment'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'Emergency supply',
                                child: Text('Emergency supply'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'Donation received',
                                child: Text('Donation received'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'Transferred stock',
                                child: Text('Transferred stock'),
                              ),
                            ],
                            onChanged: _isSaving
                                ? null
                                : (String? value) {
                                    if (value == null) {
                                      return;
                                    }

                                    setState(() {
                                      _remarks = value;
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
                  _isSaving ? 'Creating Medicine...' : 'Create Medicine',
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
      ),
    );
  }
}

class _MedicinePreset {
  const _MedicinePreset({
    required this.name,
    required this.genericName,
    required this.brandName,
    required this.dosageForm,
    required this.strength,
    required this.unit,
    required this.category,
  });

  final String name;
  final String genericName;
  final String brandName;
  final String dosageForm;
  final String strength;
  final String unit;
  final String category;

  String get displayLabel {
    return '$name • $strength • $category';
  }
}

const List<_MedicinePreset> _medicinePresets = <_MedicinePreset>[
  _MedicinePreset(
    name: 'Paracetamol',
    genericName: 'Paracetamol',
    brandName: 'Generic',
    dosageForm: 'tablet',
    strength: '500mg',
    unit: 'pcs',
    category: 'Pain reliever',
  ),
  _MedicinePreset(
    name: 'Ibuprofen',
    genericName: 'Ibuprofen',
    brandName: 'Generic',
    dosageForm: 'tablet',
    strength: '200mg',
    unit: 'pcs',
    category: 'Pain reliever',
  ),
  _MedicinePreset(
    name: 'Amoxicillin',
    genericName: 'Amoxicillin',
    brandName: 'Generic',
    dosageForm: 'capsule',
    strength: '500mg',
    unit: 'pcs',
    category: 'Antibiotic',
  ),
  _MedicinePreset(
    name: 'Cetirizine',
    genericName: 'Cetirizine',
    brandName: 'Generic',
    dosageForm: 'tablet',
    strength: '10mg',
    unit: 'pcs',
    category: 'Antihistamine',
  ),
  _MedicinePreset(
    name: 'Loperamide',
    genericName: 'Loperamide',
    brandName: 'Generic',
    dosageForm: 'capsule',
    strength: '2mg',
    unit: 'pcs',
    category: 'Antidiarrheal',
  ),
  _MedicinePreset(
    name: 'Oral Rehydration Salts',
    genericName: 'ORS',
    brandName: 'Generic',
    dosageForm: 'other',
    strength: '1 sachet',
    unit: 'pack',
    category: 'Electrolyte',
  ),
  _MedicinePreset(
    name: 'Amlodipine',
    genericName: 'Amlodipine',
    brandName: 'Generic',
    dosageForm: 'tablet',
    strength: '5mg',
    unit: 'pcs',
    category: 'Antihypertensive',
  ),
  _MedicinePreset(
    name: 'Losartan',
    genericName: 'Losartan',
    brandName: 'Generic',
    dosageForm: 'tablet',
    strength: '50mg',
    unit: 'pcs',
    category: 'Antihypertensive',
  ),
  _MedicinePreset(
    name: 'Metformin',
    genericName: 'Metformin',
    brandName: 'Generic',
    dosageForm: 'tablet',
    strength: '500mg',
    unit: 'pcs',
    category: 'Diabetes medicine',
  ),
  _MedicinePreset(
    name: 'Salbutamol',
    genericName: 'Salbutamol',
    brandName: 'Generic',
    dosageForm: 'syrup',
    strength: '2mg/5mL',
    unit: 'bottle',
    category: 'Respiratory medicine',
  ),
  _MedicinePreset(
    name: 'Mefenamic Acid',
    genericName: 'Mefenamic Acid',
    brandName: 'Generic',
    dosageForm: 'capsule',
    strength: '500mg',
    unit: 'pcs',
    category: 'Pain reliever',
  ),
  _MedicinePreset(
    name: 'Vitamin C',
    genericName: 'Ascorbic Acid',
    brandName: 'Generic',
    dosageForm: 'tablet',
    strength: '500mg',
    unit: 'pcs',
    category: 'Vitamin',
  ),
];

class _RhuOption {
  const _RhuOption({
    required this.id,
    required this.name,
  });

  factory _RhuOption.fromJson(Map<String, dynamic> json) {
    return _RhuOption(
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
          'rhuName',
          'officeName',
        ],
      ),
    );
  }

  final String id;
  final String name;
}

class _BarangayOption {
  const _BarangayOption({
    required this.id,
    required this.name,
    required this.rhuId,
  });

  factory _BarangayOption.fromJson(Map<String, dynamic> json) {
    return _BarangayOption(
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
          'barangayName',
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
    );
  }

  final String id;
  final String name;
  final String rhuId;
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
              Icons.medication_liquid_rounded,
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
                  'Add Medicine Stock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select RHU, barangay, medicine, and batch details without typing database IDs.',
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

class _MedicinePreviewCard extends StatelessWidget {
  const _MedicinePreviewCard({
    required this.medicine,
  });

  final _MedicinePreset medicine;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: <Widget>[
          _PreviewLine(label: 'Medicine name', value: medicine.name),
          _PreviewLine(label: 'Generic name', value: medicine.genericName),
          _PreviewLine(label: 'Brand name', value: medicine.brandName),
          _PreviewLine(label: 'Dosage form', value: medicine.dosageForm),
          _PreviewLine(label: 'Strength', value: medicine.strength),
          _PreviewLine(label: 'Unit', value: medicine.unit),
          _PreviewLine(label: 'Category', value: medicine.category),
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w900,
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
              child: Text('Loading RHU and barangay list...'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.message,
  });

  final String message;

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
              message,
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
