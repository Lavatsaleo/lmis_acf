import 'package:flutter/material.dart';

import '../../core/access/user_access.dart';
import '../../data/local/settings/app_settings_repo.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/sample_api.dart';
import '../../widgets/anchor_ui.dart';
import 'sample_consignment_screen.dart';
import 'sample_scanner_page.dart';

/// Research samples, for the step this user does:
/// - field base: receive tubes from the sites, pack consignments, send to Juba
/// - main warehouse (Juba): receive consignments, ship them to the laboratory
/// - laboratory: receive consignments and check every tube
class SamplesHomeScreen extends StatefulWidget {
  final UserAccess access;
  const SamplesHomeScreen({super.key, required this.access});

  @override
  State<SamplesHomeScreen> createState() => _SamplesHomeScreenState();
}

class _SamplesHomeScreenState extends State<SamplesHomeScreen> {
  SampleApi? _api;
  bool _loading = true;
  String? _error;
  List<ConsignmentDto> _consignments = const [];
  List<SampleDto> _expected = const [];
  List<SampleDto> _atBase = const [];

  UserAccess get a => widget.access;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<SampleApi> _client() async => _api ??= SampleApi(ApiClient.create(baseUrl: await AppSettingsRepo().getBaseUrl()));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = await _client();
      final consignments = await api.consignments();
      if (a.canSamplesBase) {
        final r = await api.expected();
        _expected = r.expected;
        _atBase = r.atBase;
      }
      if (mounted) setState(() => _consignments = consignments);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, action: 'Loading samples'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openConsignment(String ref) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SampleConsignmentScreen(access: a, reference: ref)));
    if (mounted) _load();
  }

  Future<void> _receiveTubes() async {
    final api = await _client();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SampleScannerPage(
          title: 'Receive tubes',
          hint: 'Scan each tube that arrived from the sites. Tubes are packed into a consignment afterwards.',
          onScan: (code) async {
            try {
              final r = await api.receiveTube(code);
              final s = r.sample;
              if (r.already) return ScanOutcome.ok('Already received', s.subtitle);
              return ScanOutcome.ok('Received ${s.barcode}', [s.site, s.subtitle, ...r.notices].where((x) => x.isNotEmpty).join(' · '));
            } catch (e) {
              return ScanOutcome.problem('Not received', friendlyError(e));
            }
          },
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _newConsignment() async {
    try {
      final api = await _client();
      final d = await api.createConsignment();
      if (!mounted) return;
      await _openConsignment(d.consignment.id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, action: 'Starting a consignment'))));
    }
  }

  Future<void> _scanConsignment() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SampleScannerPage(title: 'Scan consignment', hint: 'Scan the QR label on the consignment.')),
    );
    if (raw == null || !mounted) return;
    await _openConsignment(consignmentCodeOf(raw));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final waiting = _consignments.where((c) => c.nextAction.isNotEmpty).toList();
    final others = _consignments.where((c) => c.nextAction.isEmpty).toList();
    final title = a.canSamplesLab ? 'Samples · laboratory' : a.canSamplesHub ? 'Samples · Juba' : 'Samples · field base';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: AnchorNotice(_error!, icon: Icons.error_outline, warning: true)),
            if (a.canSamplesBase) ...[
              Row(
                children: [
                  Expanded(child: AnchorStat(label: 'Expected from sites', value: formatCount(_expected.length), icon: Icons.schedule)),
                  const SizedBox(width: 10),
                  Expanded(child: AnchorStat(label: 'Here, not packed', value: formatCount(_atBase.length), icon: Icons.science_outlined)),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _receiveTubes, icon: const Icon(Icons.qr_code_scanner), label: const Text('Receive tubes')),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _newConsignment, icon: const Icon(Icons.inventory_2_outlined), label: const Text('Pack a new consignment')),
            ] else ...[
              FilledButton.icon(onPressed: _scanConsignment, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan a consignment')),
              const SizedBox(height: 6),
              Text(
                a.canSamplesLab ? 'Scan the label to receive a consignment, then check its tubes.' : 'Scan the label to receive a consignment from a base, or to ship it to the laboratory.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            if (!_loading && waiting.isNotEmpty) ...[
              AnchorSectionTitle(a.canSamplesBase ? 'Being packed' : 'Waiting for you'),
              ...waiting.map((c) => _ConsignmentTile(c: c, onTap: () => _openConsignment(c.id))),
            ],
            if (!_loading && others.isNotEmpty) ...[
              const AnchorSectionTitle('Other consignments'),
              ...others.map((c) => _ConsignmentTile(c: c, onTap: () => _openConsignment(c.id))),
            ],
            if (!_loading && _consignments.isEmpty && _error == null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('No consignments yet.', style: TextStyle(color: cs.onSurfaceVariant))),
            if (a.canSamplesBase && !_loading && _expected.isNotEmpty) ...[
              const SizedBox(height: 8),
              AnchorSectionTitle('Expected from sites', subtitle: 'Collected and recorded in DHIS2, not received here yet'),
              ..._expected.take(50).map((s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.science_outlined),
                    title: Text(s.barcode, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${s.site} · ${s.subtitle}'),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConsignmentTile extends StatelessWidget {
  final ConsignmentDto c;
  final VoidCallback onTap;
  const _ConsignmentTile({required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text(c.code, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text([c.statusLabel, '${c.tubes} tube${c.tubes == 1 ? '' : 's'}', if (c.originName.isNotEmpty) c.originName, if (c.updatedLabel.isNotEmpty) c.updatedLabel].join(' · ')),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
