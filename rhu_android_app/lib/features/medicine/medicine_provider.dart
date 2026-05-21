import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/storage/offline_queue_service.dart';
import '../../data/models/medicine_model.dart';
import '../../data/models/medicine_transaction_model.dart';
import '../../data/repositories/medicine_repository.dart';

class MedicineProvider extends ChangeNotifier {
  MedicineProvider({
    MedicineRepository? medicineRepository,
    OfflineQueueService? offlineQueueService,
    LocalStorageService? localStorageService,
  })  : _medicineRepository = medicineRepository ?? MedicineRepository(),
        _offlineQueueService = offlineQueueService ?? OfflineQueueService(),
        _localStorageService = localStorageService ?? LocalStorageService();

  final MedicineRepository _medicineRepository;
  final OfflineQueueService _offlineQueueService;
  final LocalStorageService _localStorageService;

  final List<MedicineModel> _medicines = <MedicineModel>[];
  final List<MedicineTransactionModel> _transactions =
      <MedicineTransactionModel>[];

  final Map<String, int> _localStockOverrides = <String, int>{};

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isRecordingTransaction = false;
  bool _lastTransactionWasOffline = false;

  String? _errorMessage;
  String? _successMessage;

  String _searchQuery = '';
  String? _stockStatusFilter;

  String? _rhuFilter;
  String? _barangayFilter;

  List<MedicineModel> get medicines {
    return List<MedicineModel>.unmodifiable(_medicines);
  }

  List<MedicineTransactionModel> get transactions {
    return List<MedicineTransactionModel>.unmodifiable(_transactions);
  }

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isRecordingTransaction => _isRecordingTransaction;
  bool get lastTransactionWasOffline => _lastTransactionWasOffline;

  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  String get searchQuery => _searchQuery;
  String? get stockStatusFilter => _stockStatusFilter;

  String? get rhuFilter => _rhuFilter;
  String? get barangayFilter => _barangayFilter;

  bool get hasMedicines => _medicines.isNotEmpty;
  bool get hasTransactions => _transactions.isNotEmpty;

  int get totalMedicines => _medicines.length;

  int get lowStockCount {
    return _medicines.where((MedicineModel item) => item.isLowStock).length;
  }

  int get outOfStockCount {
    return _medicines.where((MedicineModel item) => item.isOutOfStock).length;
  }

  int get expiredCount {
    return _medicines.where((MedicineModel item) => item.isExpired).length;
  }

  int get totalStock {
    return _medicines.fold<int>(
      0,
      (int sum, MedicineModel item) => sum + effectiveStockFor(item),
    );
  }

  int effectiveStockFor(MedicineModel medicine) {
    return _localStockOverrides[medicine.id] ?? medicine.currentStock;
  }

