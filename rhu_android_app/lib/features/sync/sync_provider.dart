import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/offline_queue_service.dart';
import '../../data/repositories/sync_repository.dart';
import '../../data/services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  SyncProvider({
    SyncRepository? syncRepository,
  }) : _syncRepository = syncRepository ?? SyncRepository() {
    startAutoSync();
  }

  final SyncRepository _syncRepository;

  final List<OfflineMedicineTransaction> _offlineTransactions =
      <OfflineMedicineTransaction>[];

  Timer? _autoSyncTimer;

  bool _isLoading = false;
  bool _isSyncing = false;

  String? _errorMessage;
  String? _successMessage;
  String? _lastAutoSyncMessage;

  DateTime? _lastAutoSyncAt;

  Map<String, dynamic> _syncStatus = <String, dynamic>{};

  List<OfflineMedicineTransaction> get offlineTransactions {
    return List<OfflineMedicineTransaction>.unmodifiable(_offlineTransactions);
  }

  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;

  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get lastAutoSyncMessage => _lastAutoSyncMessage;

  DateTime? get lastAutoSyncAt => _lastAutoSyncAt;

  Map<String, dynamic> get syncStatus => Map<String, dynamic>.from(_syncStatus);

  bool get hasOfflineTransactions => _offlineTransactions.isNotEmpty;

  int get totalOfflineCount => _offlineTransactions.length;

  int get pendingCount {
    return _offlineTransactions.where((OfflineMedicineTransaction item) {
      return item.isPending;
    }).length;
  }

  int get failedCount {
    return _offlineTransactions.where((OfflineMedicineTransaction item) {
      return item.isFailed;
    }).length;
  }

  int get serverTotalLogs {
    return _readInt(_syncStatus['totalLogs']);
  }

  int get serverSuccessLogs {
    return _readInt(_syncStatus['successLogs']);
  }

  int get serverFailedLogs {
    return _readInt(_syncStatus['failedLogs']);
  }

  int get serverPartialLogs {
    return _readInt(_syncStatus['partialLogs']);
  }

  void startAutoSync() {
    _autoSyncTimer?.cancel();

    _autoSyncTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        _runAutoSyncTick();
      },
    );

    _runAutoSyncTick();
  }

  Future<void> _runAutoSyncTick() async {
    if (_isSyncing) {
      return;
    }

    try {
      await loadOfflineQueue(silent: true);

      if (pendingCount == 0 && failedCount == 0) {
        return;
      }

      await syncPendingTransactions(
        silent: true,
        fromAutoSync: true,
      );
    } catch (_) {
      // Silent fail. It will try again on the next timer tick.
    }
  }

  Future<void> loadOfflineQueue({
    bool silent = false,
  }) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final List<OfflineMedicineTransaction> transactions =
          await _syncRepository.getOfflineTransactions();

      _offlineTransactions
        ..clear()
        ..addAll(
          transactions.where((OfflineMedicineTransaction item) {
            return !item.isSynced;
          }),
        );
    } catch (_) {
      if (!silent) {
        _errorMessage = 'Unable to load offline transactions.';
      }
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadSyncStatus({
    bool silent = false,
  }) async {
    try {
      _syncStatus = await _syncRepository.getSyncStatus();

      if (!silent) {
        notifyListeners();
      }
    } on ApiException catch (error) {
      if (!silent) {
        _errorMessage = error.message;
        notifyListeners();
      }
    } catch (_) {
      if (!silent) {
        _errorMessage = 'Unable to load sync status.';
        notifyListeners();
      }
    }
  }

  Future<bool> saveOfflineTransaction({
    required String medicineId,
    required String medicineName,
    required String transactionType,
    required int quantity,
    required String reason,
    String remarks = '',
    String patientReference = '',
    String source = '',
  }) async {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final OfflineMedicineTransaction transaction =
          await _syncRepository.saveOfflineMedicineTransaction(
        medicineId: medicineId,
        medicineName: medicineName,
        transactionType: transactionType,
        quantity: quantity,
        reason: reason,
        remarks: remarks,
        patientReference: patientReference,
        source: source,
      );

      _offlineTransactions.insert(0, transaction);
      _successMessage =
          'Transaction saved offline. It will sync automatically.';

      notifyListeners();

      _runAutoSyncTick();

      return true;
    } catch (_) {
      _errorMessage = 'Unable to save offline transaction.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> syncPendingTransactions({
    bool silent = false,
    bool fromAutoSync = false,
  }) async {
    if (_isSyncing) {
      return false;
    }

    _isSyncing = true;

    if (!silent) {
      _errorMessage = null;
      _successMessage = null;
      notifyListeners();
    }

    try {
      final SyncResult result =
          await _syncRepository.syncPendingMedicineTransactions();

      await _syncRepository.deleteSyncedTransactions();
      await loadOfflineQueue(silent: true);
      await loadSyncStatus(silent: true);

      _lastAutoSyncAt = DateTime.now();

      if (result.success) {
        if (result.successCount > 0 || result.totalRecords > 0) {
          _successMessage =
              'Medicine transactions synced successfully.';

          if (fromAutoSync) {
            _lastAutoSyncMessage =
                'Internet is available. Medicine transactions synced.';
          }
        }

        if (!silent || fromAutoSync) {
          notifyListeners();
        }

        return true;
      }

      if (!silent) {
        _errorMessage = result.message;
        notifyListeners();
      }

      return false;
    } on ApiException catch (error) {
      if (!silent) {
        _errorMessage = error.message;
        notifyListeners();
      }

      return false;
    } catch (_) {
      if (!silent) {
        _errorMessage = 'Unable to sync offline transactions.';
        notifyListeners();
      }

      return false;
    } finally {
      _isSyncing = false;

      if (!silent) {
        notifyListeners();
      }
    }
  }

  Future<void> deleteSyncedTransactions() async {
    await _syncRepository.deleteSyncedTransactions();
    await loadOfflineQueue();
  }

  Future<void> clearOfflineQueue() async {
    await _syncRepository.clearOfflineQueue();
    await loadOfflineQueue();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void clearAutoSyncMessage() {
    _lastAutoSyncMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  static int _readInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }
}