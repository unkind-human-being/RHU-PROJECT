import '../../core/storage/offline_queue_service.dart';
import '../services/sync_service.dart';

class SyncRepository {
  SyncRepository({
    SyncService? syncService,
  }) : _syncService = syncService ?? SyncService();

  final SyncService _syncService;

  Future<List<OfflineMedicineTransaction>> getOfflineTransactions() {
    return _syncService.getOfflineTransactions();
  }

  Future<List<OfflineMedicineTransaction>> getPendingTransactions() {
    return _syncService.getPendingTransactions();
  }

  Future<int> getPendingCount() {
    return _syncService.getPendingCount();
  }

  Future<OfflineMedicineTransaction> saveOfflineMedicineTransaction({
    required String medicineId,
    required String medicineName,
    required String transactionType,
    required int quantity,
    required String reason,
    String remarks = '',
    String patientReference = '',
    String source = '',
  }) {
    return _syncService.saveOfflineMedicineTransaction(
      medicineId: medicineId,
      medicineName: medicineName,
      transactionType: transactionType,
      quantity: quantity,
      reason: reason,
      remarks: remarks,
      patientReference: patientReference,
      source: source,
    );
  }

  Future<SyncResult> syncPendingMedicineTransactions() {
    return _syncService.syncPendingMedicineTransactions();
  }

  Future<Map<String, dynamic>> getSyncStatus() {
    return _syncService.getSyncStatus();
  }

  Future<void> deleteSyncedTransactions() {
    return _syncService.deleteSyncedTransactions();
  }

  Future<void> clearOfflineQueue() {
    return _syncService.clearOfflineQueue();
  }
}