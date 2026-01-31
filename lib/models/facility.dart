class Facility {
  final String orgUnitUid;
  final String name;

  const Facility({required this.orgUnitUid, required this.name});

  factory Facility.fromJson(Map<String, dynamic> j) {
    return Facility(
      orgUnitUid: (j['orgUnitUid'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'orgUnitUid': orgUnitUid, 'name': name};
}

// Demo list for now (can be pulled from DHIS2 later)
const List<Facility> kFacilities = [
  Facility(orgUnitUid: 'FAC001', name: 'Facility A'),
  Facility(orgUnitUid: 'FAC002', name: 'Facility B'),
  Facility(orgUnitUid: 'FAC003', name: 'Facility C'),
];
