import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String _medicineInventoryBox = 'rhu_local_medicine_inventory';

  Future<Box<dynamic>> _openMedicineBox() async {
    if (Hive.isBoxOpen(_medicineInventoryBox)) {
      return Hive.box<dynamic>(_medicineInventoryBox);
    }

    return Hive.openBox<dynamic>(_medicineInventoryBox);
  }

  Future<void> saveMedicineInventory({
    required String cacheKey,
    required List<Map<String, dynamic>> medicines,
  }) async {
    final Box<dynamic> box = await _openMedicineBox();

    await box.put(cacheKey, <String, dynamic>{
      'savedAt': DateTime.now().toIso8601String(),
      'medicines': medicines,
    });
  }

  Future<List<Map<String, dynamic>>> getMedicineInventory({
    required String cacheKey,
  }) async {
    final Box<dynamic> box = await _openMedicineBox();

    final dynamic cachedValue = box.get(cacheKey);

    if (cachedValue is! Map) {
      return <Map<String, dynamic>>[];
    }

    final dynamic medicinesValue = cachedValue['medicines'];

    if (medicinesValue is! List) {
      return <Map<String, dynamic>>[];
    }

    return medicinesValue
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<DateTime?> getMedicineInventoryLastSavedAt({
    required String cacheKey,
  }) async {
    final Box<dynamic> box = await _openMedicineBox();

    final dynamic cachedValue = box.get(cacheKey);

    if (cachedValue is! Map) {
      return null;
    }

    final dynamic savedAt = cachedValue['savedAt'];

    if (savedAt == null) {
      return null;
    }

    return DateTime.tryParse(savedAt.toString());
  }

  Future<void> updateMedicineInAllCachedInventories({
    required Map<String, dynamic> medicine,
  }) async {
    final Box<dynamic> box = await _openMedicineBox();
    final String medicineId = _readMedicineId(medicine);

    if (medicineId.isEmpty) {
      return;
    }

    for (final dynamic key in box.keys) {
      final dynamic cachedValue = box.get(key);

      if (cachedValue is! Map) {
        continue;
      }

      final dynamic medicinesValue = cachedValue['medicines'];

      if (medicinesValue is! List) {
        continue;
      }

      final List<Map<String, dynamic>> medicines = medicinesValue
          .whereType<Map>()
          .map((Map item) => Map<String, dynamic>.from(item))
          .toList();

      final int index = medicines.indexWhere((Map<String, dynamic> item) {
        return _readMedicineId(item) == medicineId;
      });

      if (index == -1) {
        continue;
      }

      medicines[index] = medicine;

      await box.put(key, <String, dynamic>{
        'savedAt': DateTime.now().toIso8601String(),
        'medicines': medicines,
      });
    }
  }

  Future<void> addMedicineToAllCachedInventories({
    required Map<String, dynamic> medicine,
  }) async {
    final Box<dynamic> box = await _openMedicineBox();
    final String medicineId = _readMedicineId(medicine);

    if (medicineId.isEmpty) {
      return;
    }

    for (final dynamic key in box.keys) {
      final dynamic cachedValue = box.get(key);

      if (cachedValue is! Map) {
        continue;
      }

      final dynamic medicinesValue = cachedValue['medicines'];

      if (medicinesValue is! List) {
        continue;
      }

      final List<Map<String, dynamic>> medicines = medicinesValue
          .whereType<Map>()
          .map((Map item) => Map<String, dynamic>.from(item))
          .toList();

      final bool alreadyExists = medicines.any((Map<String, dynamic> item) {
        return _readMedicineId(item) == medicineId;
      });

      if (!alreadyExists) {
        medicines.insert(0, medicine);
      }

      await box.put(key, <String, dynamic>{
        'savedAt': DateTime.now().toIso8601String(),
        'medicines': medicines,
      });
    }
  }

  Future<void> removeMedicineFromAllCachedInventories({
    required String medicineId,
  }) async {
    final Box<dynamic> box = await _openMedicineBox();

    if (medicineId.trim().isEmpty) {
      return;
    }

    for (final dynamic key in box.keys) {
      final dynamic cachedValue = box.get(key);

      if (cachedValue is! Map) {
        continue;
      }

      final dynamic medicinesValue = cachedValue['medicines'];

      if (medicinesValue is! List) {
        continue;
      }

      final List<Map<String, dynamic>> medicines = medicinesValue
          .whereType<Map>()
          .map((Map item) => Map<String, dynamic>.from(item))
          .where((Map<String, dynamic> item) {
        return _readMedicineId(item) != medicineId;
      }).toList();

      await box.put(key, <String, dynamic>{
        'savedAt': DateTime.now().toIso8601String(),
        'medicines': medicines,
      });
    }
  }

  Future<void> clearMedicineInventory({
    required String cacheKey,
  }) async {
    final Box<dynamic> box = await _openMedicineBox();

    await box.delete(cacheKey);
  }

  Future<void> clearAllMedicineInventory() async {
    final Box<dynamic> box = await _openMedicineBox();

    await box.clear();
  }

  String _readMedicineId(Map<String, dynamic> medicine) {
    final dynamic id = medicine['_id'] ?? medicine['id'];

    if (id == null) {
      return '';
    }

    return id.toString();
  }


  Future<void> updateMedicineStockInAllCachedInventories({
    required String medicineId,
    required int newStock,
  }) async {
    final Box<dynamic> box = await _openMedicineBox();

    if (medicineId.trim().isEmpty) {
      return;
    }

    for (final dynamic key in box.keys) {
      final dynamic cachedValue = box.get(key);

      if (cachedValue is! Map) {
        continue;
      }

      final dynamic medicinesValue = cachedValue['medicines'];

      if (medicinesValue is! List) {
        continue;
      }

      final List<Map<String, dynamic>> medicines = medicinesValue
          .whereType<Map>()
          .map((Map item) => Map<String, dynamic>.from(item))
          .toList();

      bool changed = false;

      for (int index = 0; index < medicines.length; index++) {
        final Map<String, dynamic> medicine = medicines[index];
        final dynamic id = medicine['_id'] ?? medicine['id'];

        if (id != null && id.toString() == medicineId) {
          medicines[index] = <String, dynamic>{
            ...medicine,
            'currentStock': newStock,
            'updatedAt': DateTime.now().toIso8601String(),
          };

          changed = true;
        }
      }

      if (changed) {
        await box.put(key, <String, dynamic>{
          'savedAt': DateTime.now().toIso8601String(),
          'medicines': medicines,
        });
      }
    }
  }


}