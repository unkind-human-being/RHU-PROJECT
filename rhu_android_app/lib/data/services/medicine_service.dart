import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/storage/token_storage_service.dart';
import '../models/medicine_model.dart';
import '../models/medicine_transaction_model.dart';

class MedicineService {
  MedicineService({
    ApiClient? apiClient,
    TokenStorageService? tokenStorageService,
    LocalStorageService? localStorageService,
  })  : _tokenStorageService = tokenStorageService ?? TokenStorageService(),
        _localStorageService = localStorageService ?? LocalStorageService(),
        _apiClient = apiClient ??
            ApiClient(
              tokenProvider:
                  (tokenStorageService ?? TokenStorageService()).getToken,
            );

  final ApiClient _apiClient;
  final TokenStorageService _tokenStorageService;
  final LocalStorageService _localStorageService;

  Future<List<MedicineModel>> getMedicines({
    String? search,
    String? stockStatus,
    String? rhuId,
    String? barangayId,
    String? viewScope,
    int page = 1,
    int limit = 50,
  }) async {
    final String cacheKey = _buildMedicineInventoryCacheKey(
      search: search,
      stockStatus: stockStatus,
      rhuId: rhuId,
      barangayId: barangayId,
      viewScope: viewScope,
      page: page,
      limit: limit,
    );

    final String baseCacheKey = _buildMedicineInventoryCacheKey(
      search: null,
      stockStatus: null,
      rhuId: rhuId,
      barangayId: barangayId,
      viewScope: viewScope,
      page: page,
      limit: limit,
    );

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        ApiConstants.medicines,
        requiresAuth: true,
        queryParameters: <String, dynamic>{
          'search': search,
          'stockStatus': stockStatus,
          'rhu': rhuId,
          'barangay': barangayId,
          'viewScope': viewScope,
          'page': page,
          'limit': limit,
        },
      );

      final dynamic data = response['data'];

      if (data is! List) {
        return <MedicineModel>[];
      }

      final List<Map<String, dynamic>> medicineJsonList = data
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();

      await _localStorageService.saveMedicineInventory(
        cacheKey: cacheKey,
        medicines: medicineJsonList,
      );

      if (_isBlank(search) && _isBlank(stockStatus)) {
        await _localStorageService.saveMedicineInventory(
          cacheKey: baseCacheKey,
          medicines: medicineJsonList,
        );
      }

