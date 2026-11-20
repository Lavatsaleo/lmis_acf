import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/access/user_access.dart';
import '../../data/local/auth/token_store.dart';
import '../../data/local/settings/app_settings_repo.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/sample_api.dart';
import '../../utils/remote_pdf.dart';
import '../../widgets/anchor_ui.dart';
import 'sample_scanner_page.dart';

/// One consignment: its tubes, its journey, and the next step for this user
/// (pack and send, receive in Juba, ship to the laboratory, receive and check).
class SampleConsignmentScreen extends StatefulWidget {
  final UserAccess access;
  /// Consignment id, code, or the scanned QR text.
  final String reference;
  const SampleConsignmentScreen({super.key, required this.access, required this.reference});

  @override
  State<SampleConsignmentScreen> createState() => _SampleConsignmentScreenState();
}

class _SampleConsignmentScreenState extends State<SampleConsignmentScreen> {
  SampleApi? _api;
  ConsignmentDetailDto? _d;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<SampleApi> _client() async => _api ??= SampleApi(ApiClient.create(baseUrl: await AppSettingsRepo().getBaseUrl()));

  String get _ref => _d?.consignment.id ?? widget.reference;

  Future<void> _load() async {
    try {
      final d = await (await _client()).consignment(_ref);
      if (mounted) {
        setState(() {
          _d = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, action: 'Opening the consignment'));
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<ConsignmentDetailDto> Function(SampleApi api) step, String done) async {
    setState(() => _busy = true);
    try {
      final d = await step(await _client());
      if (!mounted) return;
      setState(() => _d = d);
      _toast(done);
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action))],
      ),
    );
    return ok == true;
  }

  Future<void> _packTubes() async {
    final api = await _client();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SampleScannerPage(
          title: 'Pack ${_d!.consignment.code}',
          hint: 'Scan each tube as you put it in the consignment.',
          onScan: (code) async {
            try {
              final r = await api.packTube(_ref, code);
              if (r.already) return ScanOutcome.ok('Already in this consignment', r.sample.subtitle);
              return ScanOutcome.ok('Packed ${r.sample.barcode} · ${r.tubes ?? ''} in total', [r.sample.site, r.sample.subtitle, ...r.notices].where((x) => x.isNotEmpty).join(' · '));
            } catch (e) {
              return ScanOutcome.problem('Not packed', friendlyError(e));
            }
          },
        ),
      ),
    );
    await _load();
  }

  Future<void> _checkTubes() async {
    final api = await _client();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SampleScannerPage(
          title: 'Check ${_d!.consignment.code}',
          hint: 'Scan every tube in the consignment. Tubes not listed in it are flagged.',
          onScan: (code) async {
            try {
              final r = await api.checkTube(_ref, code);
              final left = r.remaining == null ? '' : ' · ${r.remaining} left';
              return ScanOutcome.ok(r.already ? 'Already checked' : 'Arrived ${r.sample.barcode}$left', r.sample.subtitle);
            } catch (e) {
              return ScanOutcome.problem('Check this tube', friendlyError(e));
            }
          },
        ),
      ),
    );
    await _load();
  }

  Future<void> _printLabel() async {
    setState(() => _busy = true);
    try {
      final pdf = await RemotePdf.downloadPdfBytes(
        baseUrl: await AppSettingsRepo().getBaseUrl(),
        pathOrUrl: SampleApi.labelPath(_ref),
        accessToken: await const TokenStore().readAccessToken(),
      );
      await Printing.layoutPdf(onLayout: (_) async => pdf, name: '${_d?.consignment.code ?? 'consignment'}.pdf');
    } catch (e) {
      if (mounted) _toast(friendlyError(e, action: 'Printing the label'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shipToLab() async {
    final ctrl = TextEditingController();
    final tracking = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ship to the laboratory'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Courier / air waybill number (optional)')),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Shipped'))],
      ),
    );
    if (tracking == null) return;
    await _run((api) => api.shipToLab(_ref, tracking), 'Marked as shipped to the laboratory');
  }

  Widget _actions(ConsignmentDetailDto d) {
    final c = d.consignment;
    final buttons = <Widget>[];
    switch (c.nextAction) {
      case 'PACK':
        buttons.addAll([
          FilledButton.icon(onPressed: _busy ? null : _packTubes, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan tubes into it')),
          OutlinedButton.icon(onPressed: _busy ? null : _printLabel, icon: const Icon(Icons.print_outlined), label: const Text('Print QR label')),
          OutlinedButton.icon(
            onPressed: _busy || d.samples.isEmpty
                ? null
                : () async {
                    if (await _confirm('Send to Juba?', '${d.samples.length} tube(s). No tubes can be added after sending. Stick the QR label on the consignment first.', 'Send')) {
                      await _run((api) => api.sendToJuba(_ref), 'Sent to Juba');
                    }
                  },
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Send to Juba'),
          ),
        ]);
      case 'RECEIVE_JUBA':
        buttons.add(FilledButton.icon(onPressed: _busy ? null : () => _run((api) => api.receiveConsignment(_ref), 'Received in Juba'), icon: const Icon(Icons.move_to_inbox_outlined), label: const Text('Receive in Juba')));
      case 'SEND_TO_LAB':
        buttons.add(FilledButton.icon(onPressed: _busy ? null : _shipToLab, icon: const Icon(Icons.flight_takeoff), label: const Text('Ship to the laboratory')));
      case 'RECEIVE_LAB':
        buttons.add(FilledButton.icon(onPressed: _busy ? null : () => _run((api) => api.receiveConsignment(_ref), 'Received. Now check the tubes.'), icon: const Icon(Icons.move_to_inbox_outlined), label: const Text('Receive at the laboratory')));
      case 'CHECK_TUBES':
        buttons.add(FilledButton.icon(onPressed: _busy ? null : _checkTubes, icon: const Icon(Icons.qr_code_scanner), label: const Text('Check tubes')));
        if (c.status == 'AT_LAB') {
          final left = d.count('TO_LAB');
          buttons.add(OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    if (await _confirm('Finish the check?', left == 0 ? 'Every tube has been checked.' : '$left tube(s) not scanned will be recorded as missing.', 'Finish')) {
                      await _run((api) => api.finishCheck(_ref), left == 0 ? 'Check finished: all tubes arrived' : 'Check finished: $left missing');
                    }
                  },
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Finish the check'),
          ));
        }
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final b in buttons) Padding(padding: const EdgeInsets.only(bottom: 8), child: b)]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: Text(d?.consignment.code ?? 'Consignment')),
      body: d == null
          ? Center(child: _error != null ? Padding(padding: const EdgeInsets.all(24), child: AnchorNotice(_error!, icon: Icons.error_outline, warning: true)) : const CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.consignment.statusLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                            [
                              'From ${d.consignment.originName}',
                              '${d.samples.length} tube${d.samples.length == 1 ? '' : 's'}',
                              if (d.consignment.trackingNumber.isNotEmpty) 'Tracking ${d.consignment.trackingNumber}',
                            ].join(' · '),
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          if (d.consignment.status == 'AT_LAB' || d.consignment.status == 'CHECKED') ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: AnchorStat(label: 'Arrived', value: '${d.count('ARRIVED')}', icon: Icons.check_circle_outline, color: const Color(0xFF1B7F4B))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: AnchorStat(
                                    label: d.consignment.status == 'CHECKED' ? 'Missing' : 'Not scanned yet',
                                    value: '${d.consignment.status == 'CHECKED' ? d.count('MISSING') : d.count('TO_LAB')}',
                                    icon: Icons.help_outline,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_busy) const LinearProgressIndicator(),
                  _actions(d),
                  AnchorSectionTitle('Tubes (${d.samples.length})'),
                  if (d.samples.isEmpty) Text('No tubes yet.', style: TextStyle(color: cs.onSurfaceVariant)),
                  ...d.samples.map((s) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          s.status == 'ARRIVED' ? Icons.check_circle : s.status == 'MISSING' ? Icons.cancel_outlined : Icons.science_outlined,
                          color: s.status == 'ARRIVED' ? const Color(0xFF1B7F4B) : s.status == 'MISSING' ? cs.error : null,
                        ),
                        title: Text(s.barcode, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([if (s.site.isNotEmpty) s.site, s.subtitle].where((x) => x.isNotEmpty).join(' · ')),
                        trailing: d.consignment.nextAction == 'PACK'
                            ? IconButton(
                                tooltip: 'Take out',
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: _busy ? null : () => _run((api) => api.removeTube(_ref, s.barcode), '${s.barcode} taken out'),
                              )
                            : null,
                      )),
                  const SizedBox(height: 8),
                  const AnchorSectionTitle('Journey'),
                  ...d.events.where((e) => e.type != 'PACKED' && e.type != 'TUBE_CHECKED').map((e) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.radio_button_checked, size: 18),
                        title: Text(e.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([shortDate(e.at), if (e.place.isNotEmpty) e.place, if (e.by.isNotEmpty) e.by, if (e.note.isNotEmpty) e.note].join(' · ')),
                      )),
                ],
              ),
            ),
    );
  }
}
