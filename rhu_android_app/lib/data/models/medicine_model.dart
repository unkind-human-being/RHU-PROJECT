class MedicineModel {
  const MedicineModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.minimumStockLevel,
    required this.maximumStockLevel,
    required this.stockStatus,
    this.genericName = '',
    this.brandName = '',
    this.dosageForm = '',
    this.strength = '',
    this.category = '',
    this.rhuId,
    this.rhuName,
    this.rhuCode,
    this.barangayId,
    this.barangayName,
    this.barangayCode,
    this.batchNumber = '',
    this.expirationDate,
    this.supplier = '',
    this.remarks = '',
    this.lastTransactionAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String genericName;
  final String brandName;
  final String dosageForm;
  final String strength;
  final String unit;
  final String category;

  final String? rhuId;
  final String? rhuName;
  final String? rhuCode;

  final String? barangayId;
  final String? barangayName;
  final String? barangayCode;

  final int currentStock;
  final int minimumStockLevel;
  final int maximumStockLevel;

  final String batchNumber;
  final DateTime? expirationDate;
  final String supplier;
  final String remarks;
  final String stockStatus;

  final DateTime? lastTransactionAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLowStock => stockStatus == 'low_stock';
  bool get isOutOfStock => stockStatus == 'out_of_stock';
  bool get isExpired => stockStatus == 'expired';
  bool get isInStock => stockStatus == 'in_stock';

  String get displayName {
    if (strength.trim().isEmpty) {
      return name;
    }

    return '$name $strength';
  }

  String get locationName {
    if (barangayName != null && barangayName!.trim().isNotEmpty) {
      return barangayName!;
    }

    if (rhuName != null && rhuName!.trim().isNotEmpty) {
      return rhuName!;
    }

    return 'No location';
  }

  String get stockStatusLabel {
    switch (stockStatus) {
      case 'in_stock':
        return 'In Stock';
      case 'low_stock':
        return 'Low Stock';
      case 'out_of_stock':
        return 'Out of Stock';
      case 'expired':
        return 'Expired';
      default:
        return 'Unknown';
    }
  }

  double get stockPercentage {
    if (maximumStockLevel <= 0) {
      return 0;
    }

    final double value = currentStock / maximumStockLevel;

    if (value < 0) {
      return 0;
    }

    if (value > 1) {
      return 1;
    }

    return value;
  }

  factory MedicineModel.fromJson(Map<String, dynamic> json) {
    final dynamic rhu = json['rhu'];
    final dynamic barangay = json['barangay'];

    return MedicineModel(
      id: _readString(json['_id'] ?? json['id']),
      name: _readString(json['name']),
      genericName: _readString(json['genericName']),
      brandName: _readString(json['brandName']),
      dosageForm: _readString(json['dosageForm']),
      strength: _readString(json['strength']),
      unit: _readString(json['unit']),
      category: _readString(json['category']),
      rhuId: _readNestedId(rhu),
      rhuName: _readNestedString(rhu, 'name'),
      rhuCode: _readNestedString(rhu, 'code'),
      barangayId: _readNestedId(barangay),
      barangayName: _readNestedString(barangay, 'name'),
      barangayCode: _readNestedString(barangay, 'code'),
      currentStock: _readInt(json['currentStock']),
      minimumStockLevel: _readInt(json['minimumStockLevel']),
      maximumStockLevel: _readInt(json['maximumStockLevel']),
      batchNumber: _readString(json['batchNumber']),
      expirationDate: _readDate(json['expirationDate']),
      supplier: _readString(json['supplier']),
      remarks: _readString(json['remarks']),
      stockStatus: _readString(json['stockStatus'], fallback: 'in_stock'),
      lastTransactionAt: _readDate(json['lastTransactionAt']),
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      '_id': id,
      'name': name,
      'genericName': genericName,
      'brandName': brandName,
      'dosageForm': dosageForm,
      'strength': strength,
      'unit': unit,
      'category': category,
      'rhu': rhuId == null
          ? null
          : <String, dynamic>{
              '_id': rhuId,
              'name': rhuName,
              'code': rhuCode,
            },
      'barangay': barangayId == null
          ? null
          : <String, dynamic>{
              '_id': barangayId,
              'name': barangayName,
              'code': barangayCode,
            },
      'currentStock': currentStock,
      'minimumStockLevel': minimumStockLevel,
      'maximumStockLevel': maximumStockLevel,
      'batchNumber': batchNumber,
      'expirationDate': expirationDate?.toIso8601String(),
      'supplier': supplier,
      'remarks': remarks,
      'stockStatus': stockStatus,
      'lastTransactionAt': lastTransactionAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static String _readString(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    return value.toString();
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

  static String? _readNestedId(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      return value.trim().isEmpty ? null : value;
    }

    if (value is Map<String, dynamic>) {
      final String id = _readString(value['_id'] ?? value['id']);
      return id.trim().isEmpty ? null : id;
    }

    return null;
  }

  static String? _readNestedString(dynamic value, String key) {
    if (value is Map<String, dynamic>) {
      final String result = _readString(value[key]);
      return result.trim().isEmpty ? null : result;
    }

    return null;
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}