import '../models/medicine_model.dart';
import '../models/medicine_transaction_model.dart';
import '../services/medicine_service.dart';

class MedicineRepository {
  MedicineRepository({
    MedicineService? medicineService,
  }) : _medicineService = medicineService ?? MedicineService();

  final MedicineService _medicineService;

  Future<List<MedicineModel>> getMedicines({
    String? search,
    String? stockStatus,
    String? rhuId,
    String? barangayId,
    String? viewScope,
    int page = 1,
    int limit = 50,
  }) {
    return _medicineService.getMedicines(
      search: search,
      stockStatus: stockStatus,
      rhuId: rhuId,
      barangayId: barangayId,
      viewScope: viewScope,
      page: page,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> getMedicineSummary({
    String? rhuId,
    String? barangayId,
    String? viewScope,
  }) {
    return _medicineService.getMedicineSummary(
      rhuId: rhuId,
      barangayId: barangayId,
      viewScope: viewScope,
    );
  }

  Future<MedicineModel> getMedicineById(String medicineId) {
    return _medicineService.getMedicineById(medicineId);
  }

  Future<List<MedicineTransactionModel>> getMedicineTransactions({
    String? medicineId,
    String? transactionType,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) {
    return _medicineService.getMedicineTransactions(
      medicineId: medicineId,
      transactionType: transactionType,
      rhuId: rhuId,
      barangayId: barangayId,
      page: page,
      limit: limit,
    );
  }

  Future<RecordMedicineTransactionResult> recordMedicineTransaction({
    required String medicineId,
    required String transactionType,
    required int quantity,
    String reason = '',
    String remarks = '',
    String patientReference = '',
    String source = '',
    String clientGeneratedId = '',
    String deviceId = '',
  }) {
    return _medicineService.recordMedicineTransaction(
      medicineId: medicineId,
      transactionType: transactionType,
      quantity: quantity,
      reason: reason,
      remarks: remarks,
      patientReference: patientReference,
      source: source,
      clientGeneratedId: clientGeneratedId,
      deviceId: deviceId,
    );
  }


  Future<MedicineModel> createMedicine({
    required String name,
    required String genericName,
    required String brandName,
    required String dosageForm,
    required String strength,
    required String unit,
    required String category,
    required String rhuId,
    String? barangayId,
    required int currentStock,
    required int minimumStockLevel,
    required int maximumStockLevel,
    required String batchNumber,
    required DateTime expirationDate,
    required String supplier,
    required String remarks,
  }) {
    return _medicineService.createMedicine(
      name: name,
      genericName: genericName,
      brandName: brandName,
      dosageForm: dosageForm,
      strength: strength,
      unit: unit,
      category: category,
      rhuId: rhuId,
      barangayId: barangayId,
      currentStock: currentStock,
      minimumStockLevel: minimumStockLevel,
      maximumStockLevel: maximumStockLevel,
      batchNumber: batchNumber,
      expirationDate: expirationDate,
      supplier: supplier,
      remarks: remarks,
    );
  }

  Future<void> deleteMedicine(String medicineId) {
    return _medicineService.deleteMedicine(medicineId);
  }

  Future<MedicineModel> updateMedicine({
    required String medicineId,
    required String name,
    required String genericName,
    required String brandName,
    required String dosageForm,
    required String strength,
    required String unit,
    required String category,
    required int minimumStockLevel,
    required int maximumStockLevel,
    required String batchNumber,
    required DateTime expirationDate,
    required String supplier,
    required String remarks,
  }) {
    return _medicineService.updateMedicine(
      medicineId: medicineId,
      name: name,
      genericName: genericName,
      brandName: brandName,
      dosageForm: dosageForm,
      strength: strength,
      unit: unit,
      category: category,
      minimumStockLevel: minimumStockLevel,
      maximumStockLevel: maximumStockLevel,
      batchNumber: batchNumber,
      expirationDate: expirationDate,
      supplier: supplier,
      remarks: remarks,
    );
  }

}