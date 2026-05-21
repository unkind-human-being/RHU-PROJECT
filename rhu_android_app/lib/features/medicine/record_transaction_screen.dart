import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/medicine_model.dart';
import 'medicine_provider.dart';

class RecordTransactionScreen extends StatefulWidget {
  const RecordTransactionScreen({super.key});

  static const String routeName = '/record-transaction';

  @override
  State<RecordTransactionScreen> createState() =>
      _RecordTransactionScreenState();
}

class _RecordTransactionScreenState extends State<RecordTransactionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _patientReferenceController =
      TextEditingController();
  final TextEditingController _sourceController = TextEditingController(
    text: 'RHU Mobile App',
  );

  String? _selectedMedicineId;
  String _transactionType = 'dispensed';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final MedicineProvider provider = context.read<MedicineProvider>();

      if (!provider.hasMedicines) {
        await provider.loadMedicines();
      }

      if (!mounted) {
        return;
      }

      if (provider.medicines.isNotEmpty && _selectedMedicineId == null) {
        setState(() {
          _selectedMedicineId = provider.medicines.first.id;
        });
      }
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _remarksController.dispose();
    _patientReferenceController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  MedicineModel? _selectedMedicine(MedicineProvider provider) {
    if (provider.medicines.isEmpty) {
      return null;
    }

    final String? selectedId = _selectedMedicineId;

    if (selectedId == null) {
      return provider.medicines.first;
    }

    try {
      return provider.medicines.firstWhere(
        (MedicineModel medicine) => medicine.id == selectedId,
      );
    } catch (_) {
      return provider.medicines.first;
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final MedicineProvider provider = context.read<MedicineProvider>();
    final MedicineModel? medicine = _selectedMedicine(provider);

    if (medicine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a medicine.'),
        ),
      );
      return;
    }

    final int quantity = int.parse(_quantityController.text.trim());
    final int currentStock = provider.effectiveStockFor(medicine);

    if (_transactionType == 'dispensed' && quantity > currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot dispense $quantity ${medicine.unit}. Current stock is only $currentStock ${medicine.unit}.',
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    final bool success = await provider.recordTransaction(
      medicine: medicine,
      transactionType: _transactionType,
      quantity: quantity,
      reason: _reasonController.text,
      remarks: _remarksController.text,
      patientReference: _patientReferenceController.text,
      source: _sourceController.text,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      _quantityController.clear();
      _reasonController.clear();
      _remarksController.clear();
      _patientReferenceController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.successMessage ?? 'Transaction saved successfully.',
          ),
          backgroundColor: provider.lastTransactionWasOffline
              ? const Color(0xFFF59E0B)
              : const Color(0xFF16A34A),
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          provider.errorMessage ?? 'Unable to save transaction.',
        ),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  String get _quantityLabel {
    if (_transactionType == 'adjusted') {
      return 'New stock quantity';
    }

    return 'Quantity';
  }

  String get _quantityHint {
    if (_transactionType == 'received') {
      return 'Example: 20';
    }

    if (_transactionType == 'dispensed') {
      return 'Example: 5';
    }

    return 'Example: 100';
  }

  String get _reasonHint {
    if (_transactionType == 'received') {
      return 'Example: New stock received from RHU office';
    }

    if (_transactionType == 'dispensed') {
      return 'Example: Dispensed to patient';
    }

    return 'Example: Physical count correction';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MedicineProvider>(
      builder: (
        BuildContext context,
        MedicineProvider provider,
        Widget? child,
      ) {
        final MedicineModel? selectedMedicine = _selectedMedicine(provider);
        final String? selectedMedicineId = selectedMedicine?.id;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Record Transaction',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh medicines',
                onPressed: provider.isLoading
                    ? null
                    : () => provider.loadMedicines(refresh: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                const _TransactionHeader(),
                const SizedBox(height: 18),
                if (provider.isLoading && !provider.hasMedicines)
                  const _LoadingCard()
                else if (!provider.hasMedicines)
                  _NoMedicineCard(
                    onRefresh: () => provider.loadMedicines(refresh: true),
                  )
                else
                  Form(
                    key: _formKey,
                    child: Column(
                      children: <Widget>[
                        _MedicinePickerCard(
                          medicines: provider.medicines,
                          selectedMedicineId: selectedMedicineId,
                          stockResolver: provider.effectiveStockFor,
                          onChanged: (String? value) {
                            setState(() {
                              _selectedMedicineId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        if (selectedMedicine != null)
                          _SelectedMedicineStockCard(
                            medicine: selectedMedicine,
                            currentStock:
                                provider.effectiveStockFor(selectedMedicine),
                          ),
                        const SizedBox(height: 14),
                        _TransactionTypeCard(
                          selectedType: _transactionType,
                          onChanged: (String value) {
                            setState(() {
                              _transactionType = value;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        _FormCard(
                          children: <Widget>[
                            TextFormField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: _quantityLabel,
                                hintText: _quantityHint,
                                prefixIcon:
                                    const Icon(Icons.numbers_rounded),
                              ),
                              validator: (String? value) {
                                final String text = value?.trim() ?? '';

                                if (text.isEmpty) {
                                  return 'Quantity is required.';
                                }

                                final int? quantity = int.tryParse(text);

                                if (quantity == null) {
                                  return 'Enter a valid number.';
                                }

                                if (quantity <= 0) {
                                  return 'Quantity must be greater than zero.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _reasonController,
                              minLines: 2,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Reason',
                                hintText: _reasonHint,
                                prefixIcon:
                                    const Icon(Icons.description_rounded),
                              ),
                              validator: (String? value) {
                                final String text = value?.trim() ?? '';

                                if (text.isEmpty) {
                                  return 'Reason is required.';
                                }

                                if (text.length < 4) {
                                  return 'Reason is too short.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _patientReferenceController,
                              decoration: const InputDecoration(
                                labelText: 'Patient reference optional',
                                hintText: 'Example: PATIENT-001',
                                prefixIcon: Icon(Icons.person_rounded),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _sourceController,
                              decoration: const InputDecoration(
                                labelText: 'Source',
                                hintText:
                                    'Example: Poblacion Barangay Health Station',
                                prefixIcon: Icon(Icons.location_city_rounded),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _remarksController,
                              minLines: 2,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Remarks optional',
                                hintText: 'Additional notes',
                                prefixIcon: Icon(Icons.notes_rounded),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: provider.isRecordingTransaction
                                ? null
                                : _submit,
                            icon: provider.isRecordingTransaction
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
                              provider.isRecordingTransaction
                                  ? 'Saving Transaction...'
                                  : 'Save Transaction',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: provider.isRecordingTransaction
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                },
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back to Dashboard'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TransactionHeader extends StatelessWidget {
  const _TransactionHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
            Icons.add_task_rounded,
            color: Colors.white,
            size: 34,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Medicine Movement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Save one transaction. The app will record it online or keep it pending offline automatically.',
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

class _MedicinePickerCard extends StatelessWidget {
  const _MedicinePickerCard({
    required this.medicines,
    required this.selectedMedicineId,
    required this.stockResolver,
    required this.onChanged,
  });

  final List<MedicineModel> medicines;
  final String? selectedMedicineId;
  final int Function(MedicineModel medicine) stockResolver;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      children: <Widget>[
        DropdownButtonFormField<String>(
          value: selectedMedicineId,
          decoration: const InputDecoration(
            labelText: 'Select medicine',
            prefixIcon: Icon(Icons.medication_rounded),
          ),
          items: medicines.map((MedicineModel medicine) {
            final int currentStock = stockResolver(medicine);

            return DropdownMenuItem<String>(
              value: medicine.id,
              child: Text(
                '${medicine.displayName} ($currentStock ${medicine.unit})',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: (String? value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please select a medicine.';
            }

            return null;
          },
        ),
      ],
    );
  }
}

class _SelectedMedicineStockCard extends StatelessWidget {
  const _SelectedMedicineStockCard({
    required this.medicine,
    required this.currentStock,
  });

  final MedicineModel medicine;
  final int currentStock;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = currentStock <= 0
        ? const Color(0xFFDC2626)
        : currentStock <= medicine.minimumStockLevel
            ? const Color(0xFFF59E0B)
            : const Color(0xFF16A34A);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                color: Color(0xFF0F766E),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    medicine.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    medicine.locationName,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '$currentStock',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  medicine.unit,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTypeCard extends StatelessWidget {
  const _TransactionTypeCard({
    required this.selectedType,
    required this.onChanged,
  });

  final String selectedType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      children: <Widget>[
        Text(
          'Transaction Type',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _TypeOption(
          title: 'Received',
          subtitle: 'Add new stock to current inventory',
          icon: Icons.call_received_rounded,
          value: 'received',
          selectedValue: selectedType,
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
        _TypeOption(
          title: 'Dispensed',
          subtitle: 'Reduce stock after medicine is given out',
          icon: Icons.outbox_rounded,
          value: 'dispensed',
          selectedValue: selectedType,
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
        _TypeOption(
          title: 'Adjusted',
          subtitle: 'Set stock based on actual physical count',
          icon: Icons.tune_rounded,
          value: 'adjusted',
          selectedValue: selectedType,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.selectedValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = value == selectedValue;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F2F1) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F766E)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              color: const Color(0xFF0F766E),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: selectedValue,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _NoMedicineCard extends StatelessWidget {
  const _NoMedicineCard({
    required this.onRefresh,
  });

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF0F766E),
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              'No medicines available',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Open Medicine Inventory online first so the app can save a local copy for offline use.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reload Medicines'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(
              child: Text('Loading medicine records...'),
            ),
          ],
        ),
      ),
    );
  }
}