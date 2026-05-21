import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/storage/offline_queue_service.dart';
import '../../core/storage/token_storage_service.dart';

class SyncService {
  SyncService({
    ApiClient? apiClient,
    TokenStorageService? tokenStorageService,
    OfflineQueueService? offlineQueueService,
    LocalStorageService? localStorageService,
  })  : _tokenStorageService = tokenStorageService ?? TokenStorageService(),
        _offlineQueueService = offlineQueueService ?? OfflineQueueService(),
        _localStorageService = localStorageService ?? LocalStorageService(),
        _apiClient = apiClient ??
            ApiClient(
              tokenProvider:
                  (tokenStorageService ?? TokenStorageService()).getToken,
            );

  final ApiClient _apiClient;
  final TokenStorageService _tokenStorageService;
  final OfflineQueueService _offlineQueueService;
  final LocalStorageService _localStorageService;

  Future<List<OfflineMedicineTransaction>> getOfflineTransactions() {
    return _offlineQueueService.getAllTransactions();
  }

  Future<List<OfflineMedicineTransaction>> getPendingTransactions() {
    return _offlineQueueService.getPendingTransactions();
  }

  Future<int> getPendingCount() {
    return _offlineQueueService.getPendingCount();
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
    return _offlineQueueService.addMedicineTransaction(
      medicineId: medicineId,
      medicineName: medicineName,
      transactionType: transactionType,
      quantity: quantity,
      reason: reason,
      remarks: remarks,
      patientReference: patientReference,
      source: source,
      deviceId: 'flutter-android-device',
    );
  }

  Future<SyncResult> syncPendingMedicineTransactions() async {
    final List<OfflineMedicineTransaction> pendingTransactions =
        await _offlineQueueService.getPendingTransactions();

    if (pendingTransactions.isEmpty) {
      return const SyncResult(
        success: true,
        message: 'No pending offline transactions to sync.',
        totalRecords: 0,
        successCount: 0,
        failedCount: 0,
      );
    }

    final Map<String, dynamic> response = await _apiClient.post(
      ApiConstants.syncMedicineTransactions,
      requiresAuth: true,
      body: <String, dynamic>{
        'deviceId': 'flutter-android-device',
        'appVersion': '1.0.0',
        'platform': 'android',
        'transactions': pendingTransactions
            .map((OfflineMedicineTransaction transaction) {
          return transaction.toSyncJson();
        }).toList(),
      },
    );

    final List<dynamic> resultItems = _readResultItems(response);

    final Map<String, OfflineMedicineTransaction> transactionByClientId =
        <String, OfflineMedicineTransaction>{
      for (final OfflineMedicineTransaction transaction in pendingTransactions)
        transaction.clientGeneratedId: transaction,
    };

    for (final dynamic item in resultItems) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final String clientGeneratedId =
          item['clientGeneratedId']?.toString() ?? '';

      final OfflineMedicineTransaction? localTransaction =
          transactionByClientId[clientGeneratedId];

      if (localTransaction == null) {
        continue;
      }

      final bool itemSuccess = item['success'] == true;

      if (itemSuccess) {
        await _offlineQueueService.markAsSynced(localTransaction.id);

        final dynamic medicineJson =
            item['medicine'] ?? item['updatedMedicine'];

        if (medicineJson is Map<String, dynamic>) {
          await _localStorageService.updateMedicineInAllCachedInventories(
            medicine: Map<String, dynamic>.from(medicineJson),
          );
        }
      } else {
        await _offlineQueueService.markAsFailed(
          id: localTransaction.id,
          errorMessage: item['message']?.toString() ?? 'Sync failed.',
        );
      }
    }

    final bool overallSuccess = _readBool(response['success']);
    final int totalRecords = _readInt(response['totalRecords']);
    final int successCount = _readInt(response['successCount']);
    final int failedCount = _readInt(response['failedCount']);

    return SyncResult(
      success: overallSuccess,
      message: response['message']?.toString() ??
          (overallSuccess ? 'Sync completed.' : 'Sync failed.'),
      syncLogId: response['syncLogId']?.toString(),
      totalRecords: totalRecords,
      successCount: successCount,
      failedCount: failedCount,
    );
  }

  Future<Map<String, dynamic>> getSyncStatus() async {
    final Map<String, dynamic> response = await _apiClient.get(
      ApiConstants.syncStatus,
      requiresAuth: true,
    );

    final dynamic data = response['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    return <String, dynamic>{};
  }

  Future<void> deleteSyncedTransactions() {
    return _offlineQueueService.deleteSyncedTransactions();
  }

  Future<void> clearOfflineQueue() {
    return _offlineQueueService.clearAll();
  }

  Future<String?> getToken() {
    return _tokenStorageService.getToken();
  }

  static List<dynamic> _readResultItems(Map<String, dynamic> response) {
    final dynamic directResults = response['results'];

    if (directResults is List) {
      return directResults;
    }

    final dynamic data = response['data'];

    if (data is Map<String, dynamic> && data['results'] is List) {
      return data['results'] as List;
    }

    return <dynamic>[];
  }

  static bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value == null) {
      return false;
    }

    return value.toString().toLowerCase() == 'true';
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

class SyncResult {
  const SyncResult({
    required this.success,
    required this.message,
    required this.totalRecords,
    required this.successCount,
    required this.failedCount,
    this.syncLogId,
  });

  final bool success;
  final String message;
  final String? syncLogId;
  final int totalRecords;
  final int successCount;
  final int failedCount;
}