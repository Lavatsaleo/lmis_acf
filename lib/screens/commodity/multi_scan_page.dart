import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Reusable scanner page used for both Dispatch and Receive.
///
/// - Prevents duplicates (by boxUid)
/// - Enforces expectedCount (cannot scan more than expected)
/// - Auto-closes the scanner immediately once expectedCount is reached
class MultiScanPage extends StatefulWidget {
  final String title;
  final String helperText;
  final int expectedCount;

  const MultiScanPage({
    super.key,
    required this.title,
    required this.expectedCount,
    this.helperText = "Scan the QR codes on the boxes.",
  });

  @override
  State<MultiScanPage> createState() => _MultiScanPageState();
}

class _MultiScanPageState extends State<MultiScanPage> {
  final MobileScannerController _controller = MobileScannerController();

  final List<String> _payloads = <String>[];
  final Set<String> _uniqueKeys = <String>{};

  bool _cooldown = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Map<String, dynamic> _parsePayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // ignore, handled below
    }
    return <String, dynamic>{};
  }

  String _extractUid(String raw) {
    final parsed = _parsePayload(raw);
    final uid = parsed['boxUid'];
    if (uid == null) return raw;
    return uid.toString();
  }

  Future<void> _autoCloseIfDone() async {
    if (_payloads.length < widget.expectedCount) return;

    // Stop the camera ASAP, then return results.
    try {
      await _controller.stop();
    } catch (_) {
      // ignore
    }

    if (!mounted) return;
    Navigator.pop(context, _payloads);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_cooldown) return;

    // Already complete: ignore further scans and auto-close.
    if (_payloads.length >= widget.expectedCount) {
      await _autoCloseIfDone();
      return;
    }

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    final parsed = _parsePayload(raw);
    final boxUid = (parsed['boxUid'] as String?)?.trim();
    if (boxUid == null || boxUid.isEmpty) return;

    // Prevent duplicates
    if (_uniqueKeys.contains(boxUid)) return;

    setState(() {
      _payloads.add(raw);
      _uniqueKeys.add(boxUid);
      _cooldown = true;
    });

    // If we just hit the target, auto-close immediately.
    if (_payloads.length >= widget.expectedCount) {
      // Let the UI paint the last scan, then close.
      await Future.delayed(const Duration(milliseconds: 150));
      await _autoCloseIfDone();
      return;
    }

    // Small delay to avoid rapid double scans.
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _cooldown = false);
  }

  void _finish() {
    Navigator.pop(context, _payloads);
  }

  @override
  Widget build(BuildContext context) {
    final doneEnabled = _payloads.isNotEmpty && _payloads.length >= widget.expectedCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _payloads.isEmpty ? null : _finish,
            child: const Text("Done"),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.helperText,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Scanned: ${_payloads.length} / ${widget.expectedCount}",
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (_cooldown)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _payloads.isEmpty
                                ? "No scans yet."
                                : "Latest: ${_extractUid(_payloads.last)}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!doneEnabled && _payloads.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              "Scan ${widget.expectedCount - _payloads.length} more box(es) to complete.",
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, <String>[]),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _payloads.isEmpty ? null : _finish,
                    child: const Text("Finish"),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
