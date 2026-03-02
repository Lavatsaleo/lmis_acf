import 'package:flutter/material.dart';

import '../data/local/sync/sync_queue_repo.dart';
import 'home_screen.dart';
import 'queue_inspector_screen.dart';
import 'scan_hub_screen.dart';
import 'profile_screen.dart';

/// Step 6: Bottom navigation shell.
///
/// Keeps the app feeling like a real product (Dashboard / Scan / Queue / Profile)
/// while preserving your existing screens and offline-first logic.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final SyncQueueRepo _queueRepo = SyncQueueRepo();

  late final List<Widget> _pages = const [
    HomeScreen(),
    ScanHubScreen(),
    QueueInspectorScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncQueueCounts>(
      stream: _queueRepo.watchCounts(),
      builder: (context, snapshot) {
        final counts = snapshot.data ?? const SyncQueueCounts(pending: 0, failed: 0, sent: 0);
        final pending = counts.pending;

        return Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: IndexedStack(
              key: ValueKey<int>(_index),
              index: _index,
              children: _pages,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              const NavigationDestination(
                icon: Icon(Icons.qr_code_scanner_outlined),
                selectedIcon: Icon(Icons.qr_code_scanner),
                label: 'Scan',
              ),
              NavigationDestination(
                icon: _NavBadge(
                  show: pending > 0,
                  count: pending,
                  child: const Icon(Icons.sync_outlined),
                ),
                selectedIcon: _NavBadge(
                  show: pending > 0,
                  count: pending,
                  child: const Icon(Icons.sync),
                ),
                label: 'Queue',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavBadge extends StatelessWidget {
  final bool show;
  final int count;
  final Widget child;

  const _NavBadge({required this.show, required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!show) return child;

    final cs = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.error,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cs.surface, width: 1.5),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: cs.onError,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
