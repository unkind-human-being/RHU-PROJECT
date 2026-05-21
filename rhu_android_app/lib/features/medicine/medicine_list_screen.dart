import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/medicine_model.dart';
import '../../data/repositories/medicine_repository.dart';
import 'edit_medicine_screen.dart';
import 'medicine_provider.dart';
import 'medicine_transaction_history_screen.dart';

class MedicineListScreen extends StatefulWidget {
  const MedicineListScreen({super.key});

  static const String routeName = '/medicines';

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MedicineRepository _medicineRepository = MedicineRepository();

  Timer? _searchDebounce;
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_handleSearchTextState);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MedicineProvider>().loadMedicines();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchTextState);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchTextState() {
    final bool hasText = _searchController.text.trim().isNotEmpty;

    if (_hasSearchText == hasText) {
      return;
    }

    setState(() {
      _hasSearchText = hasText;
    });
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      context.read<MedicineProvider>().searchMedicines(value);
    });
  }

  Future<void> _handleRefresh() {
    return context.read<MedicineProvider>().loadMedicines(refresh: true);
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    await context.read<MedicineProvider>().clearFilters();
  }

  Future<void> _openAddMedicine() async {
    final Object? result = await Navigator.of(context).pushNamed(
      '/add-medicine',
    );

    if (result == true && mounted) {
      await _handleRefresh();
    }
  }

  Future<void> _openEditMedicine(MedicineModel medicine) async {
    final Object? result = await Navigator.of(context).pushNamed(
      EditMedicineScreen.routeName,
      arguments: EditMedicineArguments(
        medicine: medicine,
      ),
    );

    if (result == true && mounted) {
      await _handleRefresh();
    }
  }

  Future<void> _deleteMedicine(MedicineModel medicine) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Medicine?'),
          content: Text(
            'Are you sure you want to delete/deactivate "${medicine.displayName}"?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _medicineRepository.deleteMedicine(medicine.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medicine deleted/deactivated successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      await _handleRefresh();
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
          content: Text('Unable to delete/deactivate medicine.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MedicineProvider>(
      builder: (
        BuildContext context,
        MedicineProvider provider,
        Widget? child,
      ) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Medicine Inventory',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh',
                onPressed: provider.isLoading ? null : _handleRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: provider.isLoading ? null : _openAddMedicine,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Medicine'),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  _InventoryHeader(provider: provider),
                  const SizedBox(height: 18),
                  _SearchAndFilterBar(
                    controller: _searchController,
                    hasSearchText: _hasSearchText,
                    selectedStatus: provider.stockStatusFilter,
                    onChanged: _handleSearchChanged,
                    onStatusChanged: provider.setStockStatusFilter,
                    onClear: _clearFilters,
                  ),
                  const SizedBox(height: 18),
                  if (provider.errorMessage != null)
                    _ErrorCard(
                      message: provider.errorMessage!,
                      onRetry: _handleRefresh,
                    )
                  else if (provider.isLoading)
                    const _MedicineLoadingList()
                  else if (!provider.hasMedicines)
                    const _EmptyMedicineState()
                  else
                    ...provider.medicines.map(
                      (MedicineModel medicine) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MedicineCard(
                            medicine: medicine,
                            onEdit: () => _openEditMedicine(medicine),
                            onDelete: () => _deleteMedicine(medicine),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InventoryHeader extends StatelessWidget {
  const _InventoryHeader({
    required this.provider,
  });

  final MedicineProvider provider;

  @override
  Widget build(BuildContext context) {
    final int alertCount = provider.lowStockCount +
        provider.outOfStockCount +
        provider.expiredCount;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.inventory_2_rounded,
                color: Colors.white,
                size: 28,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Medicine Supply',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Manage medicine records for your assigned area. Use Medicine Monitor to check other barangays.',
            style: TextStyle(
              color: Color(0xFFE0F2F1),
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderMetric(
                  label: 'Items',
                  value: provider.totalMedicines.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Total Stock',
                  value: provider.totalStock.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Alerts',
                  value: alertCount.toString(),
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
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
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

class _SearchAndFilterBar extends StatelessWidget {
  const _SearchAndFilterBar({
    required this.controller,
    required this.hasSearchText,
    required this.selectedStatus,
    required this.onChanged,
    required this.onStatusChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasSearchText;
  final String? selectedStatus;
  final ValueChanged<String> onChanged;
  final ValueChanged<String?> onStatusChanged;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: 'Search medicine',
            hintText: 'Search by name, batch, category...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: hasSearchText
                ? IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: selectedStatus ?? 'all',
          decoration: const InputDecoration(
            labelText: 'Stock status',
            prefixIcon: Icon(Icons.filter_list_rounded),
          ),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(
              value: 'all',
              child: Text('All statuses'),
            ),
            DropdownMenuItem<String>(
              value: 'in_stock',
              child: Text('In Stock'),
            ),
            DropdownMenuItem<String>(
              value: 'low_stock',
              child: Text('Low Stock'),
            ),
            DropdownMenuItem<String>(
              value: 'out_of_stock',
              child: Text('Out of Stock'),
            ),
            DropdownMenuItem<String>(
              value: 'expired',
              child: Text('Expired'),
            ),
          ],
          onChanged: (String? value) {
            if (value == null || value == 'all') {
              onStatusChanged(null);
              return;
            }

            onStatusChanged(value);
          },
        ),
      ],
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.medicine,
    required this.onEdit,
    required this.onDelete,
  });

  final MedicineModel medicine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color get _statusColor {
    if (medicine.isExpired || medicine.isOutOfStock) {
      return const Color(0xFFDC2626);
    }

    if (medicine.isLowStock) {
      return const Color(0xFFF59E0B);
    }

    return const Color(0xFF16A34A);
  }

  Color get _statusBackground {
    if (medicine.isExpired || medicine.isOutOfStock) {
      return const Color(0xFFFEF2F2);
    }

    if (medicine.isLowStock) {
      return const Color(0xFFFFFBEB);
    }

    return const Color(0xFFDCFCE7);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).pushNamed(
            MedicineTransactionHistoryScreen.routeName,
            arguments: MedicineTransactionHistoryArguments(
              medicine: medicine,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.medication_rounded,
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
                          medicine.category.trim().isEmpty
                              ? 'No category'
                              : medicine.category,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _StatusBadge(
                        label: medicine.stockStatusLabel,
                        foreground: _statusColor,
                        background: _statusBackground,
                      ),
                      const SizedBox(height: 4),
                      IconButton(
                        tooltip: 'Edit medicine',
                        onPressed: onEdit,
                        icon: const Icon(
                          Icons.edit_rounded,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete medicine',
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: medicine.stockPercentage,
                  backgroundColor: const Color(0xFFE5E7EB),
                  color: _statusColor,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MedicineInfo(
                      label: 'Current Stock',
                      value: '${medicine.currentStock} ${medicine.unit}',
                    ),
                  ),
                  Expanded(
                    child: _MedicineInfo(
                      label: 'Minimum',
                      value: '${medicine.minimumStockLevel} ${medicine.unit}',
                    ),
                  ),
                  Expanded(
                    child: _MedicineInfo(
                      label: 'Batch',
                      value: medicine.batchNumber.trim().isEmpty
                          ? 'N/A'
                          : medicine.batchNumber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      medicine.locationName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
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
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MedicineInfo extends StatelessWidget {
  const _MedicineInfo({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
              'Unable to load medicines',
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

class _EmptyMedicineState extends StatelessWidget {
  const _EmptyMedicineState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF0F766E),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No medicine records found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'This list only shows medicine records in your assigned management area.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineLoadingList extends StatelessWidget {
  const _MedicineLoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        4,
        (int index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text('Loading medicine records...'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
