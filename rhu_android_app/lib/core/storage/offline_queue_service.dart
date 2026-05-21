import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class OfflineQueueService {
  static const String _boxName = 'rhu_offline_medicine_transactions';
  static const String _statusPending = 'pending';
  static const String _statusSynced = 'synced';
  static const String _statusFailed = 'failed';

  Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<dynamic>(_boxName);
    }

    return Hive.openBox<dynamic>(_boxName);
  }

  Future<OfflineMedicineTransaction> addMedicineTransaction({
    required String medicineId,
    required String medicineName,
    required String transactionType,
    required int quantity,
    required String reason,
    String remarks = '',
    String patientReference = '',
    String source = '',
    String deviceId = 'flutter-android-device',
  }) async {
    final Box<dynamic> box = await _openBox();

    final String id = const Uuid().v4();
    final String now = DateTime.now().toIso8601String();

    final OfflineMedicineTransaction transaction =
        OfflineMedicineTransaction(
      id: id,
      medicineId: medicineId,
      medicineName: medicineName,
      transactionType: transactionType,
      quantity: quantity,
      reason: reason,
      remarks: remarks,
      patientReference: patientReference,
      source: source,
      clientGeneratedId: 'offline-$id',
      deviceId: deviceId,
      status: _statusPending,
      createdAt: now,
      updatedAt: now,
      errorMessage: '',
    );

    await box.put(id, transaction.toJson());

    return transaction;
  }

  Future<List<OfflineMedicineTransaction>> getAllTransactions() async {
    final Box<dynamic> box = await _openBox();

    final List<OfflineMedicineTransaction> transactions =
        box.values.map((dynamic value) {
      if (value is Map) {
        return OfflineMedicineTransaction.fromJson(
          Map<String, dynamic>.from(value),
        );
      }

      return null;
    }).whereType<OfflineMedicineTransaction>().toList();

    transactions.sort(
      (
        OfflineMedicineTransaction first,
        OfflineMedicineTransaction second,
      ) {
        return second.createdAt.compareTo(first.createdAt);
      },
    );

    return transactions;
  }

  Future<List<OfflineMedicineTransaction>> getPendingTransactions() async {
    final List<OfflineMedicineTransaction> transactions =
        await getAllTransactions();

    return transactions.where((OfflineMedicineTransaction transaction) {
      return transaction.status == _statusPending ||
          transaction.status == _statusFailed;
    }).toList();
  }

  Future<int> getPendingCount() async {
    final List<OfflineMedicineTransaction> pending =
        await getPendingTransactions();

    return pending.length;
  }

  Future<void> markAsSynced(String id) async {
    final Box<dynamic> box = await _openBox();

    final dynamic existingValue = box.get(id);

    if (existingValue is! Map) {
      return;
    }

    final OfflineMedicineTransaction transaction =
        OfflineMedicineTransaction.fromJson(
      Map<String, dynamic>.from(existingValue),
    );

    await box.put(
      id,
      transaction
          .copyWith(
            status: _statusSynced,
            errorMessage: '',
            updatedAt: DateTime.now().toIso8601String(),
          )
          .toJson(),
    );
  }

  Future<void> markAsFailed({
    required String id,
    required String errorMessage,
  }) async {
    final Box<dynamic> box = await _openBox();

    final dynamic existingValue = box.get(id);

    if (existingValue is! Map) {
      return;
    }

    final OfflineMedicineTransaction transaction =
        OfflineMedicineTransaction.fromJson(
      Map<String, dynamic>.from(existingValue),
    );

    await box.put(
      id,
      transaction
          .copyWith(
            status: _statusFailed,
            errorMessage: errorMessage,
            updatedAt: DateTime.now().toIso8601String(),
          )
          .toJson(),
    );
  }

  Future<void> deleteTransaction(String id) async {
    final Box<dynamic> box = await _openBox();

    await box.delete(id);
  }

  Future<void> deleteSyncedTransactions() async {
    final Box<dynamic> box = await _openBox();
    final List<OfflineMedicineTransaction> transactions =
        await getAllTransactions();

    for (final OfflineMedicineTransaction transaction in transactions) {
      if (transaction.status == _statusSynced) {
        await box.delete(transaction.id);
      }
    }
  }

  Future<void> clearAll() async {
    final Box<dynamic> box = await _openBox();

    await box.clear();
  }
}

class OfflineMedicineTransaction {
  const OfflineMedicineTransaction({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.transactionType,
    required this.quantity,
    required this.reason,
    required this.remarks,
    required this.patientReference,
    required this.source,
    required this.clientGeneratedId,
    required this.deviceId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.errorMessage,
  });

  final String id;
  final String medicineId;
  final String medicineName;
  final String transactionType;
  final int quantity;
  final String reason;
  final String remarks;
  final String patientReference;
  final String source;
  final String clientGeneratedId;
  final String deviceId;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String errorMessage;

  bool get isPending => status == 'pending';
  bool get isSynced => status == 'synced';
  bool get isFailed => status == 'failed';

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

  Map<String, dynamic> toSyncJson() {
    return <String, dynamic>{
      'medicine': medicineId,
      'transactionType': transactionType,
      'quantity': quantity,
      'reason': reason,
      'remarks': remarks,
      'patientReference': patientReference,
      'source': source,
      'clientGeneratedId': clientGeneratedId,
      'deviceId': deviceId,
      'offlineCreatedAt': createdAt,
    };
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'transactionType': transactionType,
      'quantity': quantity,
      'reason': reason,
      'remarks': remarks,
      'patientReference': patientReference,
      'source': source,
      'clientGeneratedId': clientGeneratedId,
      'deviceId': deviceId,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'errorMessage': errorMessage,
    };
  }

  factory OfflineMedicineTransaction.fromJson(Map<String, dynamic> json) {
    return OfflineMedicineTransaction(
      id: _readString(json['id']),
      medicineId: _readString(json['medicineId']),
      medicineName: _readString(json['medicineName']),
      transactionType: _readString(json['transactionType']),
      quantity: _readInt(json['quantity']),
      reason: _readString(json['reason']),
      remarks: _readString(json['remarks']),
      patientReference: _readString(json['patientReference']),
      source: _readString(json['source']),
      clientGeneratedId: _readString(json['clientGeneratedId']),
      deviceId: _readString(json['deviceId']),
      status: _readString(json['status'], fallback: 'pending'),
      createdAt: _readString(json['createdAt']),
      updatedAt: _readString(json['updatedAt']),
      errorMessage: _readString(json['errorMessage']),
    );
  }

  OfflineMedicineTransaction copyWith({
    String? id,
    String? medicineId,
    String? medicineName,
    String? transactionType,
    int? quantity,
    String? reason,
    String? remarks,
    String? patientReference,
    String? source,
    String? clientGeneratedId,
    String? deviceId,
    String? status,
    String? createdAt,
    String? updatedAt,
    String? errorMessage,
  }) {
    return OfflineMedicineTransaction(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      medicineName: medicineName ?? this.medicineName,
      transactionType: transactionType ?? this.transactionType,
      quantity: quantity ?? this.quantity,
      reason: reason ?? this.reason,
      remarks: remarks ?? this.remarks,
      patientReference: patientReference ?? this.patientReference,
      source: source ?? this.source,
      clientGeneratedId: clientGeneratedId ?? this.clientGeneratedId,
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
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
}