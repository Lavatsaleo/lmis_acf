import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../data/local/clinical/clinical_assessment_repo.dart';
import '../data/local/clinical/clinical_child_repo.dart';
import '../data/local/isar/clinical_assessment.dart';
import '../data/local/isar/clinical_child.dart';
import '../data/local/isar/sync_queue_item.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../core/sync/sync_service.dart';

import '../utils/growth/growth_models.dart';
import '../utils/growth/whz_calculator.dart';
import '../widgets/acf_brand.dart';


enum InDepthAssessmentMode {
  enrollment,
  discharge,
}


class ClinicalInDepthAssessmentScreen extends StatefulWidget {
  final String localChildId;
  final InDepthAssessmentMode mode;
  final String? draftEnrollmentJson; // only required for enrollment
  final String? editAssessmentId; // when editing a saved local assessment
  final VoidCallback? onFinalizeQueued;

  const ClinicalInDepthAssessmentScreen({
    super.key,
    required this.localChildId,
    this.mode = InDepthAssessmentMode.enrollment,
    this.draftEnrollmentJson,
    this.editAssessmentId,
    this.onFinalizeQueued,
  });

  @override
  State<ClinicalInDepthAssessmentScreen> createState() => _ClinicalInDepthAssessmentScreenState();
}

class _ClinicalInDepthAssessmentScreenState extends State<ClinicalInDepthAssessmentScreen> {
  final _uuid = const Uuid();
  final ClinicalChildRepo _childRepo = ClinicalChildRepo();
  final ClinicalAssessmentRepo _assessRepo = ClinicalAssessmentRepo();
  final SyncQueueRepo _queueRepo = SyncQueueRepo();
  final SyncService _syncService = SyncService();

  ClinicalChild? _child;
  ClinicalAssessment? _editing;
  SyncQueueItem? _enrollQueueItem; // only needed when editing enrollment before sync
  bool _loading = true;
  bool _saving = false;

  // --- Anthropometry ---
  final TextEditingController _weightKg = TextEditingController();
  final TextEditingController _heightCm = TextEditingController();
  final TextEditingController _muacMm = TextEditingController();

  // --- Visit (dispense + next appointment) ---
  final TextEditingController _sachetsDispensed = TextEditingController();
  DateTime? _nextAppointmentDate;
  final TextEditingController _visitNotes = TextEditingController();

  // --- Exit (discharge) ---
  DateTime? _exitDate;
  String? _exitOutcome;

  // --- Socio-economic ---
  final TextEditingController _hhSize = TextEditingController();
  final TextEditingController _u5Count = TextEditingController();
  String? _incomeSource;
  bool? _enrolledAssistance; // cash transfer / food assistance
  final TextEditingController _assistanceProgramName = TextEditingController();

  // --- Child Care and Protection ---
  String? _dailyCareProvider;
  bool? _underBothParents;
  final TextEditingController _primaryCaregiver = TextEditingController();
  bool? _separated2Weeks;
  String? _abuseAware; // Yes / No / Prefer not to say
  bool? _enrolledDaycare;

  // --- Illness & care-seeking ---
  bool _sickPast2Weeks = false;
  final Set<String> _illnesses = <String>{};
  bool _soughtCare = false;
  final Set<String> _careSources = <String>{};

  // --- Disability ---
  bool _diagnosedDisability = false;
  bool _hasDisabilitySupport = false;
  final Set<String> _disabilityConditions = <String>{};
  final TextEditingController _disabilityOther = TextEditingController();
  final TextEditingController _disabilityServiceProvider = TextEditingController();

  // --- Infant/Young Child Feeding (IYCF) ---
  bool _breastfeeding = true;
  final TextEditingController _breastfeedingStoppedAtMonths = TextEditingController(); // if not breastfeeding
  bool _complementaryFeeding = true;
  final TextEditingController _feedingTimesYesterday = TextEditingController(); // meals/snacks in last 24h
  final Set<String> _foodGroups = <String>{};

  // Illness feeding change (skip logic: only if sick == true)
  bool _feedingChanged = false;
  final Set<String> _feedingChangePatterns = <String>{};

  // --- PSS (5 items, 0-2 each) ---
  final List<int> _pss = List<int>.filled(5, 0);

  // --- WASH ---
  String? _waterSource;
  String? _waterCollectionTime;
  String? _waterTreatment;
  final Set<String> _waterTreatmentMethods = <String>{};
  final Set<String> _handwashInstances = <String>{};
  String? _toiletType;

  // --- Household Hunger Scale ---
  bool _hhsQ1 = false;
  String? _hhsF1;
  bool _hhsQ2 = false;
  String? _hhsF2;
  bool _hhsQ3 = false;
  String? _hhsF3;

  // --- Analysis ---
  final Set<String> _analysisFactors = <String>{};
  String? _analysisDominant;
  final TextEditingController _analysisOther = TextEditingController();
  final List<_ActionPlanRow> _actionPlan = <_ActionPlanRow>[ _ActionPlanRow() ];

  // --- Free notes ---
  final TextEditingController _freeNotes = TextEditingController();

  int? _ageMonths;

  static DateTime? _tryParseYmd(String v) {
    final s = v.trim();
    if (s.isEmpty) return null;
    try {
      final parts = s.split('-');
      if (parts.length != 3) return null;
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.mode == InDepthAssessmentMode.discharge) {
      _exitDate = DateTime.now();
    }
    _load();
  }

