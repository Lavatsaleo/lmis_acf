import 'package:flutter/material.dart';

import '../core/access/user_access.dart';
import '../core/sync/auto_sync_service.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../data/remote/api_client.dart';
import '../data/remote/auth_api.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'queue_inspector_screen.dart';

/// Bottom navigation: Home, Sync (only for users who work offline) and Account.
///
/// Every task starts from Home, so there is one way to reach each screen.
/// Warehouse officers work online and have no sync queue, so no Sync tab.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;

  final SyncQueueRepo _queueRepo = SyncQueueRepo();
  final SessionStore _sessionStore = SessionStore();
  final AutoSyncService _autoSyncService = AutoSyncService.instance;

  UserAccess? _access;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoSyncService.start();
    _loadAccess();
  }

  /// The saved profile, refreshed from the server when online, so a change
  /// of role, location or country settings reaches the phone without signing
  /// out (and an app update picks up fields older builds did not save).
  Future<void> _loadAccess() async {
    var me = await _sessionStore.readUserJson();
    try {
      final api = ApiClient.create(baseUrl: await AppSettingsRepo().getBaseUrl());
      final fresh = await AuthApi(api).fetchMe().timeout(const Duration(seconds: 6));
      final sameUser = me == null || (fresh['id'] ?? '').toString() == (me['id'] ?? '').toString();
      if (fresh.isNotEmpty && sameUser) {
        me = {...?me, ...fresh};
        await _sessionStore.saveUserJson(me);
      }
    } catch (_) {
      // Offline or server unreachable: keep working with the saved profile.
    }
    if (mounted) setState(() => _access = UserAccess.fromUserJson(me));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSyncService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _autoSyncService.forceSync(reason: 'app_resumed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    if (access == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final showSync = access.usesOfflineQueue;
    final pages = <Widget>[
      HomeScreen(onOpenSync: showSync ? () => setState(() => _index = 1) : null),
      if (showSync) const QueueInspectorScreen(),
      const ProfileScreen(),
    ];
    final index = _index.clamp(0, pages.length - 1);

    return StreamBuilder<SyncQueueCounts>(
      stream: _queueRepo.watchCounts(),
      builder: (context, snapshot) {
        final counts = snapshot.data ?? const SyncQueueCounts(pending: 0, failed: 0, sent: 0);
        final waiting = counts.pending + counts.failed;

        return Scaffold(
          body: IndexedStack(index: index, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
              if (showSync)
                NavigationDestination(
                  icon: Badge(isLabelVisible: waiting > 0, label: Text(waiting > 99 ? '99+' : '$waiting'), child: const Icon(Icons.sync_outlined)),
                  selectedIcon: Badge(isLabelVisible: waiting > 0, label: Text(waiting > 99 ? '99+' : '$waiting'), child: const Icon(Icons.sync)),
                  label: 'Sync',
                ),
              const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
            ],
          ),
        );
      },
    );
  }
}
