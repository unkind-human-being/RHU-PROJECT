import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/services/sync_service.dart';
import '../notifications/local_notification_service.dart';

const String medicineSyncTaskName = 'rhu_medicine_background_sync';

@pragma('vm:entry-point')
void medicineSyncCallbackDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? inputData) async {
    if (task != medicineSyncTaskName) {
      return true;
    }

    return MedicineSyncBackgroundWorker.run();
  });
}

class MedicineSyncBackgroundWorker {
  MedicineSyncBackgroundWorker._();

  static Future<bool> run() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      await Hive.initFlutter();

      await LocalNotificationService.initialize(
        requestPermission: false,
      );

      final SyncService syncService = SyncService();

      final pendingTransactions = await syncService.getPendingTransactions();

      if (pendingTransactions.isEmpty) {
        return true;
      }

      final SyncResult result =
          await syncService.syncPendingMedicineTransactions();

      if (result.success && result.successCount > 0) {
        await syncService.deleteSyncedTransactions();

        await LocalNotificationService.showMedicineSyncSuccess(
          syncedCount: result.successCount,
        );
      }

      return result.success;
    } catch (_) {
      return false;
    }
  }
}