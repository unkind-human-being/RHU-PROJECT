class MedicineTransactionModel {
  const MedicineTransactionModel({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.transactionType,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.rhuId,
    this.rhuName,
    this.barangayId,
    this.barangayName,
    this.batchNumber = '',
    this.reason = '',
    this.remarks = '',
    this.patientReference = '',
    this.source = '',
    this.recordedById,
    this.recordedByName,
    this.clientGeneratedId = '',
    this.deviceId = '',
    this.syncStatus = '',
    this.transactionDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;

  final String medicineId;
  final String medicineName;

  final String? rhuId;
  final String? rhuName;

  final String? barangayId;
  final String? barangayName;

  final String transactionType;
  final int quantity;
  final int previousStock;
  final int newStock;

  final String batchNumber;
  final String reason;
  final String remarks;
  final String patientReference;
  final String source;

  final String? recordedById;
  final String? recordedByName;

  final String clientGeneratedId;
  final String deviceId;
  final String syncStatus;

  final DateTime? transactionDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isReceived => transactionType == 'received';
  bool get isDispensed => transactionType == 'dispensed';
  bool get isAdjusted => transactionType == 'adjusted';

  String get transactionTypeLabel {
    switch (transactionType) {
      case 'received':
        return 'Received';
      case 'dispensed':
        return 'Dispensed';
      case 'adjusted':
        return 'Adjusted';
      default:
        return 'Unknown';
    }
  }

  String get stockMovementLabel {
    if (isReceived) {
      return '+$quantity';
    }

    if (isDispensed) {
      return '-$quantity';
    }

    if (isAdjusted) {
      return '$previousStock → $newStock';
    }

    return quantity.toString();
  }

  factory MedicineTransactionModel.fromJson(Map<String, dynamic> json) {
    final dynamic medicine = json['medicine'];
    final dynamic rhu = json['rhu'];
    final dynamic barangay = json['barangay'];
    final dynamic recordedBy = json['recordedBy'];

    return MedicineTransactionModel(
      id: _readString(json['_id'] ?? json['id']),
      medicineId: _readNestedId(medicine) ?? _readString(json['medicine']),
      medicineName: _readNestedString(medicine, 'name') ?? 'Unknown Medicine',
      rhuId: _readNestedId(rhu),
      rhuName: _readNestedString(rhu, 'name'),
      barangayId: _readNestedId(barangay),
      barangayName: _readNestedString(barangay, 'name'),
      transactionType: _readString(json['transactionType']),
      quantity: _readInt(json['quantity']),
      previousStock: _readInt(json['previousStock']),
      newStock: _readInt(json['newStock']),
      batchNumber: _readString(json['batchNumber']),
      reason: _readString(json['reason']),
      remarks: _readString(json['remarks']),
      patientReference: _readString(json['patientReference']),
      source: _readString(json['source']),
      recordedById: _readNestedId(recordedBy),
      recordedByName: _readNestedString(recordedBy, 'fullName'),
      clientGeneratedId: _readString(json['clientGeneratedId']),
      deviceId: _readString(json['deviceId']),
      syncStatus: _readString(json['syncStatus']),
      transactionDate: _readDate(json['transactionDate']),
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      '_id': id,
      'medicine': <String, dynamic>{
        '_id': medicineId,
        'name': medicineName,
      },
      'rhu': rhuId == null
          ? null
          : <String, dynamic>{
              '_id': rhuId,
              'name': rhuName,
            },
      'barangay': barangayId == null
          ? null
          : <String, dynamic>{
              '_id': barangayId,
              'name': barangayName,
            },
      'transactionType': transactionType,
      'quantity': quantity,
      'previousStock': previousStock,
      'newStock': newStock,
      'batchNumber': batchNumber,
      'reason': reason,
      'remarks': remarks,
      'patientReference': patientReference,
      'source': source,
      'recordedBy': recordedById == null
          ? null
          : <String, dynamic>{
              '_id': recordedById,
              'fullName': recordedByName,
            },
      'clientGeneratedId': clientGeneratedId,
      'deviceId': deviceId,
      'syncStatus': syncStatus,
      'transactionDate': transactionDate?.toIso8601String(),
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