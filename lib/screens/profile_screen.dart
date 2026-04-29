import 'package:flutter/material.dart';

import '../data/local/auth/session_store.dart';
import '../data/local/auth/token_store.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../widgets/acf_brand.dart';
import '../widgets/app_version_badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SessionStore _sessionStore = SessionStore();
  final TokenStore _tokenStore = const TokenStore();
  final SyncQueueRepo _syncQueueRepo = SyncQueueRepo();

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

  Future<void> _logout() async {
    final queueCounts = await _syncQueueRepo.counts();
    final hasUnsentData = queueCounts.pending > 0 || queueCounts.failed > 0;

    if (hasUnsentData) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot logout. This phone has ${queueCounts.pending + queueCounts.failed} unsynced item(s). Sync first.',
          ),
        ),
      );
      return;
    }

    await _tokenStore.clear();
    await _sessionStore.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final me = _me ?? <String, dynamic>{};
    final name = (me['name'] ?? me['fullName'] ?? me['email'] ?? 'User').toString();
    final email = (me['email'] ?? '').toString();
    final role = (me['role'] ?? '').toString();
    final facilityName = (me['facilityName'] ?? '').toString();

    return Scaffold(
      appBar: AcfAppBar(
        title: 'Profile',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const AcfLogo(size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        if (role.isNotEmpty)
                          Text(
                            role,
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        if (facilityName.isNotEmpty)
                          Text(
                            facilityName,
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Application version', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const AppVersionBadge(textAlign: TextAlign.left, showAppName: true),
                  const SizedBox(height: 8),
                  Text(
                    'Use this version and build number when reporting issues from the field.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('App security', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    'This mobile app uses a fixed secured backend endpoint. Users cannot change the backend URL from inside the app. The app also blocks logout when there is unsynced local data.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
