import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/local/isar/isar_service.dart';
import 'sync_service.dart';

class BackgroundSyncService {
  static const String taskName = 'lmis_background_two_way_sync';
  static const String uniqueName = 'lmis_background_two_way_sync_periodic';

  const BackgroundSyncService._();

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 10),
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await IsarService.instance.init();

      final syncService = SyncService();
      await syncService.forceSyncNow(limit: 100);
      return true;
    } catch (_) {
      // Returning false tells WorkManager that the task can be retried later.
      return false;
    }
  });
}
