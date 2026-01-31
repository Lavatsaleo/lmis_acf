import 'package:lmis_acf/models/facility.dart';

class ScanSessionResult {
  final List<String> payloads;
  final Facility facility;
  final int expectedCount;

  const ScanSessionResult({
    required this.payloads,
    required this.facility,
    required this.expectedCount,
  });
}

class ReceiveSessionResult {
  final List<String> payloads;
  final Facility facility;
  final int expectedCount;
  final String shipmentId;

  const ReceiveSessionResult({
    required this.payloads,
    required this.facility,
    required this.expectedCount,
    required this.shipmentId,
  });
}

class ApplyResult {
  final int ok;
  final int skipped;
  final int notFound;
  final List<String> okBoxUids;

  const ApplyResult({
    required this.ok,
    required this.skipped,
    required this.notFound,
    required this.okBoxUids,
  });
}
