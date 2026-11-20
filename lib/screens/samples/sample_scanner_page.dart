import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// What happened to one scan, shown on the scanner straight away.
class ScanOutcome {
  final bool ok;
  final String title;
  final String detail;
  const ScanOutcome.ok(this.title, [this.detail = '']) : ok = true;
  const ScanOutcome.problem(this.title, [this.detail = '']) : ok = false;
}

/// Camera scanner for sample tubes (barcodes) and consignment labels (QR).
///
/// With [onScan] it keeps scanning: every code is handed to [onScan] and the
/// result is shown, so a tray of tubes is scanned one after another. Without
/// it, the first code closes the page and is returned (one consignment label).
class SampleScannerPage extends StatefulWidget {
  final String title;
  final String hint;
  final Future<ScanOutcome> Function(String code)? onScan;
  final Widget Function(BuildContext context)? footer;

  const SampleScannerPage({super.key, required this.title, required this.hint, this.onScan, this.footer});

  @override
  State<SampleScannerPage> createState() => _SampleScannerPageState();
}

class _SampleScannerPageState extends State<SampleScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _typed = TextEditingController();
  bool _busy = false;
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<(String, ScanOutcome)> _log = [];

  @override
  void dispose() {
    _controller.dispose();
    _typed.dispose();
    super.dispose();
  }

  Future<void> _handle(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || _busy) return;
    // The camera reports the same code many times a second: ignore repeats for a moment.
    if (code == _lastCode && DateTime.now().difference(_lastAt).inMilliseconds < 2500) return;
    _lastCode = code;
    _lastAt = DateTime.now();
    if (widget.onScan == null) {
      await _controller.stop();
      if (mounted) Navigator.pop(context, code);
      return;
    }
    setState(() => _busy = true);
    ScanOutcome outcome;
    try {
      outcome = await widget.onScan!(code);
    } catch (e) {
      outcome = ScanOutcome.problem('Could not save $code', e.toString());
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _log.insert(0, (code, outcome));
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final last = _log.isEmpty ? null : _log.first.$2;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      final v = b.rawValue;
                      if (v != null && v.trim().isNotEmpty) {
                        _handle(v);
                        break;
                      }
                    }
                  },
                ),
                if (_busy) const ColoredBox(color: Color(0x55000000), child: Center(child: CircularProgressIndicator())),
                if (last != null && !_busy)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: last.ok ? const Color(0xFF1B7F4B) : const Color(0xFFB3261E), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Icon(last.ok ? Icons.check_circle : Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(last.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                                if (last.detail.isNotEmpty) Text(last.detail, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(widget.hint, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _typed,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(isDense: true, labelText: 'Or type the number'),
                    onSubmitted: (v) {
                      _typed.clear();
                      _lastCode = null;
                      _handle(v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final v = _typed.text;
                    _typed.clear();
                    _lastCode = null;
                    _handle(v);
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          if (widget.footer != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: widget.footer!(context)),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: _log.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final (code, o) = _log[i];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(o.ok ? Icons.check_circle_outline : Icons.error_outline, color: o.ok ? const Color(0xFF1B7F4B) : cs.error),
                  title: Text(o.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(o.detail.isEmpty ? code : '$code · ${o.detail}'),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(width: double.infinity, child: FilledButton.tonal(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
            ),
          ),
        ],
      ),
    );
  }
}

/// The consignment code from a scanned label ({"consignment":"SC-..."} or the plain code).
String consignmentCodeOf(String raw) {
  try {
    final j = jsonDecode(raw);
    if (j is Map && j['consignment'] != null) return j['consignment'].toString();
  } catch (_) {
    // a plain code
  }
  return raw.trim();
}
