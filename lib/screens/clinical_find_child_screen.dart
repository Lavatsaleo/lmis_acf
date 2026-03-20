import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/local/clinical/clinical_child_repo.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/remote/api_client.dart';
import '../data/remote/clinical_remote_sync_service.dart';
import '../data/local/isar/clinical_child.dart';
import 'clinical_child_detail_screen.dart';
import '../widgets/acf_brand.dart';

class ClinicalFindChildScreen extends StatefulWidget {
  const ClinicalFindChildScreen({super.key});

  @override
  State<ClinicalFindChildScreen> createState() => _ClinicalFindChildScreenState();
}

class _ClinicalFindChildScreenState extends State<ClinicalFindChildScreen> {
  final _repo = ClinicalChildRepo();
  final _settingsRepo = AppSettingsRepo();
  final _connectivity = Connectivity();
  final _remoteSync = ClinicalRemoteSyncService();

  final _q = TextEditingController();
  int _mode = 0; // 0=Local, 1=Server

  bool _loading = false;
  List<ClinicalChild> _results = const [];
  List<Map<String, dynamic>> _remote = const [];


  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  
Future<void> _search(String query) async {
  setState(() => _loading = true);
  try {
    if (_mode == 0) {
      final list = await _repo.search(query, limit: 50);
      if (!mounted) return;
      setState(() {
        _results = list;
        _remote = const [];
      });
    } else {
      final results = await _connectivity.checkConnectivity();
      final online = !results.contains(ConnectivityResult.none);
      if (!online) {
        if (!mounted) return;
        setState(() {
          _remote = const [];
          _results = const [];
        });
        return;
      }

      final baseUrl = await _settingsRepo.getBaseUrl();
      final api = ApiClient.create(baseUrl: baseUrl);

      final resp = await api.request(
        method: 'GET',
        path: '/api/clinical/children/search?q=${Uri.encodeQueryComponent(query)}',
      );

      final data = resp.data;
      final list = <Map<String, dynamic>>[];
      if (data is List) {
        for (final e in data) {
          if (e is Map) {
            list.add(e.cast<String, dynamic>());
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _remote = list;
        _results = const [];
      });
    }
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

Future<void> _importRemote(Map<String, dynamic> remote) async {
  try {
    final id = (remote['id'] ?? '').toString();
    if (id.isEmpty) return;

    final localChildId = await _remoteSync.importChildByRemoteId(id);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClinicalChildDetailScreen(localChildId: localChildId)),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
  }
}

@override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const AcfAppBar(title: 'Find child'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Local')),
                      ButtonSegment(value: 1, label: Text('Server')),
                    ],
                    selected: <int>{_mode},
                    onSelectionChanged: (s) {
                      setState(() => _mode = s.first);
                      _search(_q.text.trim());
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _q,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by name, CWC number, caregiver, phone…',
                suffixIcon: _q.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _q.clear();
                          _search('');
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (v) {
                setState(() {});
                _search(v);
              },
            ),
            const SizedBox(height: 12),
Expanded(
  child: _loading
      ? const Center(child: CircularProgressIndicator())
      : (_mode == 0)
          ? (_results.isEmpty
              ? Center(child: Text('No matches', style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final c = _results[i];
                    return ListTile(
                      tileColor: cs.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('${c.firstName} ${c.lastName}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(
                        [
                          if ((c.uniqueChildNumber ?? '').isNotEmpty) 'Reg#: ${c.uniqueChildNumber}',
                          if ((c.cwcNumber ?? '').isNotEmpty) 'CWC: ${c.cwcNumber}',
                          'Caregiver: ${c.caregiverName}',
                          if ((c.caregiverContacts).isNotEmpty) 'Tel: ${c.caregiverContacts}',
                        ].join(' • '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClinicalChildDetailScreen(localChildId: c.localChildId),
                          ),
                        );
                      },
                    );
                  },
                ))
          : (_remote.isEmpty
              ? Center(
                  child: Text(
                    'No server matches (or offline)',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  itemCount: _remote.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = _remote[i];
                    final fn = (r['firstName'] ?? r['childFirstName'] ?? '').toString();
                    final ln = (r['lastName'] ?? r['childLastName'] ?? '').toString();
                    final cwc = (r['cwcNumber'] ?? '').toString();
                    final reg = (r['uniqueChildNumber'] ?? '').toString();
                    return ListTile(
                      tileColor: cs.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('$fn $ln', style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(
                        [
                          if (reg.isNotEmpty) 'Reg#: $reg',
                          if (cwc.isNotEmpty) 'CWC: $cwc',
                        ].join(' • '),
                      ),
                      trailing: IconButton(
                        tooltip: 'Download to device',
                        icon: const Icon(Icons.download),
                        onPressed: () => _importRemote(r),
                      ),
                    );
                  },
                )),
),
          ],
        ),
      ),
    );
  }
}
