import 'api_client.dart';

/// One research sample (a tube). Study ID and Patient ID only, never names.
class SampleDto {
  final String barcode;
  final String swabType;
  final String studyId;
  final String patientId;
  final String site;
  final String status;
  final String statusLabel;
  final String collectedAt;
  final bool inDhis2;
  final String consignmentCode;

  const SampleDto({
    required this.barcode,
    required this.swabType,
    required this.studyId,
    required this.patientId,
    required this.site,
    required this.status,
    required this.statusLabel,
    required this.collectedAt,
    required this.inDhis2,
    required this.consignmentCode,
  });

  factory SampleDto.fromJson(Map<String, dynamic> j) {
    String s(dynamic v) => (v ?? '').toString();
    final c = j['consignment'];
    return SampleDto(
      barcode: s(j['barcode']),
      swabType: s(j['swabType']),
      studyId: s(j['studyId']),
      patientId: s(j['patientId']),
      site: s(j['site']),
      status: s(j['status']),
      statusLabel: s(j['statusLabel']),
      collectedAt: s(j['collectedAt']),
      inDhis2: j['inDhis2'] == true,
      consignmentCode: c is Map ? s(c['code']) : '',
    );
  }

  /// "Nasal · Study 4752 · Patient 0000030414"
  String get subtitle {
    final parts = <String>[
      if (swabType.isNotEmpty) '${swabType[0]}${swabType.substring(1).toLowerCase()}',
      if (studyId.isNotEmpty) 'Study $studyId',
      if (patientId.isNotEmpty) 'Patient $patientId',
      if (!inDhis2) 'not in DHIS2 yet',
    ];
    return parts.join(' · ');
  }
}

class ConsignmentDto {
  final String id;
  final String code;
  final String status;
  final String statusLabel;
  final String originName;
  final int tubes;
  final String trackingNumber;
  final String nextAction;
  final String updatedLabel;

  const ConsignmentDto({
    required this.id,
    required this.code,
    required this.status,
    required this.statusLabel,
    required this.originName,
    required this.tubes,
    required this.trackingNumber,
    required this.nextAction,
    required this.updatedLabel,
  });

  factory ConsignmentDto.fromJson(Map<String, dynamic> j, {String? nextAction}) {
    String s(dynamic v) => (v ?? '').toString();
    final o = j['origin'];
    // The latest hand-over (or when packing started).
    final at = s(j['checkedAt'] ?? j['receivedAtLabAt'] ?? j['sentToLabAt'] ?? j['receivedAtJubaAt'] ?? j['sentToJubaAt'] ?? j['createdAt']);
    return ConsignmentDto(
      id: s(j['id']),
      code: s(j['code']),
      status: s(j['status']),
      statusLabel: s(j['statusLabel']),
      originName: o is Map ? s(o['name']) : '',
      tubes: (j['tubes'] is int) ? j['tubes'] as int : int.tryParse(s(j['tubes'])) ?? 0,
      trackingNumber: s(j['trackingNumber']),
      nextAction: nextAction ?? s(j['nextAction']),
      updatedLabel: shortDate(at),
    );
  }
}

class SampleEventDto {
  final String type;
  final String at;
  final String place;
  final String by;
  final String note;

  const SampleEventDto({required this.type, required this.at, required this.place, required this.by, required this.note});

  factory SampleEventDto.fromJson(Map<String, dynamic> j) {
    String s(dynamic v) => (v ?? '').toString();
    return SampleEventDto(type: s(j['type']), at: s(j['createdAt']), place: s(j['locationName']), by: s(j['userName']), note: s(j['note']));
  }

  String get label => const {
        'CONSIGNMENT_CREATED': 'Consignment started',
        'RECEIVED_AT_BASE': 'Received at the base',
        'PACKED': 'Packed',
        'UNPACKED': 'Taken out',
        'SENT_TO_JUBA': 'Sent to Juba',
        'RECEIVED_AT_JUBA': 'Received in Juba',
        'SENT_TO_LAB': 'Shipped to the laboratory',
        'RECEIVED_AT_LAB': 'Received at the laboratory',
        'TUBE_CHECKED': 'Tube checked',
        'TUBE_UNEXPECTED': 'Unexpected tube scanned',
        'TUBE_MISSING': 'Tube missing',
        'CHECK_FINISHED': 'Check finished',
      }[type] ??
      type;
}

class ConsignmentDetailDto {
  final ConsignmentDto consignment;
  final List<SampleDto> samples;
  final List<SampleEventDto> events;

  const ConsignmentDetailDto({required this.consignment, required this.samples, required this.events});

  factory ConsignmentDetailDto.fromJson(Map<String, dynamic> j) {
    final c = (j['consignment'] as Map).cast<String, dynamic>();
    return ConsignmentDetailDto(
      consignment: ConsignmentDto.fromJson(c, nextAction: (j['nextAction'] ?? '').toString()),
      samples: ((j['samples'] as List?) ?? const []).map((x) => SampleDto.fromJson((x as Map).cast<String, dynamic>())).toList(),
      events: ((j['events'] as List?) ?? const []).map((x) => SampleEventDto.fromJson((x as Map).cast<String, dynamic>())).toList(),
    );
  }

