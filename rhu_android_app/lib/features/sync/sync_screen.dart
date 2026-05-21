import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/storage/offline_queue_service.dart';
import 'sync_provider.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  static const String routeName = '/sync';

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  SyncProvider? _provider;
  String? _lastShownAutoMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final SyncProvider provider = context.read<SyncProvider>();
      _provider = provider;

      provider.addListener(_handleProviderNotice);
      provider.startAutoSync();

      _loadData();
    });
  }

  @override
  void dispose() {
    ScaffoldMessenger.of(context).clearMaterialBanners();
    _provider?.removeListener(_handleProviderNotice);
    super.dispose();
  }

  void _handleProviderNotice() {
    final SyncProvider? provider = _provider;

    if (provider == null || !mounted) {
      return;
    }

    final String? message = provider.lastAutoSyncMessage;

    if (message == null || message == _lastShownAutoMessage) {
      return;
    }

    _lastShownAutoMessage = message;
    _showTopNotice(message);
    provider.clearAutoSyncMessage();
  }

  void _showTopNotice(String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger.clearMaterialBanners();
    messenger.clearSnackBars();

    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFFE0F2F1),
        leading: const Icon(
          Icons.cloud_done_rounded,
          color: Color(0xFF0F766E),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF064E3B),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              messenger.clearMaterialBanners();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).clearMaterialBanners();
    });
  }

  Future<void> _loadData() async {
    final SyncProvider provider = context.read<SyncProvider>();

    await provider.loadOfflineQueue();
    await provider.loadSyncStatus(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (
        BuildContext context,
        SyncProvider provider,
        Widget? child,
      ) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Offline Sync',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh',
                onPressed: provider.isLoading || provider.isSyncing
                    ? null
                    : _loadData,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  _SyncHeader(provider: provider),
                  const SizedBox(height: 18),
                  _AutoSyncStatusCard(provider: provider),
                  const SizedBox(height: 20),
                  Text(
                    'Pending Offline Transactions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (provider.isLoading)
                    const _LoadingCard()
                  else if (provider.errorMessage != null)
                    _ErrorCard(
                      message: provider.errorMessage!,
                      onRetry: _loadData,
                    )
                  else if (!provider.hasOfflineTransactions)
                    const _EmptyQueueCard()
                  else
                    ...provider.offlineTransactions.map(
                      (OfflineMedicineTransaction transaction) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _OfflineTransactionCard(
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

class _SyncHeader extends StatelessWidget {
  const _SyncHeader({
    required this.provider,
  });

  final SyncProvider provider;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.cloud_sync_rounded,
                color: Colors.white,
                size: 32,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Offline Sync Center',
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
            'Offline medicine transactions are saved here and synced automatically when internet is available.',
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
                  label: 'Pending',
                  value: provider.pendingCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Failed',
                  value: provider.failedCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutoSyncStatusCard extends StatelessWidget {
  const _AutoSyncStatusCard({
    required this.provider,
  });

  final SyncProvider provider;

  @override
  Widget build(BuildContext context) {
    final String statusText = provider.isSyncing
        ? 'Syncing now...'
        : provider.pendingCount == 0 && provider.failedCount == 0
            ? 'All offline transactions are synced.'
            : 'Waiting for internet. The app will sync automatically.';

    final IconData icon = provider.isSyncing
        ? Icons.sync_rounded
        : provider.pendingCount == 0 && provider.failedCount == 0
            ? Icons.cloud_done_rounded
            : Icons.cloud_queue_rounded;

    final String lastSyncText = provider.lastAutoSyncAt == null
        ? 'Last auto sync: Not yet'
        : 'Last auto sync: ${DateFormat('MMM d, yyyy • h:mm a').format(provider.lastAutoSyncAt!)}';

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
              child: Icon(
                icon,
                color: const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Automatic Sync',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastSyncText,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (provider.isSyncing)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
          ],
        ),
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

class _OfflineTransactionCard extends StatelessWidget {
  const _OfflineTransactionCard({
    required this.transaction,
  });

  final OfflineMedicineTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = transaction.isFailed
        ? const Color(0xFFDC2626)
        : const Color(0xFFF59E0B);

    final Color statusBackground = transaction.isFailed
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFFFFBEB);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
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
                        transaction.medicineName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(transaction.createdAt),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  label: transaction.isFailed ? 'FAILED' : 'PENDING',
                  foreground: statusColor,
                  background: statusBackground,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _QueueInfo(
                    label: 'Type',
                    value: transaction.transactionTypeLabel,
                  ),
                ),
                Expanded(
                  child: _QueueInfo(
                    label: 'Quantity',
                    value: transaction.quantity.toString(),
                  ),
                ),
                Expanded(
                  child: _QueueInfo(
                    label: 'Device',
                    value: transaction.deviceId,
                  ),
                ),
              ],
            ),
            if (transaction.reason.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                transaction.reason,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (transaction.errorMessage.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        transaction.errorMessage,
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(String value) {
    final DateTime? dateTime = DateTime.tryParse(value);

    if (dateTime == null) {
      return value;
    }

    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
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
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _QueueInfo extends StatelessWidget {
  const _QueueInfo({
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
          value.isEmpty ? 'N/A' : value,
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
              'Unable to load sync data',
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

class _EmptyQueueCard extends StatelessWidget {
  const _EmptyQueueCard();

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
                Icons.cloud_done_rounded,
                color: Color(0xFF0F766E),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No pending offline records',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Offline medicine transactions will appear here only while they are waiting to sync.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
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
              child: Text('Loading offline queue...'),
            ),
          ],
        ),
      ),
    );
  }
}