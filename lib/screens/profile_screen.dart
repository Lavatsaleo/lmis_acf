import 'package:flutter/material.dart';

import '../core/access/user_access.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/auth/token_store.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../widgets/anchor_brand.dart';
import '../widgets/anchor_ui.dart';
import '../widgets/app_version_badge.dart';
import 'change_password_screen.dart';

/// Account: who is signed in, where, and sign out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SessionStore _sessionStore = SessionStore();
  final TokenStore _tokenStore = const TokenStore();
  final SyncQueueRepo _syncQueueRepo = SyncQueueRepo();

  UserAccess? _access;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await _sessionStore.readUserJson();
    if (!mounted) return;
    setState(() => _access = UserAccess.fromUserJson(me));
  }

  Future<void> _logout() async {
    final queueCounts = await _syncQueueRepo.counts();
    final unsent = queueCounts.pending + queueCounts.failed;
    if (!mounted) return;

    if (unsent > 0) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sync before signing out'),
          content: Text(
            'This phone has $unsent record(s) that are not on the server yet. '
            'Signing out now would put them at risk. Open Sync and send them first.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your email and password to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;

    await _tokenStore.clear();
    await _sessionStore.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = _access;
    if (a == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    Widget row(IconData icon, String label, String value) => ListTile(
          leading: Icon(icon, color: cs.primary),
          title: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          subtitle: Text(value.isEmpty ? '—' : value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cs.onSurface)),
        );

    return Scaffold(
      appBar: const AnchorAppBar(title: 'Account'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: anchorGradient, borderRadius: BorderRadius.circular(22)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white,
                  child: Text(
                    a.firstName.isEmpty ? '?' : a.firstName[0].toUpperCase(),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: cs.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.fullName.isEmpty ? a.email : a.fullName,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(a.roleLabel, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                row(Icons.email_outlined, 'Email', a.email),
                const Divider(height: 1),
                row(Icons.place_outlined, 'Location', a.locationName.isEmpty ? (a.platform.countryName.isEmpty ? 'All locations' : 'All of ${a.platform.countryName}') : a.locationName),
                if (a.platform.displayName.isNotEmpty) ...[
                  const Divider(height: 1),
                  row(Icons.flag_outlined, 'Country / programme', a.platform.displayName),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.lock_reset, color: cs.primary),
              title: const Text('Change password', style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(foregroundColor: cs.error, side: BorderSide(color: cs.error.withValues(alpha: 0.5))),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 20),
          const AppVersionBadge(),
          const SizedBox(height: 4),
          Text('Quote this version when reporting a problem.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
