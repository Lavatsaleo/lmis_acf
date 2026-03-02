// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clinical_assessment.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetClinicalAssessmentCollection on Isar {
  IsarCollection<ClinicalAssessment> get clinicalAssessments =>
      this.collection();
}

const ClinicalAssessmentSchema = CollectionSchema(
  name: r'ClinicalAssessment',
  id: -4368470251909778810,
  properties: {
    r'assessmentDate': PropertySchema(
      id: 0,
      name: r'assessmentDate',
      type: IsarType.dateTime,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'dataJson': PropertySchema(
      id: 2,
      name: r'dataJson',
      type: IsarType.string,
    ),
    r'heightCm': PropertySchema(
      id: 3,
      name: r'heightCm',
      type: IsarType.double,
    ),
    r'householdHungerCategory': PropertySchema(
      id: 4,
      name: r'householdHungerCategory',
      type: IsarType.string,
    ),
    r'householdHungerScore': PropertySchema(
      id: 5,
      name: r'householdHungerScore',
      type: IsarType.long,
    ),
    r'localAssessmentId': PropertySchema(
      id: 6,
      name: r'localAssessmentId',
      type: IsarType.string,
    ),
    r'localChildId': PropertySchema(
      id: 7,
      name: r'localChildId',
      type: IsarType.string,
    ),
    r'muacMm': PropertySchema(
      id: 8,
      name: r'muacMm',
      type: IsarType.long,
    ),
    r'pssCategory': PropertySchema(
      id: 9,
      name: r'pssCategory',
      type: IsarType.string,
    ),
    r'pssScore': PropertySchema(
      id: 10,
      name: r'pssScore',
      type: IsarType.long,
    ),
    r'remoteAssessmentId': PropertySchema(
      id: 11,
      name: r'remoteAssessmentId',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 12,
      name: r'status',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 13,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'weightKg': PropertySchema(
      id: 14,
      name: r'weightKg',
      type: IsarType.double,
    )
  },
  estimateSize: _clinicalAssessmentEstimateSize,
  serialize: _clinicalAssessmentSerialize,
  deserialize: _clinicalAssessmentDeserialize,
  deserializeProp: _clinicalAssessmentDeserializeProp,
  idName: r'id',
  indexes: {
    r'localAssessmentId': IndexSchema(
      id: 2143367535401275993,
      name: r'localAssessmentId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'localAssessmentId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'localChildId': IndexSchema(
      id: -5289314306964570328,
      name: r'localChildId',
      unique: false,
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
  getId: _clinicalAssessmentGetId,
  getLinks: _clinicalAssessmentGetLinks,
  attach: _clinicalAssessmentAttach,
  version: '3.1.0+1',
);

int _clinicalAssessmentEstimateSize(
  ClinicalAssessment object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.dataJson.length * 3;
  {
    final value = object.householdHungerCategory;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.localAssessmentId.length * 3;
  bytesCount += 3 + object.localChildId.length * 3;
  {
    final value = object.pssCategory;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.remoteAssessmentId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.status.length * 3;
  return bytesCount;
}

void _clinicalAssessmentSerialize(
  ClinicalAssessment object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.assessmentDate);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.dataJson);
  writer.writeDouble(offsets[3], object.heightCm);
  writer.writeString(offsets[4], object.householdHungerCategory);
  writer.writeLong(offsets[5], object.householdHungerScore);
  writer.writeString(offsets[6], object.localAssessmentId);
  writer.writeString(offsets[7], object.localChildId);
  writer.writeLong(offsets[8], object.muacMm);
  writer.writeString(offsets[9], object.pssCategory);
  writer.writeLong(offsets[10], object.pssScore);
  writer.writeString(offsets[11], object.remoteAssessmentId);
  writer.writeString(offsets[12], object.status);
  writer.writeDateTime(offsets[13], object.updatedAt);
  writer.writeDouble(offsets[14], object.weightKg);
}

ClinicalAssessment _clinicalAssessmentDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ClinicalAssessment();
  object.assessmentDate = reader.readDateTime(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.dataJson = reader.readString(offsets[2]);
  object.heightCm = reader.readDoubleOrNull(offsets[3]);
  object.householdHungerCategory = reader.readStringOrNull(offsets[4]);
  object.householdHungerScore = reader.readLongOrNull(offsets[5]);
  object.id = id;
  object.localAssessmentId = reader.readString(offsets[6]);
  object.localChildId = reader.readString(offsets[7]);
  object.muacMm = reader.readLongOrNull(offsets[8]);
  object.pssCategory = reader.readStringOrNull(offsets[9]);
  object.pssScore = reader.readLongOrNull(offsets[10]);
  object.remoteAssessmentId = reader.readStringOrNull(offsets[11]);
  object.status = reader.readString(offsets[12]);
  object.updatedAt = reader.readDateTime(offsets[13]);
  object.weightKg = reader.readDoubleOrNull(offsets[14]);
  return object;
}

P _clinicalAssessmentDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDoubleOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readLongOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readLongOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readDateTime(offset)) as P;
    case 14:
      return (reader.readDoubleOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _clinicalAssessmentGetId(ClinicalAssessment object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _clinicalAssessmentGetLinks(
    ClinicalAssessment object) {
  return [];
}

void _clinicalAssessmentAttach(
    IsarCollection<dynamic> col, Id id, ClinicalAssessment object) {
  object.id = id;
}

extension ClinicalAssessmentByIndex on IsarCollection<ClinicalAssessment> {
  Future<ClinicalAssessment?> getByLocalAssessmentId(String localAssessmentId) {
    return getByIndex(r'localAssessmentId', [localAssessmentId]);
  }

  ClinicalAssessment? getByLocalAssessmentIdSync(String localAssessmentId) {
    return getByIndexSync(r'localAssessmentId', [localAssessmentId]);
  }

  Future<bool> deleteByLocalAssessmentId(String localAssessmentId) {
    return deleteByIndex(r'localAssessmentId', [localAssessmentId]);
  }

  bool deleteByLocalAssessmentIdSync(String localAssessmentId) {
    return deleteByIndexSync(r'localAssessmentId', [localAssessmentId]);
  }

  Future<List<ClinicalAssessment?>> getAllByLocalAssessmentId(
      List<String> localAssessmentIdValues) {
    final values = localAssessmentIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'localAssessmentId', values);
  }

  List<ClinicalAssessment?> getAllByLocalAssessmentIdSync(
      List<String> localAssessmentIdValues) {
    final values = localAssessmentIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'localAssessmentId', values);
  }

  Future<int> deleteAllByLocalAssessmentId(
      List<String> localAssessmentIdValues) {
    final values = localAssessmentIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'localAssessmentId', values);
  }

  int deleteAllByLocalAssessmentIdSync(List<String> localAssessmentIdValues) {
    final values = localAssessmentIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'localAssessmentId', values);
  }

  Future<Id> putByLocalAssessmentId(ClinicalAssessment object) {
    return putByIndex(r'localAssessmentId', object);
  }

  Id putByLocalAssessmentIdSync(ClinicalAssessment object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'localAssessmentId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByLocalAssessmentId(List<ClinicalAssessment> objects) {
    return putAllByIndex(r'localAssessmentId', objects);
  }

  List<Id> putAllByLocalAssessmentIdSync(List<ClinicalAssessment> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'localAssessmentId', objects,
        saveLinks: saveLinks);
  }
}

extension ClinicalAssessmentQueryWhereSort
    on QueryBuilder<ClinicalAssessment, ClinicalAssessment, QWhere> {
  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ClinicalAssessmentQueryWhere
    on QueryBuilder<ClinicalAssessment, ClinicalAssessment, QWhereClause> {
  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterWhereClause>
      idNotEqualTo(Id id) {
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterWhereClause>
      idBetween(
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterWhereClause>
      localAssessmentIdEqualTo(String localAssessmentId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'localAssessmentId',
        value: [localAssessmentId],
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterWhereClause>
      localAssessmentIdNotEqualTo(String localAssessmentId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localAssessmentId',
              lower: [],
              upper: [localAssessmentId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localAssessmentId',
              lower: [localAssessmentId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localAssessmentId',
              lower: [localAssessmentId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'localAssessmentId',
              lower: [],
              upper: [localAssessmentId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterWhereClause>
      localChildIdEqualTo(String localChildId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'localChildId',
        value: [localChildId],
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterWhereClause>
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

extension ClinicalAssessmentQueryFilter
    on QueryBuilder<ClinicalAssessment, ClinicalAssessment, QFilterCondition> {
  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      assessmentDateEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assessmentDate',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      assessmentDateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assessmentDate',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      assessmentDateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assessmentDate',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      assessmentDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assessmentDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      dataJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      dataJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      dataJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      dataJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dataJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      dataJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      dataJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      dataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      dataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'dataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      dataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      dataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'dataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      heightCmIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'heightCm',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      heightCmIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'heightCm',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      heightCmEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'heightCm',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      heightCmGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'heightCm',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      heightCmLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'heightCm',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      heightCmBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'heightCm',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerCategoryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'householdHungerCategory',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerCategoryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'householdHungerCategory',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerCategoryEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'householdHungerCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerCategoryGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'householdHungerCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerCategoryLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'householdHungerCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerCategoryBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'householdHungerCategory',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerCategoryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'householdHungerCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerCategoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'householdHungerCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerCategoryContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'householdHungerCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerCategoryMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'householdHungerCategory',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerCategoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'householdHungerCategory',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerCategoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'householdHungerCategory',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerScoreIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'householdHungerScore',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerScoreIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'householdHungerScore',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerScoreEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'householdHungerScore',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerScoreGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'householdHungerScore',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerScoreLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'householdHungerScore',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      householdHungerScoreBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'householdHungerScore',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      idLessThan(
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      idBetween(
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localAssessmentIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localAssessmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localAssessmentIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'localAssessmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localAssessmentIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'localAssessmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localAssessmentIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'localAssessmentId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localAssessmentIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'localAssessmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localAssessmentIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'localAssessmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localAssessmentIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'localAssessmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localAssessmentIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'localAssessmentId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localAssessmentIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localAssessmentId',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localAssessmentIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'localAssessmentId',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localChildIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'localChildId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localChildIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'localChildId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localChildIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localChildId',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      localChildIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'localChildId',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      muacMmIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'muacMm',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      muacMmIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'muacMm',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      muacMmEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'muacMm',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      muacMmGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'muacMm',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      muacMmLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'muacMm',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      muacMmBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'muacMm',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssCategoryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'pssCategory',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssCategoryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'pssCategory',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssCategoryEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pssCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssCategoryGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pssCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssCategoryLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pssCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssCategoryBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pssCategory',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssCategoryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'pssCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssCategoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'pssCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssCategoryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pssCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssCategoryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pssCategory',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssCategoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pssCategory',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssCategoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pssCategory',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssScoreIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'pssScore',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssScoreIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'pssScore',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssScoreEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pssScore',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssScoreGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pssScore',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssScoreLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pssScore',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      pssScoreBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pssScore',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      remoteAssessmentIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'remoteAssessmentId',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      remoteAssessmentIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'remoteAssessmentId',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      remoteAssessmentIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remoteAssessmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      remoteAssessmentIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'remoteAssessmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      remoteAssessmentIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'remoteAssessmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      remoteAssessmentIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'remoteAssessmentId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      remoteAssessmentIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'remoteAssessmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      remoteAssessmentIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'remoteAssessmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      remoteAssessmentIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'remoteAssessmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      remoteAssessmentIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'remoteAssessmentId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      remoteAssessmentIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remoteAssessmentId',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      remoteAssessmentIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'remoteAssessmentId',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
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

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      weightKgIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'weightKg',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      weightKgIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'weightKg',
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      weightKgEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'weightKg',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      weightKgGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'weightKg',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      weightKgLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'weightKg',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterFilterCondition>
      weightKgBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'weightKg',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }
}

extension ClinicalAssessmentQueryObject
    on QueryBuilder<ClinicalAssessment, ClinicalAssessment, QFilterCondition> {}

extension ClinicalAssessmentQueryLinks
    on QueryBuilder<ClinicalAssessment, ClinicalAssessment, QFilterCondition> {}

extension ClinicalAssessmentQuerySortBy
    on QueryBuilder<ClinicalAssessment, ClinicalAssessment, QSortBy> {
  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByAssessmentDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assessmentDate', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByAssessmentDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assessmentDate', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByDataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByDataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByHeightCm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heightCm', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByHeightCmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heightCm', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByHouseholdHungerCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'householdHungerCategory', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByHouseholdHungerCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'householdHungerCategory', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByHouseholdHungerScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'householdHungerScore', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByHouseholdHungerScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'householdHungerScore', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByLocalAssessmentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localAssessmentId', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByLocalAssessmentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localAssessmentId', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByLocalChildId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localChildId', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByLocalChildIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localChildId', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByMuacMm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'muacMm', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByMuacMmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'muacMm', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByPssCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pssCategory', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByPssCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pssCategory', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByPssScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pssScore', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByPssScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pssScore', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByRemoteAssessmentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteAssessmentId', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByRemoteAssessmentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteAssessmentId', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      sortByWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.desc);
    });
  }
}

extension ClinicalAssessmentQuerySortThenBy
    on QueryBuilder<ClinicalAssessment, ClinicalAssessment, QSortThenBy> {
  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByAssessmentDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assessmentDate', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByAssessmentDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assessmentDate', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByDataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByDataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByHeightCm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heightCm', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByHeightCmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heightCm', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByHouseholdHungerCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'householdHungerCategory', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByHouseholdHungerCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'householdHungerCategory', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByHouseholdHungerScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'householdHungerScore', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByHouseholdHungerScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'householdHungerScore', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByLocalAssessmentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localAssessmentId', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByLocalAssessmentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localAssessmentId', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByLocalChildId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localChildId', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByLocalChildIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localChildId', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByMuacMm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'muacMm', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByMuacMmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'muacMm', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByPssCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pssCategory', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByPssCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pssCategory', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByPssScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pssScore', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByPssScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pssScore', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByRemoteAssessmentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteAssessmentId', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByRemoteAssessmentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteAssessmentId', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.asc);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QAfterSortBy>
      thenByWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.desc);
    });
  }
}

extension ClinicalAssessmentQueryWhereDistinct
    on QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct> {
  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByAssessmentDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assessmentDate');
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByDataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByHeightCm() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'heightCm');
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByHouseholdHungerCategory({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'householdHungerCategory',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByHouseholdHungerScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'householdHungerScore');
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByLocalAssessmentId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localAssessmentId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByLocalChildId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localChildId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByMuacMm() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'muacMm');
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByPssCategory({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pssCategory', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByPssScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pssScore');
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByRemoteAssessmentId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'remoteAssessmentId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<ClinicalAssessment, ClinicalAssessment, QDistinct>
      distinctByWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'weightKg');
    });
  }
}