  @override
  void dispose() {
    _weightKg.dispose();
    _heightCm.dispose();
    _muacMm.dispose();
    _sachetsDispensed.dispose();
    _visitNotes.dispose();
    _hhSize.dispose();
    _u5Count.dispose();
    _assistanceProgramName.dispose();
    _primaryCaregiver.dispose();
    _breastfeedingStoppedAtMonths.dispose();
    _feedingTimesYesterday.dispose();
    _disabilityOther.dispose();
    _disabilityServiceProvider.dispose();
    _analysisOther.dispose();
    _freeNotes.dispose();
    for (final r in _actionPlan) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await _childRepo.findByLocalId(widget.localChildId);

      // If we're editing an already saved local assessment, load it and prefill the form.
      ClinicalAssessment? existing;
      SyncQueueItem? enrollItem;
      final editId = (widget.editAssessmentId ?? '').trim();
      if (editId.isNotEmpty) {
        existing = await _assessRepo.findByLocalAssessmentId(editId);
        if (existing != null) {
          try {
            final m = (jsonDecode(existing.dataJson) as Map).cast<String, dynamic>();
            _prefillFromData(m);

            final t = (m['encounterType'] ?? '').toString().toUpperCase();
            if (t == 'ENROLLMENT' && c != null) {
              enrollItem = await _queueRepo.findLatestForEntity('clinical_enroll', c.localChildId);
            }
          } catch (_) {
            // ignore, show empty form
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _child = c;
        _editing = existing;
        _enrollQueueItem = enrollItem;
        _ageMonths = _computeAgeMonths(c?.dateOfBirth);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _prefillFromData(Map<String, dynamic> data) {
    Map<String, dynamic> m(Map? v) => (v as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    List<String> l(List? v) => (v as List?)?.map((e) => e.toString()).toList() ?? const <String>[];

    final anthro = m(data['anthropometry'] as Map?);
    final se = m(data['socioEconomic'] as Map?);
    final ccp = m(data['childCareProtection'] as Map?);
    final ill = m(data['illness'] as Map?);
    final dis = m(data['disability'] as Map?);
    final iycf = m(data['nutrition'] as Map?);
    final pss = m(data['pss'] as Map?);
    final wash = m(data['wash'] as Map?);
    final hhs = m(data['householdHungerScale'] as Map?);
    final analysis = m(data['analysis'] as Map?);
    final visit = m(data['visit'] as Map?);
    final exit = m(data['exit'] as Map?);

    // Anthropometry
    final w = anthro['weightKg'];
    final h = anthro['heightCm'];
    final mu = anthro['muacMm'];
    if (w != null) _weightKg.text = '$w';
    if (h != null) _heightCm.text = '$h';
    if (mu != null) _muacMm.text = '$mu';

    // Visit (enrollment only)
    final sachets = visit['sachetsDispensed'];
    if (sachets != null) _sachetsDispensed.text = '$sachets';
    final nap = (visit['nextAppointmentDate'] ?? '').toString();
    final napParsed = _tryParseYmd(nap);
    if (napParsed != null) _nextAppointmentDate = napParsed;
    final vn = (visit['notes'] ?? '').toString();
    if (vn.trim().isNotEmpty) _visitNotes.text = vn;

    // Exit (discharge only)
    final exd = (exit['exitDate'] ?? '').toString();
    final exParsed = _tryParseYmd(exd);
    if (exParsed != null) _exitDate = exParsed;
    final outcome = (exit['outcome'] ?? '').toString();
    if (outcome.trim().isNotEmpty) _exitOutcome = outcome;

    // Socio-economic
    final hh = se['householdSize'];
    final u5 = se['childrenUnder5'];
    if (hh != null) _hhSize.text = '$hh';
    if (u5 != null) _u5Count.text = '$u5';
    _incomeSource = (se['mainIncomeSource'] ?? _incomeSource)?.toString();
    final eia = se['enrolledInAssistance'];
    if (eia is bool) _enrolledAssistance = eia;
    final apn = (se['assistanceProgramName'] ?? '').toString();
    if (apn.trim().isNotEmpty) _assistanceProgramName.text = apn;

    // Child Care & Protection
    _dailyCareProvider = (ccp['dailyCareProvider'] ?? _dailyCareProvider)?.toString();
    final ubp = ccp['underCareOfBothBiologicalParents'];
    if (ubp is bool) _underBothParents = ubp;
    final pcg = (ccp['primaryCaregiverIfNotBothParents'] ?? '').toString();
    if (pcg.trim().isNotEmpty) _primaryCaregiver.text = pcg;
    final sep = ccp['separatedMoreThan2WeeksPast6Months'];
    if (sep is bool) _separated2Weeks = sep;
    _abuseAware = (ccp['abuseAware'] ?? _abuseAware)?.toString();
    final edc = ccp['enrolledInDaycare'];
    if (edc is bool) _enrolledDaycare = edc;

    // Illness
    final sp2w = ill['sickPast2Weeks'];
    _sickPast2Weeks = sp2w is bool ? sp2w : false;
    _illnesses
      ..clear()
      ..addAll(l(ill['illnesses'] as List?));
    final sc = ill['soughtCare'];
    _soughtCare = sc is bool ? sc : false;
    _careSources
      ..clear()
      ..addAll(l(ill['careSources'] as List?));

    // Disability
    final dd = dis['diagnosedDisability'];
    _diagnosedDisability = dd is bool ? dd : false;
    final hds = dis['hasDisabilitySupport'];
    _hasDisabilitySupport = hds is bool ? hds : false;
    _disabilityConditions
      ..clear()
      ..addAll(l(dis['conditions'] as List?));
    final other = (dis['otherSpecify'] ?? '').toString();
    if (other.trim().isNotEmpty) _disabilityOther.text = other;
    final sp = (dis['serviceProvider'] ?? '').toString();
    if (sp.trim().isNotEmpty) _disabilityServiceProvider.text = sp;

    // Nutrition / IYCF
    final bf = iycf['breastfeeding'];
    _breastfeeding = bf is bool ? bf : _breastfeeding;
    final stopped = (iycf['breastfeedingStoppedAtMonths'] ?? '').toString();
    if (stopped.trim().isNotEmpty) _breastfeedingStoppedAtMonths.text = stopped;
    final cf = iycf['complementaryFeeding'];
    _complementaryFeeding = cf is bool ? cf : _complementaryFeeding;
    final ft = (iycf['feedingTimesYesterday'] ?? '').toString();
    if (ft.trim().isNotEmpty) _feedingTimesYesterday.text = ft;
    _foodGroups
      ..clear()
      ..addAll(l(iycf['foodGroups'] as List?));
    final fc = iycf['feedingChangedDuringIllness'];
    _feedingChanged = fc is bool ? fc : _feedingChanged;
    _feedingChangePatterns
      ..clear()
      ..addAll(l(iycf['feedingChangePatterns'] as List?));

    // PSS
    final pssItems = l(pss['items'] as List?);
    for (int i = 0; i < _pss.length && i < pssItems.length; i++) {
      _pss[i] = int.tryParse(pssItems[i]) ?? _pss[i];
    }

    // WASH
    _waterSource = (wash['waterSource'] ?? _waterSource)?.toString();
    _waterCollectionTime = (wash['waterCollectionTime'] ?? _waterCollectionTime)?.toString();
    _waterTreatment = (wash['waterTreatment'] ?? _waterTreatment)?.toString();
    _waterTreatmentMethods
      ..clear()
      ..addAll(l(wash['waterTreatmentMethods'] as List?));
    _handwashInstances
      ..clear()
      ..addAll(l(wash['handwashInstances'] as List?));
    _toiletType = (wash['toiletType'] ?? _toiletType)?.toString();

    // HHS
    final q1 = hhs['q1_noFood'];
    _hhsQ1 = q1 is bool ? q1 : _hhsQ1;
    _hhsF1 = (hhs['q1_freq'] ?? _hhsF1)?.toString();
    final q2 = hhs['q2_sleepHungry'];
    _hhsQ2 = q2 is bool ? q2 : _hhsQ2;
    _hhsF2 = (hhs['q2_freq'] ?? _hhsF2)?.toString();
    final q3 = hhs['q3_wholeDayNight'];
    _hhsQ3 = q3 is bool ? q3 : _hhsQ3;
    _hhsF3 = (hhs['q3_freq'] ?? _hhsF3)?.toString();

    // Analysis
    _analysisFactors
      ..clear()
      ..addAll(l(analysis['contributingFactors'] as List?));
    _analysisDominant = (analysis['dominantFactor'] ?? _analysisDominant)?.toString();
    final ao = (analysis['otherFactor'] ?? '').toString();
    if (ao.trim().isNotEmpty) _analysisOther.text = ao;

    // Action plan
    for (final r in _actionPlan) {
      r.dispose();
    }
    _actionPlan.clear();
    final ap = analysis['actionPlan'];
    if (ap is List && ap.isNotEmpty) {
      for (final it in ap) {
        if (it is! Map) continue;
        final mm = it.cast<String, dynamic>();
        final row = _ActionPlanRow();
        row.problem.text = (mm['problem'] ?? '').toString();
        row.intervention.text = (mm['intervention'] ?? '').toString();
        row.responsible.text = (mm['responsible'] ?? '').toString();
        row.followUpDate.text = (mm['followUpDate'] ?? '').toString();
        row.remarks.text = (mm['remarks'] ?? '').toString();
        _actionPlan.add(row);
      }
    }
    if (_actionPlan.isEmpty) _actionPlan.add(_ActionPlanRow());

    // Free notes
    final fn = (data['freeNotes'] ?? '').toString();
    if (fn.trim().isNotEmpty) _freeNotes.text = fn;
  }

  Future<void> _pickNextAppointmentDate() async {
    // Next appointment must not be before the assessment (visit) date.
    final assessmentDate = _editing?.assessmentDate ?? DateTime.now();
    final visitDay = DateTime(assessmentDate.year, assessmentDate.month, assessmentDate.day);
    final now = DateTime.now();
    final initialRaw = _nextAppointmentDate ?? visitDay.add(const Duration(days: 14));
    final initial = initialRaw.isBefore(visitDay) ? visitDay : initialRaw;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: visitDay,
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked == null) return;
    setState(() => _nextAppointmentDate = picked);
  }

  Future<void> _pickExitDate() async {
    final now = DateTime.now();
    final initial = _exitDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _exitDate = picked);
  }

  int? _computeAgeMonths(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    int months = (now.year - dob.year) * 12 + (now.month - dob.month);
    if (now.day < dob.day) months -= 1;
    if (months < 0) months = 0;
    return months;
  }

  int _monthsBetween(DateTime start, DateTime end) {
    int months = (end.year - start.year) * 12 + (end.month - start.month);
    if (end.day < start.day) months -= 1;
    if (months < 0) months = 0;
    return months;
  }
  GrowthSex _parseSex(String v) {
    final s = v.toUpperCase();
    if (s.contains('FEMALE')) return GrowthSex.female;
    return GrowthSex.male;
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }


  /// Returns computed notes + suggested contributing factors (for the Analysis section),
  /// strictly following the Word form instructions where possible.
  Map<String, dynamic> _computeAnalysisPreview({
    required int? feedingTimes,
    required int? minFeeds,
    required bool? feedingFrequencyOk,
    required int pssScore,
    required String pssCategory,
    required int hhsScore,
    required String hhsCategory,
  }) {
    final notes = <String>[];
    final suggestedFactors = <String>{};

    // --- Illness & care-seeking ---
    if (_sickPast2Weeks) {
      notes.add('Child was sick in the past 1–2 weeks. Provide nutrition education and encourage seeking care at appropriate facilities.');
      suggestedFactors.add('Recent illness (e.g., diarrhea, ARI, fever)');

      // Poor health seeking: NO to seeking care OR sought care from "poor sources".
      final poorSources = <String>{
        'Relative or friend',
        'Traditional healer',
        'Herbal (self/herbalist)',
        'Shop/Kiosk',
      };

      final goodSources = _goodCareSources;

      if (!_soughtCare) {
        notes.add('Caregiver did not seek medical assistance during recent illness. Counsel on prompt care-seeking.');
        suggestedFactors.add('Lack of access to health services');
      } else {
        if (_careSources.any(poorSources.contains)) {
          notes.add('Caregiver sought care from informal sources (e.g., friend, traditional/herbal, shop/kiosk). Counsel on appropriate facilities.');
          suggestedFactors.add('Lack of access to health services');
        }

        // If they sought help from places apart from formal facilities, educate them.
        final hasNonFormal = _careSources.any((s) => !goodSources.contains(s));
        if (hasNonFormal) {
          notes.add('Caregiver sought help from non-facility sources. Educate on seeking assistance from formal health facilities/clinics.');
        }

        // If they never used formal sources at all, treat as poor access.
        final hasFormal = _careSources.any(goodSources.contains);
        if (!hasFormal) {
          suggestedFactors.add('Lack of access to health services');
        }
      }
    }

    // --- Disability ---
    if (_diagnosedDisability) {
      suggestedFactors.add('Disability or developmental delay affecting feeding or care');
      if (!_hasDisabilitySupport) {
        notes.add('Child has a disability but lacks support/care. Link caregiver to available disability services.');
      }
    }

    // --- IYCF (for 6–23 months) ---
    final ageMonths = _ageMonths;
    final inIYCFRange = ageMonths != null && ageMonths >= 6 && ageMonths <= 23;

    if (inIYCFRange) {
      if (feedingFrequencyOk == false) {
        notes.add('Child feeding frequency is below recommended minimum for age. Counsel caregiver on age-appropriate meal frequency.');
        suggestedFactors.add('Inadequate breastfeeding or complementary feeding');
      }

      if (_foodGroups.isNotEmpty && _foodGroups.length < 5) {
        notes.add('Low dietary diversity (<5 food groups). Counsel caregiver on improving diet diversity.');
        suggestedFactors.add('Inadequate breastfeeding or complementary feeding');
      }

      // Combined rule from the form (interpreting Q1, Q3, Q5, Q6):
      if (_breastfeeding == false &&
          _complementaryFeeding == false &&
          feedingFrequencyOk == false &&
          _foodGroups.isNotEmpty &&
          _foodGroups.length < 5) {
        notes.add('Inadequate breastfeeding/complementary feeding practices identified. Provide targeted IYCF counselling.');
        suggestedFactors.add('Inadequate breastfeeding or complementary feeding');
      }
    }

    // Illness feeding changes (skip logic: only relevant if child was sick)
    if (_sickPast2Weeks && _feedingChanged) {
      notes.add('Child feeding changed during illness. Counsel caregiver on maintaining feeding and fluids during illness.');
      suggestedFactors.add('Inadequate breastfeeding or complementary feeding');
    }

    // --- PSS ---
    if (pssScore >= 3) {
      notes.add('Caregiver psychosocial distress: $pssCategory (score $pssScore/10). Provide PSS support or refer as needed.');
    }
    if (_pss.isNotEmpty && _pss.last > 0) {
      notes.add('Risk alert: caregiver reported thoughts of harming self or others. Escalate immediately per safeguarding protocol.');
    }

    // --- HHS ---
    if (hhsScore >= 2) {
      notes.add('Household hunger: $hhsCategory (score $hhsScore/6). Consider referrals for food/cash support or social services.');
      suggestedFactors.add('Household food insecurity');
    }


    // --- Child care & protection ---
    if (_underBothParents == false) {
      notes.add('Child is not under the care of both biological parents. Consider social support/referral if needed.');
      suggestedFactors.add('Social vulnerability (e.g., orphaned child, single-parent household)');
    }
    if (_separated2Weeks == true) {
      notes.add('Child has been separated from caregiver for more than 2 weeks in the past 6 months. Flag potential protection concerns.');
      suggestedFactors.add('Child neglect or child protection concerns');
    }
    if (_abuseAware == 'Yes') {
      notes.add('Caregiver reports possible physical/emotional abuse. Follow safeguarding and referral procedures.');
      suggestedFactors.add('Child neglect or child protection concerns');
    }

    // --- Socio-economic ---
    if (_enrolledAssistance == false && hhsScore >= 2) {
      notes.add('Household reports hunger but is not enrolled in cash/food assistance. Consider referral to appropriate safety nets.');
      suggestedFactors.add('Household food insecurity');
      suggestedFactors.add('Social vulnerability (e.g., orphaned child, single-parent household)');
    }

    // --- WASH ---
    final unprotectedWaterSources = <String>{
      'Unprotected hand-dug well',
      'Surface water (lake, pond, dam, river)',
      'Unprotected spring',
    };

    if (_waterSource != null && unprotectedWaterSources.contains(_waterSource)) {
      notes.add('Household uses an unprotected water source. Counsel on safe water and treatment.');
      suggestedFactors.add('Poor WASH conditions (unsafe water, lack of sanitation)');
    }

    // Treating water: if sometimes/never, or poor method (let stand / other).
    if (_waterTreatment == 'Yes, sometimes treat it before drinking' || _waterTreatment == 'No, never treat it before drinking') {
      notes.add('Household does not consistently treat drinking water. Counsel on consistent water treatment.');
      suggestedFactors.add('Poor WASH conditions (unsafe water, lack of sanitation)');
    }

    if ((_waterTreatment ?? '').startsWith('Yes')) {
      final poorMethods = <String>{'Let it stand and settle', 'Other (specify in notes)'};
      if (_waterTreatmentMethods.any(poorMethods.contains)) {
        notes.add('Water treatment method may be ineffective (e.g., letting it stand/other). Reinforce effective treatment options.');
        suggestedFactors.add('Poor WASH conditions (unsafe water, lack of sanitation)');
      }
    }

    // Handwashing: if any of the 4 critical times missing
    final requiredHandwash = <String>{
      'After toilet',
      'Before cooking',
      'Before eating/serving food',
      'After taking children to the toilet',
    };
    if (!requiredHandwash.every(_handwashInstances.contains)) {
      notes.add('Handwashing practices are incomplete (missing one or more critical times). Provide hygiene education.');
      suggestedFactors.add('Poor WASH conditions (unsafe water, lack of sanitation)');
    }

    // Toilet: poor sanitation per form rule (option 8)
    if (_toiletType == 'No facility, field, bush, plastic bag') {
      notes.add('Household has no sanitation facility (open defecation). Counsel and link to sanitation options.');
      suggestedFactors.add('Poor WASH conditions (unsafe water, lack of sanitation)');
    }

    return {
      'notes': notes,
      'suggestedFactors': suggestedFactors.toList(),
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    final child = _child;
    if (child == null) return;

    double? parseD(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));
    int? parseI(TextEditingController c) => int.tryParse(c.text.trim());

    final weightKg = parseD(_weightKg);
    final heightCm = parseD(_heightCm);

    int? parseMuacMm(TextEditingController c) {
      final raw = c.text.trim();
      if (raw.isEmpty) return null;
      final v = int.tryParse(raw);
      if (v == null) return null;
      // MUAC is captured in millimeters. Keep it as a whole number.
      return v;
    }

    final muacMm = parseMuacMm(_muacMm);

    final feedingTimes = parseI(_feedingTimesYesterday);
    final minFeeds = (_ageMonths != null) ? _minFeeds(_ageMonths!) : null;
    final feedingFrequencyOk = (minFeeds != null && feedingTimes != null) ? feedingTimes >= minFeeds : null;

    final pssScore = _pss.fold<int>(0, (a, b) => a + b);
    final pssCategory = _pssCategory(pssScore);

    final hhsScore = _computeHhsScore();
    final hhsCategory = _hhsCategory(hhsScore);

    // --- WHZ (Weight-for-Length/Height z-score) ---
    final sex = _parseSex(child.sex);
    final whzRes = await const WhzCalculator().compute(
      sex: sex,
      heightCm: heightCm,
      weightKg: weightKg,
      ageMonths: _ageMonths,
    );
    final whzScore = whzRes.z;

    final preview = _computeAnalysisPreview(
      feedingTimes: feedingTimes,
      minFeeds: minFeeds,
      feedingFrequencyOk: feedingFrequencyOk,
      pssScore: pssScore,
      pssCategory: pssCategory,
      hhsScore: hhsScore,
      hhsCategory: hhsCategory,
    );
    final notes = (preview['notes'] as List).cast<String>();
    final suggested = (preview['suggestedFactors'] as List).cast<String>();

    // If user didn't select factors, default to suggested ones (so analysis isn't empty).
    final factorsToSave = _analysisFactors.isNotEmpty ? _analysisFactors.toList() : suggested;

    // Dominant factor: prefer user pick, else first selected/suggested.
    final dominantToSave = (_analysisDominant != null && _analysisDominant!.trim().isNotEmpty)
        ? _analysisDominant
        : (factorsToSave.isNotEmpty ? factorsToSave.first : null);

    final actionPlanToSave = <Map<String, dynamic>>[];
    for (final r in _actionPlan) {
      final m = r.toMap();
      final hasAny = m.values.any((v) => (v ?? '').toString().trim().isNotEmpty);
      if (hasAny) actionPlanToSave.add(m);
    }

    // Preserve original assessment timestamp when editing.
    final assessmentDate = _editing?.assessmentDate ?? DateTime.now();

    final data = <String, dynamic>{
      'encounterType': widget.mode == InDepthAssessmentMode.enrollment ? 'ENROLLMENT' : 'DISCHARGE',
      'anthropometry': {
        'weightKg': weightKg,
        'heightCm': heightCm,
        'muacMm': muacMm,
        'whzScore': whzScore,
        'whzRefType': whzRes.refType?.name,
        'whzOutOfRange': whzRes.outOfRange,
        'whzNote': whzRes.note,
      },
      'socioEconomic': {
        'householdSize': int.tryParse(_hhSize.text.trim()),
        'childrenUnder5': int.tryParse(_u5Count.text.trim()),
        'mainIncomeSource': _incomeSource,
        'enrolledInAssistance': _enrolledAssistance,
        'assistanceProgramName': (_enrolledAssistance == true && _assistanceProgramName.text.trim().isNotEmpty) ? _assistanceProgramName.text.trim() : null,
      },
      'childCareProtection': {
        'dailyCareProvider': _dailyCareProvider,
        'underCareOfBothBiologicalParents': _underBothParents,
        'primaryCaregiverIfNotBothParents': (_underBothParents == false && _primaryCaregiver.text.trim().isNotEmpty) ? _primaryCaregiver.text.trim() : null,
        'separatedMoreThan2WeeksPast6Months': _separated2Weeks,
        'abuseAware': _abuseAware,
        'enrolledInDaycare': _enrolledDaycare,
      },
      'illness': {
        'sickPast2Weeks': _sickPast2Weeks,
        'illnesses': _sickPast2Weeks ? _illnesses.toList() : <String>[],
        'soughtCare': _sickPast2Weeks ? _soughtCare : false,
        'careSources': (_sickPast2Weeks && _soughtCare) ? _careSources.toList() : <String>[],
      },
      'disability': {
        'diagnosedDisability': _diagnosedDisability,
        'hasSupport': _diagnosedDisability ? _hasDisabilitySupport : null,
        'supportProviderFacility': (_diagnosedDisability && _hasDisabilitySupport && _disabilityServiceProvider.text.trim().isNotEmpty)
            ? _disabilityServiceProvider.text.trim()
            : null,
        'conditions': _diagnosedDisability ? _disabilityConditions.toList() : <String>[],
        'otherSpecify': (_diagnosedDisability && _disabilityConditions.contains('Other (specify)') && _disabilityOther.text.trim().isNotEmpty)
            ? _disabilityOther.text.trim()
            : null,
      },
      'iycf': {
        'breastfeeding': _breastfeeding,
        'breastfeedingStoppedAtMonths': _breastfeeding ? null : int.tryParse(_breastfeedingStoppedAtMonths.text.trim()),
        'complementaryFeeding': _complementaryFeeding,
        'feedingTimesYesterday': feedingTimes,
        'minFeedsRecommended': minFeeds,
        'feedingFrequencyOk': feedingFrequencyOk,
        'foodGroups': _foodGroups.toList(),
        'foodGroupsCount': _foodGroups.length,
        'feedingChangedDuringIllness': _sickPast2Weeks ? _feedingChanged : false,
        'feedingChangePatterns': (_sickPast2Weeks && _feedingChanged) ? _feedingChangePatterns.toList() : <String>[],
      },
      'pss': {
        'responses': List<int>.from(_pss),
        'score': pssScore,
        'category': pssCategory,
      },
      'wash': {
        'waterSource': _waterSource,
        'waterCollectionTime': _waterCollectionTime,
        'waterTreatment': _waterTreatment,
        'waterTreatmentMethods': ((_waterTreatment ?? '').startsWith('Yes')) ? _waterTreatmentMethods.toList() : <String>[],
        'handwashingInstances': _handwashInstances.toList(),
        'toiletType': _toiletType,
      },
      'hhs': {
        'q1_noFood': _hhsQ1,
        'q1_freq': _hhsF1,
        'q2_sleepHungry': _hhsQ2,
        'q2_freq': _hhsF2,
        'q3_wholeDayNight': _hhsQ3,
        'q3_freq': _hhsF3,
        'score': hhsScore,
        'category': hhsCategory,
      },
      'analysis': {
        'notes': notes,
        'contributingFactors': factorsToSave,
        'dominantFactor': dominantToSave,
        'otherFactor': _analysisOther.text.trim().isEmpty ? null : _analysisOther.text.trim(),
        'actionPlan': actionPlanToSave,
      },
      'freeNotes': _freeNotes.text.trim().isEmpty ? null : _freeNotes.text.trim(),
      'derived': {
        'whzScore': whzScore,
        'whzRefType': whzRes.refType?.name,
        'pssScore': pssScore,
        'pssCategory': pssCategory,
        'hhsScore': hhsScore,
        'hhsCategory': hhsCategory,
      }
    };

    // Mode-specific extras + validation
    if (widget.mode == InDepthAssessmentMode.enrollment) {
      final sachets = int.tryParse(_sachetsDispensed.text.trim());
      if (sachets == null || sachets <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter sachets dispensed')));
        return;
      }
      if (_nextAppointmentDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select next appointment date')));
        return;
      }
      final visitDay = DateTime(assessmentDate.year, assessmentDate.month, assessmentDate.day);
      final nextDay = DateTime(_nextAppointmentDate!.year, _nextAppointmentDate!.month, _nextAppointmentDate!.day);
      if (nextDay.isBefore(visitDay)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Next appointment date cannot be before the visit date')));
        return;
      }
      data['visit'] = {
        'sachetsDispensed': sachets,
        'nextAppointmentDate': _fmtDate(_nextAppointmentDate!),
        'notes': _visitNotes.text.trim().isEmpty ? null : _visitNotes.text.trim(),
      };
    } else {
      if (_exitDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select exit date')));
        return;
      }
      if ((_exitOutcome ?? '').trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select exit outcome')));
        return;
      }
      data['exit'] = {
        'exitDate': _fmtDate(_exitDate!),
        'durationMonths': _monthsBetween(child.enrollmentDate, _exitDate!),
        'outcome': _exitOutcome,
      };
    }

    final localAssessmentId = _editing?.localAssessmentId ?? _uuid.v4();

    setState(() => _saving = true);
    try {
      // Save assessment locally (insert or update)
      final a = _editing ?? ClinicalAssessment();
      a
        ..localAssessmentId = localAssessmentId
        ..localChildId = child.localChildId
        ..assessmentDate = assessmentDate
        ..dataJson = jsonEncode(data)
        ..muacMm = muacMm
        ..weightKg = weightKg
        ..heightCm = heightCm
        ..householdHungerScore = hhsScore
        ..householdHungerCategory = hhsCategory
        ..pssScore = pssScore
        ..pssCategory = pssCategory
        ..status = 'QUEUED'
        ..createdAt = (_editing == null) ? DateTime.now() : a.createdAt
        ..updatedAt = DateTime.now();

      await _assessRepo.upsert(a);

      if (widget.mode == InDepthAssessmentMode.enrollment) {
        // Compose final enrollment payload: base + inDepthAssessment + visit.
        Map<String, dynamic> base;
        SyncQueueItem? queueItem;

        if (_editing != null) {
          // Editing an already saved enrollment: update the already queued enrollment payload.
          queueItem = _enrollQueueItem;
          if (queueItem == null) {
            // Try a last-mile lookup (in case the screen was opened without prefetch).
            queueItem = await _queueRepo.findLatestForEntity('clinical_enroll', child.localChildId);
          }
          if (queueItem == null || (queueItem.payloadJson ?? '').trim().isEmpty) {
            throw Exception('Cannot edit: enrollment is already synced or the queued payload is missing.');
          }
          base = (jsonDecode(queueItem.payloadJson!) as Map).cast<String, dynamic>();
        } else {
          final baseJson = widget.draftEnrollmentJson;
          if (baseJson != null && baseJson.trim().isNotEmpty) {
            base = (jsonDecode(baseJson) as Map).cast<String, dynamic>();
          } else {
            // If the user registered the child then exited the app before assessment,
            // rebuild the base enrollment payload from the saved local child record.
            base = _buildEnrollPayloadFromChild(child);
          }
        }

        base['inDepthAssessment'] = {
          'assessmentDate': _fmtDate(assessmentDate),
          'data': data,
        };

        base['visit'] = data['visit'];

        // Queue enrollment for sync (new) OR update the existing queued item (edit).
        if (queueItem != null) {
          queueItem.payloadJson = jsonEncode(base);
          queueItem.status = SyncStatus.pending;
          await _queueRepo.enqueueOrReplace(queueItem);
          widget.onFinalizeQueued?.call();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated locally. Please sync to send changes.')));
          Navigator.pop(context);
        } else {
          final queueId = _uuid.v4();
          final item = SyncQueueItem()
            ..queueId = queueId
            ..entityType = 'clinical_enroll'
            ..localEntityId = child.localChildId
            ..operation = SyncOperation.create
            ..method = 'POST'
            ..endpoint = '/api/clinical/enroll'
            ..payloadJson = jsonEncode(base)
            ..idempotencyKey = queueId
            ..status = SyncStatus.pending
            ..attempts = 0
            ..createdAt = DateTime.now();

          await _queueRepo.enqueue(item);
          widget.onFinalizeQueued?.call();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved locally and queued for sync')));
          Navigator.popUntil(context, (r) => r.isFirst);
        }
      } else {
        // Queue discharge assessment for sync.
        final payload = <String, dynamic>{
          'localChildId': child.localChildId,
          'assessmentDate': _fmtDate(assessmentDate),
          'assessmentType': 'DISCHARGE',
          'data': data,
        };

        final q = SyncQueueItem.build(
          queueId: localAssessmentId,
          entityType: 'clinical_discharge',
          localEntityId: localAssessmentId,
          dependsOnLocalEntityId: child.localChildId,
          method: 'POST',
          endpoint: '/api/clinical/children/{childId}/assessment?type=DISCHARGE',
          operation: SyncOperation.create,
          payloadJson: jsonEncode(payload),
          idempotencyKey: localAssessmentId,
        );
        await _queueRepo.enqueueOrReplace(q);

        final result = await _syncService.syncNow();

        if (!mounted) return;
        final msg = result.online
            ? 'Discharge saved. Sync: sent ${result.sent}, failed ${result.failed}.'
            : 'Discharge saved offline (queued for sync)';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }



  Map<String, dynamic> _buildEnrollPayloadFromChild(ClinicalChild c) {
    String fmt(DateTime d) {
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    }

    return {
      'caregiverName': c.caregiverName,
      'caregiverContacts': c.caregiverContacts,
      'village': c.village,
      'childFirstName': c.firstName,
      'childLastName': c.lastName,
      'sex': c.sex,
      'dateOfBirth': c.dateOfBirth != null ? fmt(c.dateOfBirth!) : null,
      'cwcNumber': c.cwcNumber,
      'enrollmentDate': fmt(c.enrollmentDate),
      'program': 'SQLNS',
      if ((c.chpName ?? '').isNotEmpty) 'chpName': c.chpName,
      if ((c.chpContacts ?? '').isNotEmpty) 'chpContacts': c.chpContacts,
      if ((c.facilityCode ?? '').isNotEmpty) 'facilityCode': c.facilityCode,
    };
  }
  int _computeHhsScore() {
    int code(bool yes, String? freq) {
      if (!yes) return 0;
      if (freq == 'Often') return 2;
      if (freq == 'Rarely') return 1;
      if (freq == 'Sometimes') return 1;
      return 1;
    }

    return code(_hhsQ1, _hhsF1) + code(_hhsQ2, _hhsF2) + code(_hhsQ3, _hhsF3);
  }

  static String _hhsCategory(int score) {
    if (score <= 1) return 'Little to no hunger in the household (0–1)';
    if (score <= 3) return 'Moderate household hunger (2–3)';
    return 'Severe household hunger (4–6)';
  }

  static String _pssCategory(int score) {
    if (score <= 2) return 'Normal (0–2)';
    if (score <= 5) return 'Moderate psychological distress (3–5)';
    return 'Severe psychological distress (6–10)';
  }

  /// Meal frequency minimums from the Word form:
  /// - 6 months => 2
  /// - 7–8 months => 3
  /// - 9–11 months => 4
  /// - 12–23 months => 5
  static int? _minFeeds(int ageMonths) {
    if (ageMonths < 6 || ageMonths > 23) return null;
    if (ageMonths == 6) return 2;
    if (ageMonths <= 8) return 3;
    if (ageMonths <= 11) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final child = _child;
    if (child == null) {
      return const Scaffold(body: Center(child: Text('Child not found')));
    }

    // For analysis preview chips and helpful UI hints
    int? parseI(TextEditingController c) => int.tryParse(c.text.trim());
    final feedingTimes = parseI(_feedingTimesYesterday);
    final minFeeds = (_ageMonths != null) ? _minFeeds(_ageMonths!) : null;
    final feedingFrequencyOk = (minFeeds != null && feedingTimes != null) ? feedingTimes >= minFeeds : null;

    final pssScore = _pss.fold<int>(0, (a, b) => a + b);
    final pssCategory = _pssCategory(pssScore);
    final hhsScore = _computeHhsScore();
    final hhsCategory = _hhsCategory(hhsScore);

    final preview = _computeAnalysisPreview(
      feedingTimes: feedingTimes,
      minFeeds: minFeeds,
      feedingFrequencyOk: feedingFrequencyOk,
      pssScore: pssScore,
      pssCategory: pssCategory,
      hhsScore: hhsScore,
      hhsCategory: hhsCategory,
    );
    final notesPreview = (preview['notes'] as List).cast<String>();
    final suggestedPreview = (preview['suggestedFactors'] as List).cast<String>();

    final inIYCFRange = _ageMonths != null && _ageMonths! >= 6 && _ageMonths! <= 23;

    return Scaffold(
      appBar: AcfAppBar(
        title: widget.mode == InDepthAssessmentMode.enrollment
            ? 'In-depth assessment (Enrollment)'
            : 'In-depth assessment (Discharge)',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(child: child, ageMonths: _ageMonths),
          const SizedBox(height: 12),

                    _SectionTile(
            title: 'Anthropometric Measures',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoCols = constraints.maxWidth >= 520;

                    final weight = _Question(
                      text: 'Weight (kg)',
                      child: TextField(
                        controller: _weightKg,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Enter weight'),
                        onChanged: (_) => setState(() {}),
                      ),
                    );
                    final height = _Question(
                      text: 'Length/Height (cm)',
                      child: TextField(
                        controller: _heightCm,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Enter length/height'),
                        onChanged: (_) => setState(() {}),
                      ),
                    );

                    if (twoCols) {
                      return Row(
                        children: [
                          Expanded(child: weight),
                          const SizedBox(width: 12),
                          Expanded(child: height),
                        ],
                      );
                    }
                    return Column(children: [weight, height]);
                  },
                ),
                _Question(
                  text: 'MUAC (mm)',
                  child: TextField(
                    controller: _muacMm,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      hintText: 'Enter MUAC in millimeters (e.g., 125)',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                FutureBuilder<WhzResult>(
                  future: const WhzCalculator().compute(
                    sex: _parseSex(child.sex),
                    heightCm: double.tryParse(_heightCm.text.trim().replaceAll(',', '.')),
                    weightKg: double.tryParse(_weightKg.text.trim().replaceAll(',', '.')),
                    ageMonths: _ageMonths,
                  ),
                  builder: (context, snap) {
                    final z = snap.data?.z;
                    final ref = snap.data?.refType;
                    final outOfRange = snap.data?.outOfRange ?? false;
                    final note = snap.data?.note;
                    String refLabel;
                    if (ref == GrowthRefType.wfl) {
                      refLabel = 'WFL (0–23 months)';
                    } else if (ref == GrowthRefType.wfh) {
                      refLabel = 'WFH (24–59 months)';
                    } else {
                      refLabel = '—';
                    }

                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('WHZ Score (auto-calculated)', style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Text(
                              z == null ? 'Not available (enter weight + length/height)' : '${z.toStringAsFixed(2)} SD • $refLabel',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (outOfRange) ...[
                              const SizedBox(height: 6),
                              const Text('Note: length/height is outside WHO reference range.', style: TextStyle(color: Colors.black54)),
                            ],
                            if ((note ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(note!, style: const TextStyle(color: Colors.black54)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          
          _SectionTile(
            title: 'Socio-economic',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoCols = constraints.maxWidth >= 520;
                    final hh = _Question(
                      text: 'Household size (number of people)',
                      child: TextField(
                        controller: _hhSize,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Enter number'),
                      ),
                    );
                    final u5 = _Question(
                      text: 'Children under 5 (number)',
                      child: TextField(
                        controller: _u5Count,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Enter number'),
                      ),
                    );

                    if (twoCols) {
                      return Row(
                        children: [
                          Expanded(child: hh),
                          const SizedBox(width: 12),
                          Expanded(child: u5),
                        ],
                      );
                    }
                    return Column(children: [hh, u5]);
                  },
                ),
                _Question(
                  text: 'Main source of household income',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _incomeSource,
                    items: _incomeSourceOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _incomeSource = v),
                    decoration: const InputDecoration(hintText: 'Select one'),
                  ),
                ),
                _Question(
                  text: 'Enrolled in any cash transfer/food assistance programme?',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _enrolledAssistance == null ? null : (_enrolledAssistance! ? 'Yes' : 'No'),
                    items: const [
                      DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                      DropdownMenuItem(value: 'No', child: Text('No')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _enrolledAssistance = (v == 'Yes');
                        if (_enrolledAssistance != true) {
                          _assistanceProgramName.clear();
                        }
                      });
                    },
                    decoration: const InputDecoration(hintText: 'Select'),
                  ),
                ),
                if (_enrolledAssistance == true)
                  _Question(
                    text: 'Programme name (specify)',
                    child: TextField(
                      controller: _assistanceProgramName,
                      decoration: const InputDecoration(hintText: 'Type programme name'),
                    ),
                  ),
              ],
            ),
          ),

          
          _SectionTile(
            title: 'Child Care and Protection',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Question(
                  text: 'Who provides daily care to the child?',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _dailyCareProvider,
                    items: _dailyCareProviderOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _dailyCareProvider = v),
                    decoration: const InputDecoration(hintText: 'Select one'),
                  ),
                ),
                _Question(
                  text: 'Under care of both biological parents?',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _underBothParents == null ? null : (_underBothParents! ? 'Yes' : 'No'),
                    items: const [
                      DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                      DropdownMenuItem(value: 'No', child: Text('No')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _underBothParents = (v == 'Yes');
                        if (_underBothParents != false) {
                          _primaryCaregiver.clear();
                        }
                      });
                    },
                    decoration: const InputDecoration(hintText: 'Select'),
                  ),
                ),
                if (_underBothParents == false)
                  _Question(
                    text: 'Primary caregiver (if not both parents)',
                    child: TextField(
                      controller: _primaryCaregiver,
                      decoration: const InputDecoration(hintText: 'Type name/relationship'),
                    ),
                  ),
                _Question(
                  text: 'Separated from caregiver > 2 weeks in past 6 months?',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _separated2Weeks == null ? null : (_separated2Weeks! ? 'Yes' : 'No'),
                    items: const [
                      DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                      DropdownMenuItem(value: 'No', child: Text('No')),
                    ],
                    onChanged: (v) => setState(() => _separated2Weeks = (v == 'Yes')),
                    decoration: const InputDecoration(hintText: 'Select'),
                  ),
                ),
                _Question(
                  text: 'Any physical or emotional abuse you are aware of?',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _abuseAware,
                    items: _abuseOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _abuseAware = v),
                    decoration: const InputDecoration(hintText: 'Select one'),
                  ),
                ),
                _Question(
                  text: 'Enrolled in any daycare service?',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _enrolledDaycare == null ? null : (_enrolledDaycare! ? 'Yes' : 'No'),
                    items: const [
                      DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                      DropdownMenuItem(value: 'No', child: Text('No')),
                    ],
                    onChanged: (v) => setState(() => _enrolledDaycare = (v == 'Yes')),
                    decoration: const InputDecoration(hintText: 'Select'),
                  ),
                ),
              ],
            ),
          ),

          _SectionTile(
            title: 'Illness and care seeking (past 1–2 weeks)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Question(
                  text: 'Has the child been sick in the past 1–2 weeks?',
                  child: _ToggleSwitch(
                    value: _sickPast2Weeks,
                    onChanged: (v) {
                      setState(() {
                        _sickPast2Weeks = v;
                        if (!v) {
                          _illnesses.clear();
                          _soughtCare = false;
                          _careSources.clear();
                          _feedingChanged = false;
                          _feedingChangePatterns.clear();
                        }
                      });
                    },
                  ),
                ),
                if (_sickPast2Weeks) ...[
                  const SizedBox(height: 6),
                  _Question(
                    text: 'Select illness(es) (select all that apply)',
                    child: _MultiSelect(
                      options: _illnessOptions,
                      selected: _illnesses,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  _Question(
                    text: 'Did the caregiver seek medical assistance?',
                    child: _ToggleSwitch(
                      value: _soughtCare,
                      onChanged: (v) {
                        setState(() {
                          _soughtCare = v;
                          if (!v) _careSources.clear();
                        });
                      },
                    ),
                  ),
                  if (_soughtCare) ...[
                    const SizedBox(height: 6),
                    _Question(
                      text: 'Where did they seek assistance? (select all that apply)',
                      child: _MultiSelect(
                        options: _careSourceOptions,
                        selected: _careSources,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          _SectionTile(
            title: 'Disability',
            child: Column(
              children: [
                _Question(
                  text: 'Does the child have a diagnosed disability?',
                  child: _ToggleSwitch(
                    value: _diagnosedDisability,
                    onChanged: (v) {
                      setState(() {
                        _diagnosedDisability = v;
                        if (!v) {
                          _hasDisabilitySupport = false;
                          _disabilityConditions.clear();
                          _disabilityOther.clear();
                          _disabilityServiceProvider.clear();
                        }
                      });
                    },
                  ),
                ),
                if (_diagnosedDisability) ...[
                  _Question(
                    text: 'If yes, which condition(s) apply? (Tick all that apply)',
                    child: _MultiSelect(
                      options: _disabilityConditionOptions,
                      selected: _disabilityConditions,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  if (_disabilityConditions.contains('Other (specify)'))
                    _Question(
                      text: 'Other (specify)',
                      child: TextField(
                        controller: _disabilityOther,
                        decoration: const InputDecoration(hintText: 'Type here'),
                      ),
                    ),
                  _Question(
                    text: 'Does the caregiver have access to disability services/support?',
                    child: _ToggleSwitch(
                      value: _hasDisabilitySupport,
                      onChanged: (v) {
                        setState(() {
                          _hasDisabilitySupport = v;
                          if (!v) _disabilityServiceProvider.clear();
                        });
                      },
                    ),
                  ),
                  if (_hasDisabilitySupport)
                    _Question(
                      text: 'If Yes, specify service provider/facility:',
                      child: TextField(
                        controller: _disabilityServiceProvider,
                        decoration: const InputDecoration(hintText: 'Type here'),
                      ),
                    ),
                ],
              ],
            ),
          ),

          _SectionTile(
            title: 'IYCF (feeding)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Question(
                  text: 'Is the child currently breastfeeding?',
                  child: _ToggleSwitch(
                    value: _breastfeeding,
                    onChanged: (v) => setState(() => _breastfeeding = v),
                  ),
                ),
                if (!_breastfeeding)
                  _Question(
                    text: 'If stopped breastfeeding, at what age (months)?',
                    child: TextField(
                      controller: _breastfeedingStoppedAtMonths,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Enter months'),
                    ),
                  ),
                const SizedBox(height: 8),
                _Question(
                  text: 'Is the child receiving complementary foods?',
                  child: _ToggleSwitch(
                    value: _complementaryFeeding,
                    onChanged: (v) => setState(() => _complementaryFeeding = v),
                  ),
                ),
                const SizedBox(height: 8),
                if (inIYCFRange) ...[
                  _Question(
                    text: 'How many times did the child eat yesterday? (meals/snacks)',
                    child: TextField(
                      controller: _feedingTimesYesterday,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Enter number'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (minFeeds != null)
                    _ScoreChip(
                      label: 'Recommended minimum feeds',
                      value: '$minFeeds / day',
                    ),
                  const SizedBox(height: 10),
                  _Question(
                    text: 'Food groups consumed yesterday (select all)',
                    child: _MultiSelect(
                      options: _foodGroupOptions,
                      selected: _foodGroups,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ScoreChip(
                    label: 'Food groups selected',
                    value: '${_foodGroups.length}',
                  ),
                  const SizedBox(height: 10),
                  if (feedingFrequencyOk != null)
                    _ScoreChip(
                      label: 'Feeding frequency',
                      value: feedingFrequencyOk ? 'OK' : 'Below recommended',
                    ),
                ] else ...[
                  Text(
                    'Feeding frequency and dietary diversity checks apply to children aged 6–23 months. (Current age: ${_ageMonths ?? '-'} months)',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],

                const SizedBox(height: 10),
                if (_sickPast2Weeks) ...[
                  _Question(
                    text: 'In the past 1–2 weeks, has the child’s feeding changed due to illness?',
                    child: _ToggleSwitch(
                      value: _feedingChanged,
                      onChanged: (v) {
                        setState(() {
                          _feedingChanged = v;
                          if (!v) _feedingChangePatterns.clear();
                        });
                      },
                    ),
                  ),
                  if (_feedingChanged) ...[
                    _Question(
                      text: 'Feeding pattern changes (select all that apply)',
                      child: _MultiSelect(
                        options: _feedingChangeOptions,
                        selected: _feedingChangePatterns,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          _SectionTile(
            title: 'PSS (psychosocial)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Score each item: 0 (Never/Rarely), 1 (Sometimes), 2 (Often/Always)', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 10),
                for (int i = 0; i < _pssQuestions.length; i++)
                  _PssRow(
                    index: i,
                    question: _pssQuestions[i],
                    value: _pss[i],
                    onChanged: (v) => setState(() => _pss[i] = v),
                  ),
                _ScoreChip(label: 'PSS score', value: '$pssScore/10 • $pssCategory'),
              ],
            ),
          ),

          _SectionTile(
            title: 'WASH',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Question(
                  text: 'Main source of drinking water',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _waterSource,
                    items: _waterSourceOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _waterSource = v),
                    decoration: const InputDecoration(hintText: 'Select one'),
                  ),
                ),
                _Question(
                  text: 'How long does it usually take you or your household to make a round trip to collect water, including waiting time?',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _waterCollectionTime,
                    items: _waterCollectionTimeOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _waterCollectionTime = v),
                    decoration: const InputDecoration(hintText: 'Select one'),
                  ),
                ),
                _Question(
                  text: 'Does your household treat water before drinking?',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _waterTreatment,
                    items: _waterTreatmentOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _waterTreatment = v;
                        if (!(v ?? '').startsWith('Yes')) _waterTreatmentMethods.clear();
                      });
                    },
                    decoration: const InputDecoration(hintText: 'Select one'),
                  ),
                ),
                if ((_waterTreatment ?? '').startsWith('Yes')) ...[
                  _Question(
                    text: 'If yes, what does your household usually do? (select all)',
                    child: _MultiSelect(
                      options: _waterTreatmentMethodOptions,
                      selected: _waterTreatmentMethods,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ],
                _Question(
                  text: 'Yesterday (within last 24 hours), at what instances did you wash your hands? (select all)',
                  child: _MultiSelect(
                    options: _handwashInstanceOptions,
                    selected: _handwashInstances,
                    onChanged: () => setState(() {}),
                  ),
                ),
                _Question(
                  text: 'Type of toilet facility used by household',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _toiletType,
                    items: _toiletTypeOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _toiletType = v),
                    decoration: const InputDecoration(hintText: 'Select one'),
                  ),
                ),
              ],
            ),
          ),

          _SectionTile(
            title: 'Household Hunger Scale (HHS)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HhsQuestion(
                  label: 'In the past 4 weeks, was there ever no food to eat in your household?',
                  value: _hhsQ1,
                  freqValue: _hhsF1,
                  onValueChanged: (v) => setState(() {
                    _hhsQ1 = v;
                    if (!v) _hhsF1 = null;
                  }),
                  onFreqChanged: (v) => setState(() => _hhsF1 = v),
                ),
                _HhsQuestion(
                  label: 'In the past 4 weeks, did anyone go to sleep hungry because there was not enough food?',
                  value: _hhsQ2,
                  freqValue: _hhsF2,
                  onValueChanged: (v) => setState(() {
                    _hhsQ2 = v;
                    if (!v) _hhsF2 = null;
                  }),
                  onFreqChanged: (v) => setState(() => _hhsF2 = v),
                ),
                _HhsQuestion(
                  label: 'In the past 4 weeks, did anyone go a whole day and night without eating anything because there was not enough food?',
                  value: _hhsQ3,
                  freqValue: _hhsF3,
                  onValueChanged: (v) => setState(() {
                    _hhsQ3 = v;
                    if (!v) _hhsF3 = null;
                  }),
                  onFreqChanged: (v) => setState(() => _hhsF3 = v),
                ),
                const SizedBox(height: 10),
                _ScoreChip(label: 'HHS score', value: '$hhsScore/6 • $hhsCategory'),
              ],
            ),
          ),

          _SectionTile(
            title: 'Analysis (auto + action plan)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notesPreview.isNotEmpty) ...[
                  const Text('Auto-generated notes (based on your answers):', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final n in notesPreview) Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $n'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                const Text('Contributing factors (select all that apply):', style: TextStyle(fontWeight: FontWeight.w800)),
                _MultiSelect(
                  options: _analysisFactorOptions,
                  selected: _analysisFactors,
                  onChanged: () => setState(() {}),
                ),

                if (suggestedPreview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Suggested based on answers: ${suggestedPreview.join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _analysisFactors.addAll(suggestedPreview);
                          _analysisDominant ??= suggestedPreview.isNotEmpty ? suggestedPreview.first : null;
                        });
                      },
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Apply suggestions'),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                _Question(
                  text: 'Most dominant contributing factor',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _analysisDominant,
                    items: (_analysisFactors.isNotEmpty ? _analysisFactors.toList() : _analysisFactorOptions)
                        .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _analysisDominant = v),
                    decoration: const InputDecoration(hintText: 'Select one'),
                  ),
                ),
                _Question(
                  text: 'Other (specify, if needed)',
                  child: TextField(
                    controller: _analysisOther,
                    decoration: const InputDecoration(hintText: 'Type if needed'),
                  ),
                ),

                const SizedBox(height: 16),
                const Text('Action plan', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                for (int i = 0; i < _actionPlan.length; i++)
                  _ActionPlanCard(
                    index: i,
                    row: _actionPlan[i],
                    onRemove: _actionPlan.length <= 1
                        ? null
                        : () => setState(() {
                              _actionPlan[i].dispose();
                              _actionPlan.removeAt(i);
                            }),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _actionPlan.add(_ActionPlanRow())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add action row'),
                  ),
                ),
              ],
            ),
          ),

          if (widget.mode == InDepthAssessmentMode.enrollment)
            _SectionTile(
              title: 'Dispense & next appointment',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _sachetsDispensed,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                    decoration: const InputDecoration(
                      labelText: 'Sachets dispensed (quantity) *',
                      hintText: 'e.g., 28',
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _pickNextAppointmentDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_available, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _nextAppointmentDate == null
                                  ? 'Next appointment date *'
                                  : 'Next appointment: ${_fmtDate(_nextAppointmentDate!)}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _visitNotes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Visit notes (optional)',
                      hintText: 'Any notes about dispensing or appointments…',
                    ),
                  ),
                ],
              ),
            ),

          if (widget.mode == InDepthAssessmentMode.discharge)
            _SectionTile(
              title: 'Exit / discharge',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: _pickExitDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.logout, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _exitDate == null ? 'Exit date *' : 'Exit date: ${_fmtDate(_exitDate!)}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      final c = _child;
                      final end = _exitDate ?? DateTime.now();
                      final months = (c == null) ? null : _monthsBetween(c.enrollmentDate, end);
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Text(
                          months == null
                              ? 'Duration of stay (months): -'
                              : 'Duration of stay (months): $months',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _exitOutcome,
                    items: const [
                      DropdownMenuItem(
                        value: 'Achieved normal anthropometric measurements',
                        child: Text('Achieved normal anthropometric measurements'),
                      ),
                      DropdownMenuItem(
                        value: 'Deteriorated to SAM/MAM',
                        child: Text('Deteriorated to SAM/MAM'),
                      ),
                      DropdownMenuItem(
                        value: 'Lost to follow up',
                        child: Text('Lost to follow up'),
                      ),
                      DropdownMenuItem(
                        value: 'Died',
                        child: Text('Died'),
                      ),
                      DropdownMenuItem(
                        value: 'Transfer to another follow up site',
                        child: Text('Transfer to another follow up site'),
                      ),
                      DropdownMenuItem(
                        value: 'Not achieved normal anthropometric measurements',
                        child: Text('Not achieved normal anthropometric measurements'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _exitOutcome = v),
                    decoration: const InputDecoration(labelText: 'Exit outcome *'),
                  ),
                ],
              ),
            ),

          _SectionTile(
            title: 'Additional notes',
            child: TextField(
              controller: _freeNotes,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Any additional notes…',
              ),
            ),
          ),

          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(
              _saving
                  ? 'Saving…'
                  : (widget.mode == InDepthAssessmentMode.enrollment
                      ? 'Save locally & queue for sync'
                      : 'Save discharge & queue for sync'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final ClinicalChild child;
  final int? ageMonths;

  const _HeaderCard({required this.child, required this.ageMonths});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.assignment, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${child.firstName} ${child.lastName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  [
                    if (child.cwcNumber != null && child.cwcNumber!.isNotEmpty) 'CWC: ${child.cwcNumber}',
                    if (ageMonths != null) 'Age: $ageMonths months',
                    'Sex: ${child.sex}',
                  ].join(' • '),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionTile({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [child],
      ),
    );
  }
}


class _Question extends StatelessWidget {
  final String text;
  final Widget child;

  const _Question({required this.text, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: cs.onSurfaceVariant,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// Simple yes/no control used across the form.
///
/// We render the *question* above the control (via [_Question]) to avoid
/// long text being cramped inside the input field.
class _ToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Switch(value: value, onChanged: onChanged),
        const SizedBox(width: 8),
        Text(
          value ? 'Yes' : 'No',
          style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface),
        ),
      ],
    );
  }
}