  int count(String status) => samples.where((s) => s.status == status).length;
}

/// Result of one tube scan.
class TubeScanResult {
  final SampleDto sample;
  final bool already;
  final List<String> notices;
  final int? tubes;
  final int? remaining;

  const TubeScanResult({required this.sample, required this.already, required this.notices, this.tubes, this.remaining});

  factory TubeScanResult.fromJson(Map<String, dynamic> j) => TubeScanResult(
        sample: SampleDto.fromJson((j['sample'] as Map).cast<String, dynamic>()),
        already: j['already'] == true,
        notices: ((j['notices'] as List?) ?? const []).map((x) => x.toString()).toList(),
        tubes: j['tubes'] is int ? j['tubes'] as int : null,
        remaining: j['remaining'] is int ? j['remaining'] as int : null,
      );
}

/// "2026-10-21T17:30:54.000Z" -> "21 Oct, 17:30" (local time).
String shortDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final l = d.toLocal();
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${l.day} ${m[l.month - 1]}, ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Research samples: field base, main warehouse (Juba) and laboratory steps.
class SampleApi {
  final ApiClient _api;
  SampleApi(this._api);

  static String _ref(String ref) => Uri.encodeComponent(ref.trim());

  Map<String, dynamic> _map(dynamic data) => data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};

  /// Base: tubes expected from its sites, and tubes received but not packed.
  Future<({List<SampleDto> expected, List<SampleDto> atBase})> expected() async {
    final r = _map((await _api.request(method: 'GET', path: '/api/samples/expected')).data);
    List<SampleDto> list(dynamic v) => ((v as List?) ?? const []).map((x) => SampleDto.fromJson((x as Map).cast<String, dynamic>())).toList();
    return (expected: list(r['expected']), atBase: list(r['atBase']));
  }

  Future<TubeScanResult> receiveTube(String barcode) async =>
      TubeScanResult.fromJson(_map((await _api.request(method: 'POST', path: '/api/samples/receive', data: {'barcode': barcode})).data));

  Future<List<ConsignmentDto>> consignments() async {
    final data = (await _api.request(method: 'GET', path: '/api/samples/consignments')).data;
    return ((data as List?) ?? const []).map((x) => ConsignmentDto.fromJson((x as Map).cast<String, dynamic>())).toList();
  }

  Future<ConsignmentDetailDto> createConsignment() async =>
      ConsignmentDetailDto.fromJson(_map((await _api.request(method: 'POST', path: '/api/samples/consignments', data: <String, dynamic>{})).data));

  /// [ref] is the consignment id, its code, or the scanned QR text.
  Future<ConsignmentDetailDto> consignment(String ref) async =>
      ConsignmentDetailDto.fromJson(_map((await _api.request(method: 'GET', path: '/api/samples/consignments/${_ref(ref)}')).data));

  Future<TubeScanResult> packTube(String ref, String barcode) async =>
      TubeScanResult.fromJson(_map((await _api.request(method: 'POST', path: '/api/samples/consignments/${_ref(ref)}/samples', data: {'barcode': barcode})).data));

  Future<ConsignmentDetailDto> removeTube(String ref, String barcode) async => ConsignmentDetailDto.fromJson(
      _map((await _api.request(method: 'DELETE', path: '/api/samples/consignments/${_ref(ref)}/samples/${Uri.encodeComponent(barcode)}')).data));

  Future<ConsignmentDetailDto> sendToJuba(String ref) async =>
      ConsignmentDetailDto.fromJson(_map((await _api.request(method: 'POST', path: '/api/samples/consignments/${_ref(ref)}/send', data: <String, dynamic>{})).data));

  /// Juba or the laboratory, depending on who scans.
  Future<ConsignmentDetailDto> receiveConsignment(String ref) async =>
      ConsignmentDetailDto.fromJson(_map((await _api.request(method: 'POST', path: '/api/samples/consignments/${_ref(ref)}/receive', data: <String, dynamic>{})).data));

  Future<ConsignmentDetailDto> shipToLab(String ref, String trackingNumber) async => ConsignmentDetailDto.fromJson(
      _map((await _api.request(method: 'POST', path: '/api/samples/consignments/${_ref(ref)}/dispatch', data: {'trackingNumber': trackingNumber})).data));

  Future<TubeScanResult> checkTube(String ref, String barcode) async =>
      TubeScanResult.fromJson(_map((await _api.request(method: 'POST', path: '/api/samples/consignments/${_ref(ref)}/check', data: {'barcode': barcode})).data));

  Future<ConsignmentDetailDto> finishCheck(String ref) async =>
      ConsignmentDetailDto.fromJson(_map((await _api.request(method: 'POST', path: '/api/samples/consignments/${_ref(ref)}/finish', data: <String, dynamic>{})).data));

  static String labelPath(String id) => '/api/samples/consignments/${Uri.encodeComponent(id)}/label.pdf';
}
