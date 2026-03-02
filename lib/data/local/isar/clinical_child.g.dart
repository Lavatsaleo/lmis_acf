// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clinical_child.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetClinicalChildCollection on Isar {
  IsarCollection<ClinicalChild> get clinicalChilds => this.collection();
}

const ClinicalChildSchema = CollectionSchema(
  name: r'ClinicalChild',
  id: -7857337909701681008,
  properties: {
    r'caregiverContacts': PropertySchema(
      id: 0,
      name: r'caregiverContacts',
      type: IsarType.string,
    ),
    r'caregiverName': PropertySchema(
      id: 1,
      name: r'caregiverName',
      type: IsarType.string,
    ),
    r'chpContacts': PropertySchema(
      id: 2,
      name: r'chpContacts',
      type: IsarType.string,
    ),
    r'chpName': PropertySchema(
      id: 3,
      name: r'chpName',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 4,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'cwcNumber': PropertySchema(
      id: 5,
      name: r'cwcNumber',
      type: IsarType.string,
    ),
    r'dateOfBirth': PropertySchema(
      id: 6,
      name: r'dateOfBirth',
      type: IsarType.dateTime,
    ),
    r'enrollmentDate': PropertySchema(
      id: 7,
      name: r'enrollmentDate',
      type: IsarType.dateTime,
    ),
    r'facilityCode': PropertySchema(
      id: 8,
      name: r'facilityCode',
      type: IsarType.string,
    ),
    r'firstName': PropertySchema(
      id: 9,
      name: r'firstName',
      type: IsarType.string,
    ),
    r'lastName': PropertySchema(
      id: 10,
      name: r'lastName',
      type: IsarType.string,
    ),
    r'localChildId': PropertySchema(
      id: 11,
      name: r'localChildId',
      type: IsarType.string,
    ),
    r'remoteChildId': PropertySchema(
      id: 12,
      name: r'remoteChildId',
      type: IsarType.string,
    ),
    r'sex': PropertySchema(
      id: 13,
      name: r'sex',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 14,
      name: r'status',
      type: IsarType.string,
    ),
    r'uniqueChildNumber': PropertySchema(
      id: 15,
      name: r'uniqueChildNumber',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 16,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'village': PropertySchema(
      id: 17,
      name: r'village',
      type: IsarType.string,
    )
  },
  estimateSize: _clinicalChildEstimateSize,
  serialize: _clinicalChildSerialize,
  deserialize: _clinicalChildDeserialize,
  deserializeProp: _clinicalChildDeserializeProp,
  idName: r'id',
  indexes: {
    r'localChildId': IndexSchema(
      id: -5289314306964570328,
      name: r'localChildId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'localChildId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _clinicalChildGetId,
  getLinks: _clinicalChildGetLinks,
  attach: _clinicalChildAttach,
  version: '3.1.0+1',
);

int _clinicalChildEstimateSize(
  ClinicalChild object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.caregiverContacts.length * 3;
  bytesCount += 3 + object.caregiverName.length * 3;
  {
    final value = object.chpContacts;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.chpName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.cwcNumber;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.facilityCode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.firstName.length * 3;
  bytesCount += 3 + object.lastName.length * 3;
  bytesCount += 3 + object.localChildId.length * 3;
  {
    final value = object.remoteChildId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sex.length * 3;
  bytesCount += 3 + object.status.length * 3;
  {
    final value = object.uniqueChildNumber;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.village;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _clinicalChildSerialize(
  ClinicalChild object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.caregiverContacts);
  writer.writeString(offsets[1], object.caregiverName);
  writer.writeString(offsets[2], object.chpContacts);
  writer.writeString(offsets[3], object.chpName);
  writer.writeDateTime(offsets[4], object.createdAt);
  writer.writeString(offsets[5], object.cwcNumber);
  writer.writeDateTime(offsets[6], object.dateOfBirth);
  writer.writeDateTime(offsets[7], object.enrollmentDate);
  writer.writeString(offsets[8], object.facilityCode);
  writer.writeString(offsets[9], object.firstName);
  writer.writeString(offsets[10], object.lastName);
  writer.writeString(offsets[11], object.localChildId);
  writer.writeString(offsets[12], object.remoteChildId);
  writer.writeString(offsets[13], object.sex);
  writer.writeString(offsets[14], object.status);
  writer.writeString(offsets[15], object.uniqueChildNumber);
  writer.writeDateTime(offsets[16], object.updatedAt);
  writer.writeString(offsets[17], object.village);
}

ClinicalChild _clinicalChildDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ClinicalChild();
  object.caregiverContacts = reader.readString(offsets[0]);
  object.caregiverName = reader.readString(offsets[1]);
  object.chpContacts = reader.readStringOrNull(offsets[2]);
  object.chpName = reader.readStringOrNull(offsets[3]);
  object.createdAt = reader.readDateTime(offsets[4]);
  object.cwcNumber = reader.readStringOrNull(offsets[5]);
  object.dateOfBirth = reader.readDateTimeOrNull(offsets[6]);
  object.enrollmentDate = reader.readDateTime(offsets[7]);
  object.facilityCode = reader.readStringOrNull(offsets[8]);
  object.firstName = reader.readString(offsets[9]);
  object.id = id;
  object.lastName = reader.readString(offsets[10]);
  object.localChildId = reader.readString(offsets[11]);
  object.remoteChildId = reader.readStringOrNull(offsets[12]);
  object.sex = reader.readString(offsets[13]);
  object.status = reader.readString(offsets[14]);
  object.uniqueChildNumber = reader.readStringOrNull(offsets[15]);
  object.updatedAt = reader.readDateTime(offsets[16]);
  object.village = reader.readStringOrNull(offsets[17]);
  return object;
}

P _clinicalChildDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readDateTime(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readDateTime(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _clinicalChildGetId(ClinicalChild object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _clinicalChildGetLinks(ClinicalChild object) {
  return [];
}

void _clinicalChildAttach(
    IsarCollection<dynamic> col, Id id, ClinicalChild object) {
  object.id = id;
}

extension ClinicalChildByIndex on IsarCollection<ClinicalChild> {
  Future<ClinicalChild?> getByLocalChildId(String localChildId) {
    return getByIndex(r'localChildId', [localChildId]);
  }

  ClinicalChild? getByLocalChildIdSync(String localChildId) {
    return getByIndexSync(r'localChildId', [localChildId]);
  }

  Future<bool> deleteByLocalChildId(String localChildId) {
    return deleteByIndex(r'localChildId', [localChildId]);
  }

  bool deleteByLocalChildIdSync(String localChildId) {
    return deleteByIndexSync(r'localChildId', [localChildId]);
  }

  Future<List<ClinicalChild?>> getAllByLocalChildId(
      List<String> localChildIdValues) {
    final values = localChildIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'localChildId', values);
  }

  List<ClinicalChild?> getAllByLocalChildIdSync(
      List<String> localChildIdValues) {
    final values = localChildIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'localChildId', values);
  }

  Future<int> deleteAllByLocalChildId(List<String> localChildIdValues) {
    final values = localChildIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'localChildId', values);
  }

  int deleteAllByLocalChildIdSync(List<String> localChildIdValues) {
    final values = localChildIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'localChildId', values);
  }

  Future<Id> putByLocalChildId(ClinicalChild object) {
    return putByIndex(r'localChildId', object);
  }

  Id putByLocalChildIdSync(ClinicalChild object, {bool saveLinks = true}) {
    return putByIndexSync(r'localChildId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByLocalChildId(List<ClinicalChild> objects) {
    return putAllByIndex(r'localChildId', objects);
  }

  List<Id> putAllByLocalChildIdSync(List<ClinicalChild> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'localChildId', objects, saveLinks: saveLinks);
  }
}

extension ClinicalChildQueryWhereSort
    on QueryBuilder<ClinicalChild, ClinicalChild, QWhere> {
  QueryBuilder<ClinicalChild, ClinicalChild, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ClinicalChildQueryWhere
    on QueryBuilder<ClinicalChild, ClinicalChild, QWhereClause> {
  QueryBuilder<ClinicalChild, ClinicalChild, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterWhereClause>
      localChildIdEqualTo(String localChildId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'localChildId',
        value: [localChildId],
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterWhereClause>
      localChildIdNotEqualTo(String localChildId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localChildId',
              lower: [],
              upper: [localChildId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localChildId',
              lower: [localChildId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localChildId',
              lower: [localChildId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localChildId',
              lower: [],
              upper: [localChildId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension ClinicalChildQueryFilter
    on QueryBuilder<ClinicalChild, ClinicalChild, QFilterCondition> {
  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverContactsEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'caregiverContacts',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverContactsGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'caregiverContacts',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverContactsLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'caregiverContacts',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverContactsBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'caregiverContacts',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverContactsStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'caregiverContacts',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverContactsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'caregiverContacts',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverContactsContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'caregiverContacts',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverContactsMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'caregiverContacts',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverContactsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'caregiverContacts',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverContactsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'caregiverContacts',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'caregiverName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'caregiverName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'caregiverName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'caregiverName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'caregiverName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'caregiverName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'caregiverName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'caregiverName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'caregiverName',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      caregiverNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'caregiverName',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpContactsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'chpContacts',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpContactsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'chpContacts',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpContactsEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chpContacts',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpContactsGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chpContacts',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpContactsLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chpContacts',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpContactsBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chpContacts',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpContactsStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'chpContacts',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpContactsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'chpContacts',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpContactsContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'chpContacts',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpContactsMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'chpContacts',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpContactsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chpContacts',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpContactsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'chpContacts',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'chpName',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'chpName',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chpName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chpName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chpName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chpName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'chpName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'chpName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'chpName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'chpName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chpName',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      chpNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'chpName',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      cwcNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cwcNumber',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      cwcNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cwcNumber',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      cwcNumberEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cwcNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      cwcNumberGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cwcNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      cwcNumberLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cwcNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      cwcNumberBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cwcNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      cwcNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cwcNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      cwcNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cwcNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      cwcNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cwcNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      cwcNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cwcNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      cwcNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cwcNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      cwcNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cwcNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      dateOfBirthIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'dateOfBirth',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      dateOfBirthIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'dateOfBirth',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      dateOfBirthEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dateOfBirth',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      dateOfBirthGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dateOfBirth',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      dateOfBirthLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dateOfBirth',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      dateOfBirthBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dateOfBirth',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      enrollmentDateEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'enrollmentDate',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      enrollmentDateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'enrollmentDate',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      enrollmentDateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'enrollmentDate',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      enrollmentDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'enrollmentDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      facilityCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'facilityCode',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      facilityCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'facilityCode',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      facilityCodeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'facilityCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      facilityCodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'facilityCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      facilityCodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'facilityCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      facilityCodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'facilityCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      facilityCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'facilityCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      facilityCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'facilityCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      facilityCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'facilityCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      facilityCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'facilityCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      facilityCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'facilityCode',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      facilityCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'facilityCode',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      firstNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firstName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      firstNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'firstName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      firstNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'firstName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      firstNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'firstName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      firstNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'firstName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      firstNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'firstName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      firstNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firstName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      firstNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firstName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      firstNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firstName',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      firstNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firstName',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      lastNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      lastNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      lastNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      lastNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      lastNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      lastNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      lastNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      lastNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      lastNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastName',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      lastNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastName',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      localChildIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localChildId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      localChildIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'localChildId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      localChildIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'localChildId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      localChildIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'localChildId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      localChildIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'localChildId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      localChildIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'localChildId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      localChildIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'localChildId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      localChildIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'localChildId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      localChildIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localChildId',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      localChildIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'localChildId',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      remoteChildIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'remoteChildId',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      remoteChildIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'remoteChildId',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      remoteChildIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remoteChildId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      remoteChildIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'remoteChildId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      remoteChildIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'remoteChildId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      remoteChildIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'remoteChildId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      remoteChildIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'remoteChildId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      remoteChildIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'remoteChildId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      remoteChildIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'remoteChildId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      remoteChildIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'remoteChildId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      remoteChildIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remoteChildId',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      remoteChildIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'remoteChildId',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition> sexEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      sexGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition> sexLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition> sexBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      sexStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition> sexEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition> sexContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition> sexMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sex',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      sexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sex',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      sexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sex',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      statusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      uniqueChildNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'uniqueChildNumber',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      uniqueChildNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'uniqueChildNumber',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      uniqueChildNumberEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uniqueChildNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      uniqueChildNumberGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'uniqueChildNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      uniqueChildNumberLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'uniqueChildNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      uniqueChildNumberBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'uniqueChildNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      uniqueChildNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'uniqueChildNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      uniqueChildNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'uniqueChildNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      uniqueChildNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'uniqueChildNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      uniqueChildNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'uniqueChildNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      uniqueChildNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uniqueChildNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      uniqueChildNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'uniqueChildNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      villageIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'village',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      villageIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'village',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      villageEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'village',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      villageGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'village',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      villageLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'village',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      villageBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'village',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      villageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'village',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      villageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'village',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      villageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'village',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      villageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'village',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      villageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'village',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterFilterCondition>
      villageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'village',
        value: '',
      ));
    });
  }
}

extension ClinicalChildQueryObject
    on QueryBuilder<ClinicalChild, ClinicalChild, QFilterCondition> {}

extension ClinicalChildQueryLinks
    on QueryBuilder<ClinicalChild, ClinicalChild, QFilterCondition> {}

extension ClinicalChildQuerySortBy
    on QueryBuilder<ClinicalChild, ClinicalChild, QSortBy> {
  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByCaregiverContacts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caregiverContacts', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByCaregiverContactsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caregiverContacts', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByCaregiverName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caregiverName', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByCaregiverNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caregiverName', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortByChpContacts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chpContacts', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByChpContactsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chpContacts', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortByChpName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chpName', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortByChpNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chpName', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortByCwcNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cwcNumber', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByCwcNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cwcNumber', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortByDateOfBirth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateOfBirth', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByDateOfBirthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateOfBirth', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByEnrollmentDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enrollmentDate', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByEnrollmentDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enrollmentDate', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByFacilityCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'facilityCode', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByFacilityCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'facilityCode', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortByFirstName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firstName', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByFirstNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firstName', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortByLastName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastName', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByLastNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastName', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByLocalChildId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localChildId', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByLocalChildIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localChildId', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByRemoteChildId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteChildId', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByRemoteChildIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteChildId', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortBySex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sex', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortBySexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sex', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByUniqueChildNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniqueChildNumber', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByUniqueChildNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniqueChildNumber', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortByVillage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'village', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> sortByVillageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'village', Sort.desc);
    });
  }
}

extension ClinicalChildQuerySortThenBy
    on QueryBuilder<ClinicalChild, ClinicalChild, QSortThenBy> {
  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByCaregiverContacts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caregiverContacts', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByCaregiverContactsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caregiverContacts', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByCaregiverName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caregiverName', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByCaregiverNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caregiverName', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByChpContacts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chpContacts', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByChpContactsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chpContacts', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByChpName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chpName', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByChpNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chpName', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByCwcNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cwcNumber', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByCwcNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cwcNumber', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByDateOfBirth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateOfBirth', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByDateOfBirthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateOfBirth', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByEnrollmentDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enrollmentDate', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByEnrollmentDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enrollmentDate', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByFacilityCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'facilityCode', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByFacilityCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'facilityCode', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByFirstName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firstName', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByFirstNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firstName', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByLastName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastName', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByLastNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastName', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByLocalChildId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localChildId', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByLocalChildIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localChildId', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByRemoteChildId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteChildId', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByRemoteChildIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteChildId', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenBySex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sex', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenBySexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sex', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByUniqueChildNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniqueChildNumber', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByUniqueChildNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniqueChildNumber', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByVillage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'village', Sort.asc);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QAfterSortBy> thenByVillageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'village', Sort.desc);
    });
  }
}

