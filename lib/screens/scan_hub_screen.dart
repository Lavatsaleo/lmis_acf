import 'package:flutter/material.dart';

import '../data/local/auth/session_store.dart';
import 'box_lookup_screen.dart';
import 'dispatch_screen.dart';
import 'facility_receive_screen.dart';
import 'facility_store_screen.dart';
import '../widgets/acf_brand.dart';
import '../widgets/acf_tiles.dart';

/// A simple "Scan" hub that routes users to the right transaction screens.
///
/// This keeps the UX clean: users tap Scan tab → choose Dispatch or Receive.
class ScanHubScreen extends StatefulWidget {
  const ScanHubScreen({super.key});

  @override
  State<ScanHubScreen> createState() => _ScanHubScreenState();
}

class _ScanHubScreenState extends State<ScanHubScreen> {
  final SessionStore _sessionStore = SessionStore();

  bool _loading = true;
  Map<String, dynamic>? _me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await _sessionStore.readUserJson();
    if (!mounted) return;
    setState(() {
      _me = me;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final role = (_me?['role'] ?? '').toString();
    final canDispatch = role == 'WAREHOUSE_OFFICER' || role == 'SUPER_ADMIN';
    final canReceive = role == 'FACILITY_OFFICER' || role == 'CLINICIAN' || role == 'SUPER_ADMIN';
    final canStore = canReceive;

    return Scaffold(
      appBar: const AcfAppBar(title: 'Scan'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick transactions',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose what you are doing. Scans are saved offline and synced later.',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AcfActionTile(
            title: 'Dispatch shipment',
            subtitle: 'Warehouse → Facility (queues DISPATCH)',
            icon: Icons.local_shipping_outlined,
            enabled: canDispatch,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DispatchScreen())),
          ),
          const SizedBox(height: 10),
          AcfActionTile(
            title: 'Receive shipment',
            subtitle: 'Manifest-driven receiving (preloaded expected boxes)',
            icon: Icons.inventory_2_outlined,
            enabled: canReceive,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacilityReceiveScreen())),
          ),
          const SizedBox(height: 10),
          AcfActionTile(
            title: 'Facility store',
            subtitle: 'Boxes & sachets in store (select active box for dispensing)',
            icon: Icons.storefront_outlined,
            enabled: canStore,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacilityStoreScreen())),
          ),
          const SizedBox(height: 10),
          AcfActionTile(
            title: 'Box lookup',
            subtitle: 'Scan or search a box → status + pending offline actions',
            icon: Icons.search_outlined,
            enabled: true,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BoxLookupScreen())),
          ),
          if (!canDispatch || !canReceive) ...[
            const SizedBox(height: 12),
            Text(
              'Some actions are disabled based on your role ($role).',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tip', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    'If you see “Unknown in local cache”, go to Dashboard → Offline cache and download boxes for the relevant facility/warehouse.\n\nEven if offline cache is incomplete, you can still queue scans — the backend will validate during sync.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// _ActionTile replaced by shared AcfActionTile.
