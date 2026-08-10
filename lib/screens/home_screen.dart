import 'package:flutter/material.dart';

import '../data/local/auth/session_store.dart';
import '../core/platform/platform_context.dart';
import 'clinical_home_screen.dart';
import 'warehouse_screen.dart';
import '../widgets/acf_brand.dart';
import '../widgets/acf_tiles.dart';

/// Home (Module selector)
///
/// After login, users first choose which module they want to work in:
/// - Warehouse (LMIS movements: receive/dispatch/lookup/sync)
/// - Clinical (patient workflow: enrollment, anthropometry, dispensing and follow-ups)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

    final fullName = (_me?['fullName'] ?? _me?['name'] ?? '').toString().trim();
    final email = (_me?['email'] ?? '').toString().trim();
    final role = (_me?['role'] ?? '').toString().trim();
    final platform = PlatformContext.fromUserJson(_me);

    final logisticsEnabled = platform.isModuleEnabled('LOGISTICS');
    final clinicalEnabled = platform.isModuleEnabled('CLINICAL');

    // Role controls what this user can do inside an enabled implementation.
    // The implementation controls whether that module exists at all.
    final canWarehouse = logisticsEnabled &&
        (role == 'WAREHOUSE_OFFICER' || role == 'FACILITY_OFFICER' || role == 'SUPER_ADMIN');
    final canClinical = clinicalEnabled &&
        (role == 'CLINICIAN' || role == 'FACILITY_OFFICER' || role == 'SUPER_ADMIN');

    return Scaffold(
      appBar: const AcfAppBar(title: 'Dashboard'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary.withOpacity(0.08),
                    cs.secondary.withOpacity(0.08),
                  ],
                ),
              ),
              child: Row(
                children: [
                  const AcfLogo(size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isNotEmpty ? fullName : 'Welcome back',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email.isNotEmpty ? '$email  •  $role' : role,
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (platform.displayName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            platform.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose a module',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: cs.onSurface),
          ),
          const SizedBox(height: 8),

          if (logisticsEnabled) ...[
            AcfActionTile(
              title: 'Warehouse',
              subtitle: 'Receive, dispatch, box lookup, offline cache + sync queue.',
              icon: Icons.warehouse_outlined,
              enabled: canWarehouse,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WarehouseScreen()),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (clinicalEnabled)
            AcfActionTile(
              title: 'Clinical',
              subtitle: 'Child enrollment, anthropometry, dispensing and follow-ups.',
              icon: Icons.medical_services_outlined,
              enabled: canClinical,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClinicalHomeScreen()),
              ),
            ),

          if (!logisticsEnabled && !clinicalEnabled)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No currently supported mobile modules are enabled for this implementation.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),

          const SizedBox(height: 14),
          Card(
            color: cs.surfaceVariant,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Tip: Even when offline, you can continue working. Actions are saved locally and synced later when online.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// _ModuleCard replaced by shared AcfActionTile.
