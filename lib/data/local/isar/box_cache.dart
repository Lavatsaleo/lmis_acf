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

  /// Pack size of this box (Prisma `Box.sachetsPerBox`). Configurable per
  /// product, so it must not be assumed to be 600. Null for boxes cached by
  /// older app builds.
  int? sachetsPerBox;

  /// Server balance at the last store refresh (Prisma `Box.sachetsRemaining`).
  int? sachetsRemaining;

  DateTime updatedAt = DateTime.now();
}