extension ClinicalAssessmentQueryProperty
    on QueryBuilder<ClinicalAssessment, ClinicalAssessment, QQueryProperty> {
  QueryBuilder<ClinicalAssessment, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ClinicalAssessment, DateTime, QQueryOperations>
      assessmentDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assessmentDate');
    });
  }

  QueryBuilder<ClinicalAssessment, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<ClinicalAssessment, String, QQueryOperations>
      dataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dataJson');
    });
  }

  QueryBuilder<ClinicalAssessment, double?, QQueryOperations>
      heightCmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'heightCm');
    });
  }

  QueryBuilder<ClinicalAssessment, String?, QQueryOperations>
      householdHungerCategoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'householdHungerCategory');
    });
  }

  QueryBuilder<ClinicalAssessment, int?, QQueryOperations>
      householdHungerScoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'householdHungerScore');
    });
  }

  QueryBuilder<ClinicalAssessment, String, QQueryOperations>
      localAssessmentIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localAssessmentId');
    });
  }

  QueryBuilder<ClinicalAssessment, String, QQueryOperations>
      localChildIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localChildId');
    });
  }

  QueryBuilder<ClinicalAssessment, int?, QQueryOperations> muacMmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'muacMm');
    });
  }

  QueryBuilder<ClinicalAssessment, String?, QQueryOperations>
      pssCategoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pssCategory');
    });
  }

  QueryBuilder<ClinicalAssessment, int?, QQueryOperations> pssScoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pssScore');
    });
  }

  QueryBuilder<ClinicalAssessment, String?, QQueryOperations>
      remoteAssessmentIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'remoteAssessmentId');
    });
  }

  QueryBuilder<ClinicalAssessment, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<ClinicalAssessment, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<ClinicalAssessment, double?, QQueryOperations>
      weightKgProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'weightKg');
    });
  }
}
