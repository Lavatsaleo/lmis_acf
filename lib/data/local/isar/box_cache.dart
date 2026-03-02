import 'package:isar/isar.dart';

part 'box_cache.g.dart';

/// Local cache of a Box.
///
/// We only store the minimum fields required for offline validation.
@collection
class BoxCache {
  Id id = Isar.autoIncrement;

  /// Unique box UID stored in QR code (Prisma `Box.boxUid`).
  @Index(unique: true)
  late String boxUid;

  /// Prisma `Box.status` as string (e.g. CREATED, IN_TRANSIT, RECEIVED...)
  late String status;

  /// Prisma `Box.currentFacilityId`
  String? currentFacilityId;

  /// Prisma `Box.orderId`
  String? orderId;

  /// Prisma `Box.productId`
  String? productId;

  String? batchNo;
  DateTime? expiryDate;

  DateTime updatedAt = DateTime.now();
}
