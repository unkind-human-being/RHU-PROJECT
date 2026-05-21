import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/medicine_model.dart';
import '../../data/models/medicine_transaction_model.dart';
import 'medicine_provider.dart';

class MedicineTransactionHistoryScreen extends StatefulWidget {
  const MedicineTransactionHistoryScreen({super.key});

  static const String routeName = '/medicine-transactions';

  @override
  State<MedicineTransactionHistoryScreen> createState() =>
      _MedicineTransactionHistoryScreenState();
}

class _MedicineTransactionHistoryScreenState
    extends State<MedicineTransactionHistoryScreen> {
  MedicineModel? _medicine;
  String? _transactionTypeFilter;
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoad) {
      return;
    }

    _didLoad = true;

    final Object? arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is MedicineTransactionHistoryArguments) {
      _medicine = arguments.medicine;
    } else if (arguments is MedicineModel) {
      _medicine = arguments;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
    });
  }

  Future<void> _loadTransactions() {
    return context.read<MedicineProvider>().loadTransactions(
          medicineId: _medicine?.id,
          transactionType: _transactionTypeFilter,
          refresh: true,
        );
  }

  Future<void> _setFilter(String? value) async {
    setState(() {
      _transactionTypeFilter = value;
    });

    await _loadTransactions();
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
              'Transaction History',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh',
                onPressed: provider.isLoading ? null : _loadTransactions,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadTransactions,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  _HistoryHeader(
                    medicine: _medicine,
                    totalTransactions: provider.transactions.length,
                  ),
                  const SizedBox(height: 18),
                  _TransactionFilterBar(
                    selectedValue: _transactionTypeFilter,
                    onChanged: _setFilter,
                  ),
                  const SizedBox(height: 18),
                  if (provider.errorMessage != null)
                    _ErrorCard(
                      message: provider.errorMessage!,
                      onRetry: _loadTransactions,
                    )
                  else if (provider.isLoading)
                    const _LoadingTransactionsCard()
                  else if (!provider.hasTransactions)
                    _EmptyTransactionsCard(
                      medicine: _medicine,
                    )
                  else
                    ...provider.transactions.map(
                      (MedicineTransactionModel transaction) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TransactionCard(
                            transaction: transaction,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class MedicineTransactionHistoryArguments {
  const MedicineTransactionHistoryArguments({
    this.medicine,
  });

  final MedicineModel? medicine;
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.medicine,
    required this.totalTransactions,
  });

  final MedicineModel? medicine;
  final int totalTransactions;

  @override
  Widget build(BuildContext context) {
    final String title = medicine == null
        ? 'All Medicine Transactions'
        : '${medicine!.displayName} History';

    final String subtitle = medicine == null
        ? 'View received, dispensed, and adjusted medicine records.'
        : 'Current stock: ${medicine!.currentStock} ${medicine!.unit}';

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
              Icons.history_rounded,
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
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFE0F2F1),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$totalTransactions record/s loaded',
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

class _TransactionFilterBar extends StatelessWidget {
  const _TransactionFilterBar({
    required this.selectedValue,
    required this.onChanged,
  });

  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedValue ?? 'all',
      decoration: const InputDecoration(
        labelText: 'Transaction type',
        prefixIcon: Icon(Icons.filter_list_rounded),
      ),
      items: const <DropdownMenuItem<String>>[
        DropdownMenuItem<String>(
          value: 'all',
          child: Text('All transaction types'),
        ),
        DropdownMenuItem<String>(
          value: 'received',
          child: Text('Received'),
        ),
        DropdownMenuItem<String>(
          value: 'dispensed',
          child: Text('Dispensed'),
        ),
        DropdownMenuItem<String>(
          value: 'adjusted',
          child: Text('Adjusted'),
        ),
      ],
      onChanged: (String? value) {
        if (value == null || value == 'all') {
          onChanged(null);
          return;
        }

        onChanged(value);
      },
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
  });

  final MedicineTransactionModel transaction;

  Color get _typeColor {
    if (transaction.isReceived) {
      return const Color(0xFF16A34A);
    }

    if (transaction.isDispensed) {
      return const Color(0xFFDC2626);
    }

    return const Color(0xFFF59E0B);
  }

  Color get _typeBackground {
    if (transaction.isReceived) {
      return const Color(0xFFDCFCE7);
    }

    if (transaction.isDispensed) {
      return const Color(0xFFFEF2F2);
    }

    return const Color(0xFFFFFBEB);
  }

  IconData get _typeIcon {
    if (transaction.isReceived) {
      return Icons.call_received_rounded;
    }

    if (transaction.isDispensed) {
      return Icons.outbox_rounded;
    }

    return Icons.tune_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
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
                    color: _typeBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _typeIcon,
                    color: _typeColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        transaction.medicineName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(transaction.transactionDate),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _TypeBadge(
                  label: transaction.transactionTypeLabel,
                  color: _typeColor,
                  background: _typeBackground,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TransactionMetric(
                    label: 'Movement',
                    value: transaction.stockMovementLabel,
                    valueColor: _typeColor,
                  ),
                ),
                Expanded(
                  child: _TransactionMetric(
                    label: 'Previous',
                    value: transaction.previousStock.toString(),
                  ),
                ),
                Expanded(
                  child: _TransactionMetric(
                    label: 'New Stock',
                    value: transaction.newStock.toString(),
                  ),
                ),
              ],
            ),
            if (transaction.reason.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              _InfoLine(
                icon: Icons.description_rounded,
                text: transaction.reason,
              ),
            ],
            if (transaction.source.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.location_city_rounded,
                text: transaction.source,
              ),
            ],
            if (transaction.recordedByName != null &&
                transaction.recordedByName!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.person_rounded,
                text: 'Recorded by ${transaction.recordedByName}',
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.sync_rounded,
                  color: Color(0xFF6B7280),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  transaction.syncStatus.trim().isEmpty
                      ? 'Sync status: N/A'
                      : 'Sync status: ${transaction.syncStatus}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'No date';
    }

    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
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
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TransactionMetric extends StatelessWidget {
  const _TransactionMetric({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF111827),
  });

  final String label;
  final String value;
  final Color valueColor;

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
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          color: const Color(0xFF6B7280),
          size: 17,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
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
              'Unable to load history',
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

class _EmptyTransactionsCard extends StatelessWidget {
  const _EmptyTransactionsCard({
    required this.medicine,
  });

  final MedicineModel? medicine;

  @override
  Widget build(BuildContext context) {
    final String message = medicine == null
        ? 'No medicine transactions have been recorded yet.'
        : 'No transactions found for ${medicine!.displayName}.';

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
                Icons.history_toggle_off_rounded,
                color: Color(0xFF0F766E),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No transaction history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingTransactionsCard extends StatelessWidget {
  const _LoadingTransactionsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(22),
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
              child: Text('Loading transaction history...'),
            ),
          ],
        ),
      ),
    );
  }
}