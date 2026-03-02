import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/sync/sync_service.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../data/local/isar/sync_queue_item.dart';
import '../widgets/acf_brand.dart';

class QueueInspectorScreen extends StatefulWidget {
  const QueueInspectorScreen({super.key});

  @override
  State<QueueInspectorScreen> createState() => _QueueInspectorScreenState();
}

class _QueueInspectorScreenState extends State<QueueInspectorScreen> {
  final SyncQueueRepo _repo = SyncQueueRepo();
  final SyncService _syncService = SyncService();

  bool _syncing = false;

  Future<void> _clearAll() async {
    await _repo.clearAll();
  }

  Future<void> _retryFailed() async {
    await _repo.retryAllFailed();
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final result = await _syncService.syncNow();
      if (!mounted) return;

      final msg = result.online
          ? 'Sync done: sent ${result.sent}, failed ${result.failed} (attempted ${result.attempted})'
          : 'Offline: nothing to sync';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcfAppBar(
        title: 'Sync Queue',
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined),
          ),
          IconButton(
            tooltip: 'Retry failed',
            onPressed: _retryFailed,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Clear all',
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: StreamBuilder<List<SyncQueueItem>>(
        stream: _repo.watchLatest(limit: 200),
        builder: (context, snapshot) {
          final items = snapshot.data ?? <SyncQueueItem>[];
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) return const Center(child: Text('Queue is empty'));

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final it = items[index];
              return ListTile(
                title: Text('${it.method} ${it.endpoint}'),
                subtitle: Text(
                  'entity=${it.entityType} localId=${it.localEntityId}\n'
                  'status=${it.status.name} attempts=${it.attempts}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => _QueueItemDetails(item: it),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _QueueItemDetails extends StatelessWidget {
  final SyncQueueItem item;

  const _QueueItemDetails({required this.item});

  String _prettyJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      final obj = jsonDecode(raw);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(obj);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Queue ID: ${item.queueId}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Status: ${item.status.name}'),
          Text('Operation: ${item.operation.name}'),
          Text('Attempts: ${item.attempts}'),
          if (item.httpStatus != null) Text('HTTP status: ${item.httpStatus}'),
          if (item.sentAt != null) Text('Sent at: ${item.sentAt}'),
          if (item.lastError != null) ...[
            const SizedBox(height: 8),
            Text('Last error: ${item.lastError}', style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 12),
          const Text('Payload', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: SingleChildScrollView(
              child: Text(
                _prettyJson(item.payloadJson),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if ((item.responseJson ?? '').trim().isNotEmpty) ...[
            const Text('Response', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _prettyJson(item.responseJson),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
