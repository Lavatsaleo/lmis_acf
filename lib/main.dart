import 'package:flutter/material.dart';

import 'core/sync/background_sync_service.dart';
import 'data/local/isar/isar_service.dart';
import 'lmis_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarService.instance.init();

  // Background sync is best-effort. The app must still open even if Android
  // refuses or delays background work on a specific device.
  try {
    await BackgroundSyncService.initialize();
  } catch (_) {
    // Foreground auto-sync remains active through MainShell.
  }

  runApp(const LmisApp());
}