      return medicineJsonList.map(MedicineModel.fromJson).toList();
    } catch (_) {
      List<Map<String, dynamic>> cachedMedicines =
          await _localStorageService.getMedicineInventory(
        cacheKey: cacheKey,
      );

      if (cachedMedicines.isEmpty) {
        cachedMedicines = await _localStorageService.getMedicineInventory(
          cacheKey: baseCacheKey,
        );

        cachedMedicines = _applyLocalMedicineFilters(
          medicines: cachedMedicines,
          search: search,
          stockStatus: stockStatus,
        );
      }

      if (cachedMedicines.isNotEmpty) {
        return cachedMedicines.map(MedicineModel.fromJson).toList();
      }

      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMedicineSummary({
    String? rhuId,
    String? barangayId,
    String? viewScope,
  }) async {
    final Map<String, dynamic> response = await _apiClient.get(
      ApiConstants.medicineSummary,
      requiresAuth: true,
      queryParameters: <String, dynamic>{
        'rhu': rhuId,
        'barangay': barangayId,
        'viewScope': viewScope,
      },
    );

    final dynamic data = response['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    return <String, dynamic>{};
  }

  Future<MedicineModel> getMedicineById(String medicineId) async {
    if (medicineId.trim().isEmpty) {
      throw const ApiException(
        message: 'Medicine ID is required.',
        statusCode: 400,
      );
    }

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '${ApiConstants.medicines}/$medicineId',
        requiresAuth: true,
      );

      final dynamic data = response['data'];

      if (data is! Map<String, dynamic>) {
        throw const ApiException(
          message: 'Invalid medicine response from server.',
        );
      }

      final Map<String, dynamic> medicineJson =
          Map<String, dynamic>.from(data);

      await _localStorageService.updateMedicineInAllCachedInventories(
        medicine: medicineJson,
      );

      return MedicineModel.fromJson(medicineJson);
    } catch (_) {
      final Map<String, dynamic>? cachedMedicine =
          await _findMedicineInLocalCache(medicineId);

      if (cachedMedicine != null) {
        return MedicineModel.fromJson(cachedMedicine);
      }

      rethrow;
    }
  }

  Future<List<MedicineTransactionModel>> getMedicineTransactions({
    String? medicineId,
    String? transactionType,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) async {
    final Map<String, dynamic> response = await _apiClient.get(
      ApiConstants.medicineTransactions,
      requiresAuth: true,
      queryParameters: <String, dynamic>{
        'medicine': medicineId,
        'transactionType': transactionType,
        'rhu': rhuId,
        'barangay': barangayId,
        'page': page,
        'limit': limit,
      },
    );

    final dynamic data = response['data'];

    if (data is! List) {
      return <MedicineTransactionModel>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(MedicineTransactionModel.fromJson)
        .toList();
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
  }) async {
    if (medicineId.trim().isEmpty) {
      throw const ApiException(
        message: 'Please select a medicine.',
        statusCode: 400,
      );
    }

    if (transactionType.trim().isEmpty) {
      throw const ApiException(
        message: 'Please select a transaction type.',
        statusCode: 400,
      );
    }

    if (quantity <= 0) {
      throw const ApiException(
        message: 'Quantity must be greater than zero.',
        statusCode: 400,
      );
    }

    final Map<String, dynamic> response = await _apiClient.post(
      ApiConstants.medicineTransactions,
      requiresAuth: true,
      body: <String, dynamic>{
        'medicine': medicineId,
        'transactionType': transactionType,
        'quantity': quantity,
        'reason': reason.trim(),
        'remarks': remarks.trim(),
        'patientReference': patientReference.trim(),
        'source': source.trim(),
        'clientGeneratedId': clientGeneratedId.trim(),
        'deviceId': deviceId.trim(),
      },
    );

    final dynamic data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Invalid transaction response from server.',
      );
    }

    final dynamic transactionJson = data['transaction'];
    final dynamic medicineJson = data['medicine'];

    if (transactionJson is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Transaction was saved but response data was invalid.',
      );
    }

    final MedicineTransactionModel transaction =
        MedicineTransactionModel.fromJson(
      Map<String, dynamic>.from(transactionJson),
    );

    MedicineModel? updatedMedicine;

    if (medicineJson is Map<String, dynamic>) {
      final Map<String, dynamic> updatedMedicineJson =
          Map<String, dynamic>.from(medicineJson);

      await _localStorageService.updateMedicineInAllCachedInventories(
        medicine: updatedMedicineJson,
      );

      updatedMedicine = MedicineModel.fromJson(updatedMedicineJson);
    }

    return RecordMedicineTransactionResult(
      transaction: transaction,
      updatedMedicine: updatedMedicine,
    );
  }

  Future<String?> getToken() {
    return _tokenStorageService.getToken();
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
  }) async {
    if (name.trim().isEmpty) {
      throw const ApiException(
        message: 'Medicine name is required.',
        statusCode: 400,
      );
    }

    if (rhuId.trim().isEmpty) {
      throw const ApiException(
        message: 'RHU is required.',
        statusCode: 400,
      );
    }

    if (currentStock < 0) {
      throw const ApiException(
        message: 'Current stock cannot be negative.',
        statusCode: 400,
      );
    }

    if (minimumStockLevel < 0 || maximumStockLevel < 0) {
      throw const ApiException(
        message: 'Stock levels cannot be negative.',
        statusCode: 400,
      );
    }

    if (maximumStockLevel < minimumStockLevel) {
      throw const ApiException(
        message: 'Maximum stock level must be higher than minimum stock level.',
        statusCode: 400,
      );
    }

    final String expirationDateText =
        expirationDate.toIso8601String().split('T').first;

    final Map<String, dynamic> body = <String, dynamic>{
      'name': name.trim(),
      'genericName': genericName.trim(),
      'brandName': brandName.trim(),
      'dosageForm': dosageForm.trim(),
      'strength': strength.trim(),
      'unit': unit.trim(),
      'category': category.trim(),
      'rhu': rhuId.trim(),
      'currentStock': currentStock,
      'minimumStockLevel': minimumStockLevel,
      'maximumStockLevel': maximumStockLevel,
      'batchNumber': batchNumber.trim(),
      'expirationDate': expirationDateText,
      'supplier': supplier.trim(),
      'remarks': remarks.trim(),
    };

    if (barangayId != null && barangayId.trim().isNotEmpty) {
      body['barangay'] = barangayId.trim();
    }

    final Map<String, dynamic> response = await _apiClient.post(
      ApiConstants.medicines,
      requiresAuth: true,
      body: body,
    );

    final dynamic data = response['data'] ?? response['medicine'];

    if (data is Map<String, dynamic>) {
      final Map<String, dynamic> medicineJson = Map<String, dynamic>.from(data);

      await _localStorageService.addMedicineToAllCachedInventories(
        medicine: medicineJson,
      );

      return MedicineModel.fromJson(medicineJson);
    }

    if (response.containsKey('_id') || response.containsKey('id')) {
      await _localStorageService.addMedicineToAllCachedInventories(
        medicine: response,
      );

      return MedicineModel.fromJson(response);
    }

    throw const ApiException(
      message: 'Invalid medicine response from server.',
    );
  }

  Future<void> deleteMedicine(String medicineId) async {
    if (medicineId.trim().isEmpty) {
      throw const ApiException(
        message: 'Medicine ID is required.',
        statusCode: 400,
      );
    }

    await _apiClient.delete(
      '${ApiConstants.medicines}/$medicineId',
      requiresAuth: true,
    );

    await _localStorageService.removeMedicineFromAllCachedInventories(
      medicineId: medicineId,
    );
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
  }) async {
    if (medicineId.trim().isEmpty) {
      throw const ApiException(
        message: 'Medicine ID is required.',
        statusCode: 400,
      );
    }

    if (name.trim().isEmpty) {
      throw const ApiException(
        message: 'Medicine name is required.',
        statusCode: 400,
      );
    }

    if (minimumStockLevel < 0 || maximumStockLevel < 0) {
      throw const ApiException(
        message: 'Stock levels cannot be negative.',
        statusCode: 400,
      );
    }

    if (maximumStockLevel < minimumStockLevel) {
      throw const ApiException(
        message: 'Maximum stock level must be higher than minimum stock level.',
        statusCode: 400,
      );
    }

    final String expirationDateText =
        expirationDate.toIso8601String().split('T').first;

    final Map<String, dynamic> body = <String, dynamic>{
      'name': name.trim(),
      'genericName': genericName.trim(),
      'brandName': brandName.trim(),
      'dosageForm': dosageForm.trim(),
      'strength': strength.trim(),
      'unit': unit.trim(),
      'category': category.trim(),
      'minimumStockLevel': minimumStockLevel,
      'maximumStockLevel': maximumStockLevel,
      'batchNumber': batchNumber.trim(),
      'expirationDate': expirationDateText,
      'supplier': supplier.trim(),
      'remarks': remarks.trim(),
    };

    final Map<String, dynamic> response = await _apiClient.patch(
      '${ApiConstants.medicines}/$medicineId',
      requiresAuth: true,
      body: body,
    );

    final dynamic data = response['data'] ?? response['medicine'];

    if (data is Map<String, dynamic>) {
      final Map<String, dynamic> medicineJson = Map<String, dynamic>.from(data);

      await _localStorageService.updateMedicineInAllCachedInventories(
        medicine: medicineJson,
      );

      return MedicineModel.fromJson(medicineJson);
    }

    if (response.containsKey('_id') || response.containsKey('id')) {
      await _localStorageService.updateMedicineInAllCachedInventories(
        medicine: response,
      );

      return MedicineModel.fromJson(response);
    }

    throw const ApiException(
      message: 'Invalid medicine response from server.',
    );
  }

  String _buildMedicineInventoryCacheKey({
    String? search,
    String? stockStatus,
    String? rhuId,
    String? barangayId,
    String? viewScope,
    required int page,
    required int limit,
  }) {
    return <String>[
      'medicine_inventory',
      'search=${search ?? ''}',
      'stockStatus=${stockStatus ?? ''}',
      'rhu=${rhuId ?? ''}',
      'barangay=${barangayId ?? ''}',
      'viewScope=${viewScope ?? ''}',
      'page=$page',
      'limit=$limit',
    ].join('|');
  }

  List<Map<String, dynamic>> _applyLocalMedicineFilters({
    required List<Map<String, dynamic>> medicines,
    String? search,
    String? stockStatus,
  }) {
    Iterable<Map<String, dynamic>> result = medicines;

    if (!_isBlank(search)) {
      final String query = search!.toLowerCase().trim();

      result = result.where((Map<String, dynamic> medicine) {
        final String searchableText = <String>[
          medicine['name']?.toString() ?? '',
          medicine['genericName']?.toString() ?? '',
          medicine['brandName']?.toString() ?? '',
          medicine['category']?.toString() ?? '',
          medicine['batchNumber']?.toString() ?? '',
        ].join(' ').toLowerCase();

        return searchableText.contains(query);
      });
    }

    if (!_isBlank(stockStatus)) {
      final String status = stockStatus!.toLowerCase().trim();

      result = result.where((Map<String, dynamic> medicine) {
        final int currentStock = _readInt(medicine['currentStock']);
        final int minimumStockLevel = _readInt(medicine['minimumStockLevel']);
        final DateTime? expirationDate = DateTime.tryParse(
          medicine['expirationDate']?.toString() ?? '',
        );

        final bool isOutOfStock = currentStock <= 0;
        final bool isLowStock =
            currentStock > 0 && currentStock <= minimumStockLevel;
        final bool isExpired = expirationDate != null &&
            expirationDate.isBefore(DateTime.now());

        if (status == 'out_of_stock' || status == 'outofstock') {
          return isOutOfStock;
        }

        if (status == 'low_stock' || status == 'lowstock') {
          return isLowStock;
        }

        if (status == 'expired') {
          return isExpired;
        }

        return true;
      });
    }

    return result.toList();
  }

  Future<Map<String, dynamic>?> _findMedicineInLocalCache(
    String medicineId,
  ) async {
    final List<String> commonKeys = <String>[
      _buildMedicineInventoryCacheKey(
        search: null,
        stockStatus: null,
        rhuId: null,
        barangayId: null,
        viewScope: null,
        page: 1,
        limit: 50,
      ),
    ];

    for (final String key in commonKeys) {
      final List<Map<String, dynamic>> medicines =
          await _localStorageService.getMedicineInventory(cacheKey: key);

      for (final Map<String, dynamic> medicine in medicines) {
        final String id = _readMedicineId(medicine);

        if (id == medicineId) {
          return medicine;
        }
      }
    }

    return null;
  }

  String _readMedicineId(Map<String, dynamic> medicine) {
    final dynamic id = medicine['_id'] ?? medicine['id'];

    if (id == null) {
      return '';
    }

    return id.toString();
  }

  int _readInt(dynamic value) {
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

  bool _isBlank(String? value) {
    return value == null || value.trim().isEmpty;
  }
}

class RecordMedicineTransactionResult {
  const RecordMedicineTransactionResult({
    required this.transaction,
    this.updatedMedicine,
  });

  final MedicineTransactionModel transaction;
  final MedicineModel? updatedMedicine;
}