extension ClinicalChildQueryWhereDistinct
    on QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> {
  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct>
      distinctByCaregiverContacts({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'caregiverContacts',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctByCaregiverName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'caregiverName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctByChpContacts(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chpContacts', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctByChpName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chpName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctByCwcNumber(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cwcNumber', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct>
      distinctByDateOfBirth() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dateOfBirth');
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct>
      distinctByEnrollmentDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'enrollmentDate');
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctByFacilityCode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'facilityCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctByFirstName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firstName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctByLastName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctByLocalChildId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localChildId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctByRemoteChildId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'remoteChildId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctBySex(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sex', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctByStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct>
      distinctByUniqueChildNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uniqueChildNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<ClinicalChild, ClinicalChild, QDistinct> distinctByVillage(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'village', caseSensitive: caseSensitive);
    });
  }
}

extension ClinicalChildQueryProperty
    on QueryBuilder<ClinicalChild, ClinicalChild, QQueryProperty> {
  QueryBuilder<ClinicalChild, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ClinicalChild, String, QQueryOperations>
      caregiverContactsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'caregiverContacts');
    });
  }

  QueryBuilder<ClinicalChild, String, QQueryOperations>
      caregiverNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'caregiverName');
    });
  }

  QueryBuilder<ClinicalChild, String?, QQueryOperations> chpContactsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chpContacts');
    });
  }

  QueryBuilder<ClinicalChild, String?, QQueryOperations> chpNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chpName');
    });
  }

  QueryBuilder<ClinicalChild, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<ClinicalChild, String?, QQueryOperations> cwcNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cwcNumber');
    });
  }

  QueryBuilder<ClinicalChild, DateTime?, QQueryOperations>
      dateOfBirthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dateOfBirth');
    });
  }

  QueryBuilder<ClinicalChild, DateTime, QQueryOperations>
      enrollmentDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'enrollmentDate');
    });
  }

  QueryBuilder<ClinicalChild, String?, QQueryOperations>
      facilityCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'facilityCode');
    });
  }

  QueryBuilder<ClinicalChild, String, QQueryOperations> firstNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firstName');
    });
  }

  QueryBuilder<ClinicalChild, String, QQueryOperations> lastNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastName');
    });
  }

  QueryBuilder<ClinicalChild, String, QQueryOperations> localChildIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localChildId');
    });
  }

  QueryBuilder<ClinicalChild, String?, QQueryOperations>
      remoteChildIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'remoteChildId');
    });
  }

  QueryBuilder<ClinicalChild, String, QQueryOperations> sexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sex');
    });
  }

  QueryBuilder<ClinicalChild, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<ClinicalChild, String?, QQueryOperations>
      uniqueChildNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uniqueChildNumber');
    });
  }

  QueryBuilder<ClinicalChild, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<ClinicalChild, String?, QQueryOperations> villageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'village');
    });
  }
}
