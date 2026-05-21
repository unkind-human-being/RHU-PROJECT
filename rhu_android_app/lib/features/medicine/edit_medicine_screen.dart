import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/medicine_model.dart';
import '../../data/repositories/medicine_repository.dart';

class EditMedicineArguments {
  const EditMedicineArguments({
    required this.medicine,
  });

  final MedicineModel medicine;
}

class EditMedicineScreen extends StatefulWidget {
  const EditMedicineScreen({
    super.key,
    required this.medicine,
  });

  static const String routeName = '/edit-medicine';

  final MedicineModel medicine;

  @override
  State<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _genericNameController;
  late final TextEditingController _brandNameController;
  late final TextEditingController _strengthController;
  late final TextEditingController _categoryController;
  late final TextEditingController _minimumStockController;
  late final TextEditingController _maximumStockController;
  late final TextEditingController _batchNumberController;
  late final TextEditingController _supplierController;
  late final TextEditingController _remarksController;

  final MedicineRepository _medicineRepository = MedicineRepository();

  late String _dosageForm;
  late String _unit;
  late DateTime _expirationDate;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final dynamic medicine = widget.medicine;

    _nameController = TextEditingController(
      text: _safeText(medicine.name, fallback: widget.medicine.displayName),
    );

    _genericNameController = TextEditingController(
      text: _safeText(medicine.genericName),
    );

    _brandNameController = TextEditingController(
      text: _safeText(medicine.brandName),
    );

    _strengthController = TextEditingController(
      text: _safeText(medicine.strength),
    );

    _categoryController = TextEditingController(
      text: _safeText(medicine.category),
    );

    _minimumStockController = TextEditingController(
      text: widget.medicine.minimumStockLevel.toString(),
    );

    _maximumStockController = TextEditingController(
      text: _readIntDynamic(medicine.maximumStockLevel, fallback: 500).toString(),
    );

    _batchNumberController = TextEditingController(
      text: _safeText(medicine.batchNumber),
    );

    _supplierController = TextEditingController(
      text: _safeText(medicine.supplier),
    );

    _remarksController = TextEditingController(
      text: _safeText(medicine.remarks),
    );

    _dosageForm = _normalizeDropdownValue(
      _safeText(medicine.dosageForm),
      allowedValues: <String>[
        'tablet',
        'capsule',
        'syrup',
        'injection',
        'ointment',
        'drops',
        'other',
      ],
      fallback: 'tablet',
    );

    _unit = _normalizeDropdownValue(
      _safeText(medicine.unit),
      allowedValues: <String>[
        'pcs',
        'box',
        'bottle',
        'vial',
        'pack',
        'tube',
      ],
      fallback: 'pcs',
    );

    _expirationDate = _readDateDynamic(
      medicine.expirationDate,
      fallback: DateTime.now().add(const Duration(days: 365)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genericNameController.dispose();
    _brandNameController.dispose();
    _strengthController.dispose();
    _categoryController.dispose();
    _minimumStockController.dispose();
    _maximumStockController.dispose();
    _batchNumberController.dispose();
    _supplierController.dispose();
    _remarksController.dispose();
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

  String _formatDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  Future<void> _pickExpirationDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _expirationDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
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

    final int minimumStock = _readInt(_minimumStockController);
    final int maximumStock = _readInt(_maximumStockController);

    if (maximumStock < minimumStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maximum stock level must be higher than minimum stock level.',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _medicineRepository.updateMedicine(
        medicineId: widget.medicine.id,
        name: _nameController.text,
        genericName: _genericNameController.text,
        brandName: _brandNameController.text,
        dosageForm: _dosageForm,
        strength: _strengthController.text,
        unit: _unit,
        category: _categoryController.text,
        minimumStockLevel: minimumStock,
        maximumStockLevel: maximumStock,
        batchNumber: _batchNumberController.text,
        expirationDate: _expirationDate,
        supplier: _supplierController.text,
        remarks: _remarksController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medicine updated successfully.'),
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
          content: Text('Unable to update medicine.'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Medicine',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            _HeaderCard(
              medicineName: widget.medicine.displayName,
              currentStock: '${widget.medicine.currentStock} ${widget.medicine.unit}',
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Medicine name',
                          hintText: 'Example: Paracetamol',
                          prefixIcon: Icon(Icons.medication_rounded),
                        ),
                        validator: (String? value) {
                          return _requiredValidator(
                            value,
                            'Medicine name',
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _genericNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Generic name',
                          hintText: 'Example: Paracetamol',
                          prefixIcon: Icon(Icons.science_rounded),
                        ),
                        validator: (String? value) {
                          return _requiredValidator(
                            value,
                            'Generic name',
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _brandNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Brand name',
                          hintText: 'Example: Generic',
                          prefixIcon: Icon(Icons.local_offer_rounded),
                        ),
                        validator: (String? value) {
                          return _requiredValidator(
                            value,
                            'Brand name',
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _dosageForm,
                        decoration: const InputDecoration(
                          labelText: 'Dosage form',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'tablet',
                            child: Text('Tablet'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'capsule',
                            child: Text('Capsule'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'syrup',
                            child: Text('Syrup'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'injection',
                            child: Text('Injection'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'ointment',
                            child: Text('Ointment'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'drops',
                            child: Text('Drops'),
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
                            _dosageForm = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _strengthController,
                        decoration: const InputDecoration(
                          labelText: 'Strength',
                          hintText: 'Example: 500mg',
                          prefixIcon: Icon(Icons.speed_rounded),
                        ),
                        validator: (String? value) {
                          return _requiredValidator(value, 'Strength');
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          prefixIcon: Icon(Icons.inventory_2_rounded),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'pcs',
                            child: Text('Pieces'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'box',
                            child: Text('Box'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'bottle',
                            child: Text('Bottle'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'vial',
                            child: Text('Vial'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'pack',
                            child: Text('Pack'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'tube',
                            child: Text('Tube'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _unit = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _categoryController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          hintText: 'Example: Pain reliever',
                          prefixIcon: Icon(Icons.label_rounded),
                        ),
                        validator: (String? value) {
                          return _requiredValidator(value, 'Category');
                        },
                      ),
                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'Stock Settings'),
                      const SizedBox(height: 8),
                      const _InfoBox(
                        message:
                            'Current stock is changed through Record Transaction only. This keeps the medicine history accurate.',
                      ),
                      const SizedBox(height: 12),
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
                      TextFormField(
                        controller: _batchNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Batch number',
                          hintText: 'Example: BATCH-2026-001',
                          prefixIcon: Icon(Icons.qr_code_rounded),
                        ),
                        validator: (String? value) {
                          return _requiredValidator(value, 'Batch number');
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
                      TextFormField(
                        controller: _supplierController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Supplier',
                          hintText: 'Example: DOH Supply',
                          prefixIcon: Icon(Icons.local_shipping_rounded),
                        ),
                        validator: (String? value) {
                          return _requiredValidator(value, 'Supplier');
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _remarksController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Remarks',
                          hintText: 'Example: Initial stock',
                          prefixIcon: Icon(Icons.notes_rounded),
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
  const _HeaderCard({
    required this.medicineName,
    required this.currentStock,
  });

  final String medicineName;
  final String currentStock;

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
              Icons.edit_rounded,
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
                  'Edit Medicine',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  medicineName,
                  style: const TextStyle(
                    color: Color(0xFFE0F2F1),
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Current stock: $currentStock',
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