  Future<void> loadMedicines({
    bool refresh = false,
  }) async {
    if (_isLoading || _isRefreshing) {
      return;
    }

    if (refresh) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final List<MedicineModel> result =
          await _medicineRepository.getMedicines(
        search: _searchQuery,
        stockStatus: _stockStatusFilter,
        rhuId: _rhuFilter,
        barangayId: _barangayFilter,
      );

      _medicines
        ..clear()
        ..addAll(result);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Unable to load medicine records.';
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> loadTransactions({
    String? medicineId,
    String? transactionType,
    String? rhuId,
    String? barangayId,
    bool refresh = false,
  }) async {
    if (_isLoading || _isRefreshing) {
      return;
    }

    if (refresh) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final List<MedicineTransactionModel> result =
          await _medicineRepository.getMedicineTransactions(
        medicineId: medicineId,
        transactionType: transactionType,
        rhuId: rhuId ?? _rhuFilter,
        barangayId: barangayId ?? _barangayFilter,
      );

      _transactions
        ..clear()
        ..addAll(result);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Unable to load medicine transactions.';
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<bool> recordTransaction({
    required MedicineModel medicine,
    required String transactionType,
    required int quantity,
    required String reason,
    String remarks = '',
    String patientReference = '',
    String source = '',
  }) async {
    if (_isRecordingTransaction) {
      return false;
    }

    _isRecordingTransaction = true;
    _errorMessage = null;
    _successMessage = null;
    _lastTransactionWasOffline = false;
    notifyListeners();

    try {
      final String clientGeneratedId =
          'flutter-${const Uuid().v4()}-${DateTime.now().millisecondsSinceEpoch}';

      final result = await _medicineRepository.recordMedicineTransaction(
        medicineId: medicine.id,
        transactionType: transactionType,
        quantity: quantity,
        reason: reason,
        remarks: remarks,
        patientReference: patientReference,
        source: source,
        clientGeneratedId: clientGeneratedId,
        deviceId: 'flutter-android-device',
      );

      _transactions.insert(0, result.transaction);

      final MedicineModel? updatedMedicine = result.updatedMedicine;

      if (updatedMedicine != null) {
        _localStockOverrides.remove(updatedMedicine.id);
        _replaceMedicine(updatedMedicine);
      } else {
        await loadMedicines(refresh: true);
      }

      _successMessage = 'Medicine transaction recorded successfully.';
      _lastTransactionWasOffline = false;

      notifyListeners();

      return true;
    } on ApiException catch (error) {
      if (!_shouldSaveOffline(error)) {
        _errorMessage = error.message;
        notifyListeners();

        return false;
      }

      return _saveTransactionOffline(
        medicine: medicine,
        transactionType: transactionType,
        quantity: quantity,
        reason: reason,
        remarks: remarks,
        patientReference: patientReference,
        source: source,
      );
    } catch (_) {
      return _saveTransactionOffline(
        medicine: medicine,
        transactionType: transactionType,
        quantity: quantity,
        reason: reason,
        remarks: remarks,
        patientReference: patientReference,
        source: source,
      );
    } finally {
      _isRecordingTransaction = false;
      notifyListeners();
    }
  }

  Future<bool> _saveTransactionOffline({
    required MedicineModel medicine,
    required String transactionType,
    required int quantity,
    required String reason,
    required String remarks,
    required String patientReference,
    required String source,
  }) async {
    try {
      final int currentStock = effectiveStockFor(medicine);
      final int newStock = _calculateNewStock(
        currentStock: currentStock,
        transactionType: transactionType,
        quantity: quantity,
      );

      if (newStock < 0) {
        _errorMessage =
            'Cannot dispense $quantity ${medicine.unit}. Current stock is only $currentStock ${medicine.unit}.';
        notifyListeners();

        return false;
      }

      await _offlineQueueService.addMedicineTransaction(
        medicineId: medicine.id,
        medicineName: medicine.displayName,
        transactionType: transactionType,
        quantity: quantity,
        reason: reason,
        remarks: remarks,
        patientReference: patientReference,
        source: source,
        deviceId: 'flutter-android-device',
      );

      _localStockOverrides[medicine.id] = newStock;

      await _localStorageService.updateMedicineStockInAllCachedInventories(
        medicineId: medicine.id,
        newStock: newStock,
      );

      _successMessage =
          'Transaction saved offline. It will sync automatically when internet returns.';
      _lastTransactionWasOffline = true;
      _errorMessage = null;

      notifyListeners();

      return true;
    } catch (_) {
      _errorMessage = 'Unable to save transaction offline.';
      notifyListeners();

      return false;
    }
  }

  bool _shouldSaveOffline(ApiException error) {
    final int? statusCode = error.statusCode;

    if (statusCode == null) {
      return true;
    }

    if (statusCode == 0 || statusCode == 408) {
      return true;
    }

    if (statusCode >= 500) {
      return true;
    }

    return false;
  }

  int _calculateNewStock({
    required int currentStock,
    required String transactionType,
    required int quantity,
  }) {
    if (transactionType == 'received') {
      return currentStock + quantity;
    }

    if (transactionType == 'dispensed') {
      return currentStock - quantity;
    }

    if (transactionType == 'adjusted') {
      return quantity;
    }

    return currentStock;
  }

  Future<void> searchMedicines(String value) async {
    _searchQuery = value.trim();

    await loadMedicines(refresh: true);
  }

  Future<void> setStockStatusFilter(String? value) async {
    _stockStatusFilter = value;

    await loadMedicines(refresh: true);
  }

  Future<void> setLocationFilter({
    String? rhuId,
    String? barangayId,
  }) async {
    _rhuFilter = rhuId;
    _barangayFilter = barangayId;

    await loadMedicines(refresh: true);
  }

  Future<void> clearFilters() async {
    _searchQuery = '';
    _stockStatusFilter = null;
    _rhuFilter = null;
    _barangayFilter = null;

    await loadMedicines(refresh: true);
  }

  MedicineModel? findMedicineById(String id) {
    try {
      return _medicines.firstWhere((MedicineModel medicine) {
        return medicine.id == id;
      });
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSuccess() {
    _successMessage = null;
    notifyListeners();
  }

  void _replaceMedicine(MedicineModel updatedMedicine) {
    final int index = _medicines.indexWhere(
      (MedicineModel medicine) => medicine.id == updatedMedicine.id,
    );

    if (index == -1) {
      _medicines.insert(0, updatedMedicine);
      return;
    }

    _medicines[index] = updatedMedicine;
  }
}