class _MultiSelect extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final VoidCallback onChanged;

  const _MultiSelect({required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final o in options)
          CheckboxListTile(
            value: selected.contains(o),
            title: Text(o),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) {
              if (v == true) {
                selected.add(o);
              } else {
                selected.remove(o);
              }
              onChanged();
            },
          )
      ],
    );
  }
}

class _PssRow extends StatelessWidget {
  final int index;
  final String question;
  final int value;
  final ValueChanged<int> onChanged;

  const _PssRow({required this.index, required this.question, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${index + 1}. $question', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('0'),
                  selected: value == 0,
                  onSelected: (_) => onChanged(0),
                ),
                ChoiceChip(
                  label: const Text('1'),
                  selected: value == 1,
                  onSelected: (_) => onChanged(1),
                ),
                ChoiceChip(
                  label: const Text('2'),
                  selected: value == 2,
                  onSelected: (_) => onChanged(2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HhsQuestion extends StatelessWidget {
  final String label;
  final bool value;
  final String? freqValue;
  final ValueChanged<bool> onValueChanged;
  final ValueChanged<String?> onFreqChanged;

  const _HhsQuestion({
    required this.label,
    required this.value,
    required this.freqValue,
    required this.onValueChanged,
    required this.onFreqChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Question(
              text: label,
              child: _ToggleSwitch(
                value: value,
                onChanged: onValueChanged,
              ),
            ),
            if (value)
              _Question(
                text: 'How often in the past 30 days?',
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: freqValue,
                  items: const [
                    DropdownMenuItem(value: 'Rarely', child: Text('Rarely (1–2 times)')),
                    DropdownMenuItem(value: 'Sometimes', child: Text('Sometimes (3–10 times)')),
                    DropdownMenuItem(value: 'Often', child: Text('Often (>10 times)')),
                  ],
                  onChanged: onFreqChanged,
                  decoration: const InputDecoration(hintText: 'Select one'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final String value;

  const _ScoreChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      // Use a single rich text block so long labels/values wrap instead of overflowing.
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w800),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}


class _ActionPlanRow {
  final TextEditingController problem = TextEditingController();
  final TextEditingController intervention = TextEditingController();
  final TextEditingController responsible = TextEditingController();
  final TextEditingController followUpDate = TextEditingController();
  final TextEditingController remarks = TextEditingController();

  Map<String, dynamic> toMap() => {
        'problem': problem.text.trim(),
        'intervention': intervention.text.trim(),
        'responsible': responsible.text.trim(),
        'followUpDate': followUpDate.text.trim(),
        'remarks': remarks.text.trim(),
      };

  void dispose() {
    problem.dispose();
    intervention.dispose();
    responsible.dispose();
    followUpDate.dispose();
    remarks.dispose();
  }
}

class _ActionPlanCard extends StatelessWidget {
  final int index;
  final _ActionPlanRow row;
  final VoidCallback? onRemove;

  const _ActionPlanCard({required this.index, required this.row, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String fmtDate(DateTime d) {
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    }

    Future<void> pickFollowUpDate() async {
      final now = DateTime.now();
      final initial = DateTime.tryParse(row.followUpDate.text.trim()) ?? now;
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(now.year - 1, 1, 1),
        lastDate: DateTime(now.year + 2, 12, 31),
      );
      if (picked == null) return;
      row.followUpDate.text = fmtDate(picked);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Row ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove row',
                    onPressed: onRemove,
                    icon: Icon(Icons.delete_outline, color: cs.error),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _Question(
              text: 'Problem identified',
              child: TextField(
                controller: row.problem,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Describe the problem'),
              ),
            ),
            _Question(
              text: 'Planned intervention',
              child: TextField(
                controller: row.intervention,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'What will be done?'),
              ),
            ),
            _Question(
              text: 'Responsible person',
              child: TextField(
                controller: row.responsible,
                decoration: const InputDecoration(hintText: 'Name / role'),
              ),
            ),
            _Question(
              text: 'Follow-up date',
              child: InkWell(
                onTap: pickFollowUpDate,
                borderRadius: BorderRadius.circular(12),
                child: IgnorePointer(
                  child: TextField(
                    controller: row.followUpDate,
                    readOnly: true,
                    decoration: const InputDecoration(
                      hintText: 'Select date',
                      suffixIcon: Icon(Icons.calendar_month),
                    ),
                  ),
                ),
              ),
            ),
            _Question(
              text: 'Remarks',
              child: TextField(
                controller: row.remarks,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Any remarks'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Static options from your Word form (tables) ---

const List<String> _illnessOptions = [
  'Fever',
  'ARI/Cough',
  'Watery diarrhoea',
  'Bloody diarrhoea',
  'Other (specify in notes)',
];

const List<String> _careSourceOptions = [
  'Relative or friend',
  'Traditional healer',
  'Herbal (self/herbalist)',
  'Shop/Kiosk',
  'Community health Promoter',
  'Chemist',
  'Private clinic',
  'Mobile clinic/outreaches',
  'Public health facility',
  'CBO/FBO health facility',
];

const List<String> _incomeSourceOptions = [
  'Livestock keeping',
  'Crop farming',
  'Casual labour (e.g. daily wage)',
  'Small business/trade',
  'Remittances',
  'Social protection (e.g. Inua Jamii, NICHE, HSNP)',
  'Other (specify in notes)',
];

const List<String> _dailyCareProviderOptions = [
  'Mother',
  'Father',
  'Grandparent',
  'Older sibling',
  'Other relative',
  'House help/domestic worker',
  'Day care center',
  'Neighbor/friend',
  'Other (specify in notes)',
];

const List<String> _abuseOptions = [
  'Yes',
  'No',
  'Prefer not to say',
];

const Set<String> _goodCareSources = {
  'Private clinic',
  'Mobile clinic/outreaches',
  'Public health facility',
  'CBO/FBO health facility',
};

const List<String> _foodGroupOptions = [
  'Breastmilk',
  'Grains, roots, and tubers (e.g., maize, rice, potatoes, sorghum, millet)',
  'Legumes and nuts (e.g., beans, lentils, groundnuts)',
  'Dairy products (e.g., milk, cheese, yogurt)',
  'Flesh foods (e.g., meat, fish, poultry, liver, organ meats)',
  'Eggs',
  'Vitamin A–rich fruits and vegetables (e.g., pumpkin, mangoes, carrots, dark leafy greens)',
  'Other fruits and vegetables (e.g., ripe bananas, tomatoes, onions)',
];

const List<String> _feedingChangeOptions = [
  'Eating fewer meals per day',
  'Eating smaller amounts than usual',
  'Breastfeeding less frequently or has stopped',
  'Reduced appetite or refusal to eat/breastfeed',
  'Taking only fluids (refusing solids)',
];

const List<String> _pssQuestions = [
  'Have you felt overwhelmed or unable to manage your daily responsibilities?',
  'Have you had difficulty sleeping due to worry, stress or sadness?',
  'Have you felt alone or unsupported in caring for your child?',
  'Have you experienced trauma, abuse or violence recently?',
  'Have you had thoughts of harming yourself or others?',
];

const List<String> _waterSourceOptions = [
  'Public tap/standpipe',
  'Handpumps/boreholes',
  'Protected well',
  'Water seller/kiosks',
  'Piped connection to house (or neighbor’s house)',
  'Protected spring',
  'Bottled water',
  'Water sachets',
  'Tanker trucks',
  'Unprotected hand-dug well',
  'Surface water (lake, pond, dam, river)',
  'Unprotected spring',
  'Rain water collection',
  'Other (specify in notes)',
];

const List<String> _waterCollectionTimeOptions = [
  'Less than 30 minutes',
  '30 minutes to less than 1 hour',
  '1 hour to less than 2 hours',
  '2 hours or more',
  'Water is available on premises',
];

const List<String> _waterTreatmentOptions = [
  'Yes, always treat it before drinking',
  'Yes, sometimes treat it before drinking',
  'No, never treat it before drinking',
];

const List<String> _waterTreatmentMethodOptions = [
  'Let it stand and settle',
  'Boil it',
  'Expose it to sunlight',
  'Use disinfection products (e.g. water guard)',
  'Filter it- BSF, Chujio',
  'Other (specify in notes)',
];

const List<String> _handwashInstanceOptions = [
  'After toilet',
  'Before cooking',
  'Before eating/serving food',
  'After taking children to the toilet',
  'Other (Specify)',
];

const List<String> _disabilityConditionOptions = [
  'Physical disability (e.g., limb deformity, muscle weakness)',
  'Hearing impairment (partial or full loss)',
  'Visual impairment (not correctable with glasses)',
  'Developmental delay (e.g., motor, speech, cognitive)',
  'Intellectual disability',
  'Cerebral palsy',
  'Autism spectrum disorder',
  'Other (specify)',
];

const List<String> _toiletTypeOptions = [
  'Flush or pour/flush toilet',
  'Pit latrine with slab/platform',
  'Pit VIP latrine',
  'Hanging toilet/latrine',
  'Pit latrine without slab/platform',
  'Open hole',
  'Bucket toilet',
  'No facility, field, bush, plastic bag',
];

const List<String> _analysisFactorOptions = [
  'Inadequate breastfeeding or complementary feeding',
  'Recent illness (e.g., diarrhea, ARI, fever)',
  'Household food insecurity',
  'Caregiver lacks nutrition knowledge or skills',
  'Maternal or caregiver illness or absence',
  'Poor WASH conditions (unsafe water, lack of sanitation)',
  'Child neglect or child protection concerns',
  'Disability or developmental delay affecting feeding or care',
  'Lack of access to health services',
  'Social vulnerability (e.g., orphaned child, single-parent household)',
  'Other',
];
