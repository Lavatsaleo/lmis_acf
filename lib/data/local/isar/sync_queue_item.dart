import 'package:isar/isar.dart';

part 'sync_queue_item.g.dart';

/// Where in the sync lifecycle a queued item is.
enum SyncStatus {
  pending,
  sending,
  sent,
  failed,
}

/// What kind of CRUD operation this queue item represents.
enum SyncOperation {
  create,
  update,
  delete,
}

/// A single item in the offline sync queue.
///
/// We store the raw HTTP intent (endpoint, method, JSON payload) so we can
/// replay it later when the device is online.
@collection
class SyncQueueItem {
  /// Isar internal id.
  Id id = Isar.autoIncrement;

  /// Stable UUID for this queue item (used for idempotency/retries).
  @Index(unique: true)
  late String queueId;

  /// Example: "box", "shipment", "assessment" ...
  @Index()
  late String entityType;

  /// Local UUID of the entity on the phone (not server id).
  @Index()
  late String localEntityId;

  /// HTTP method: POST/PUT/PATCH/DELETE.
  late String method;

  /// API endpoint path, eg "/api/shipments/dispatch".
  late String endpoint;

  /// JSON payload as a string.
  String? payloadJson;

  /// Optional idempotency key to send to the server.
  String? idempotencyKey;

  /// If this queue item depends on another local entity being synced first.
  /// Example: assessment depends on child enrollment.
  String? dependsOnLocalEntityId;

  @enumerated
  @Index()
  SyncStatus status = SyncStatus.pending;

  @enumerated
  SyncOperation operation = SyncOperation.create;

  int attempts = 0;
  DateTime createdAt = DateTime.now();
  DateTime? lastAttemptAt;
  String? lastError;

  /// For debugging: last HTTP status code returned (if any).
  int? httpStatus;

  /// For debugging: raw response JSON (truncated/optional).
  String? responseJson;

  /// When the item was successfully sent.
  DateTime? sentAt;

  SyncQueueItem();

  SyncQueueItem.build({
    required this.queueId,
    required this.entityType,
    required this.localEntityId,
    required this.method,
    required this.endpoint,
    required this.operation,
    this.payloadJson,
    this.idempotencyKey,
    this.dependsOnLocalEntityId,
  }) {
    status = SyncStatus.pending;
    attempts = 0;
    createdAt = DateTime.now();
  }
}
