enum PetAdmissionStatus { unknown, allowed, conditional, notAllowed }

/// Published admission evidence, separate from the owner's private notes.
/// Text rules retain alternatives and exceptions exactly as supplied.
class PetAdmission {
  final PetAdmissionStatus status;
  final String conditions, transportRule, areaRule, sizeRule, rentalRule, fees;
  final String openingHours,
      sourceName,
      sourceUrl,
      indoorFacility,
      outdoorFacility;
  final DateTime? referenceDate, checkedAt;
  const PetAdmission({
    this.status = PetAdmissionStatus.unknown,
    this.conditions = '',
    this.transportRule = '',
    this.areaRule = '',
    this.sizeRule = '',
    this.rentalRule = '',
    this.fees = '',
    this.openingHours = '',
    this.sourceName = '',
    this.sourceUrl = '',
    this.indoorFacility = '',
    this.outdoorFacility = '',
    this.referenceDate,
    this.checkedAt,
  });
  bool get hasEvidence {
    final uri = Uri.tryParse(sourceUrl);
    return sourceName.trim().isNotEmpty &&
        uri?.scheme == 'https' &&
        uri!.host.isNotEmpty;
  }

  bool get isAllowed =>
      hasEvidence &&
      (status == PetAdmissionStatus.allowed ||
          status == PetAdmissionStatus.conditional);
  String get label => !hasEvidence
      ? '동반 여부 미확인'
      : switch (status) {
          PetAdmissionStatus.allowed => '자료상 동반 가능',
          PetAdmissionStatus.conditional => '조건부 동반 · 규정 확인',
          PetAdmissionStatus.notAllowed => '자료상 동반 불가',
          PetAdmissionStatus.unknown => '동반 여부 미확인',
        };
  bool get hasTransportInfo => transportRule.isNotEmpty;
  String get mapLabel => !hasEvidence
      ? '동반 미확인'
      : switch (status) {
          PetAdmissionStatus.allowed => '동반 가능(자료)',
          PetAdmissionStatus.conditional => '조건부 동반',
          PetAdmissionStatus.notAllowed => '동반 불가(자료)',
          PetAdmissionStatus.unknown => '동반 미확인',
        };

  factory PetAdmission.fromJson(Map<String, dynamic> value) {
    final raw = value['status'] as String? ?? 'unknown';
    final status = PetAdmissionStatus.values
        .where((v) => v.name == raw)
        .firstOrNull;
    if (status == null) throw const FormatException('잘못된 동반 상태');
    String text(String key) => (value[key] as String? ?? '').trim();
    return PetAdmission(
      status: status,
      conditions: text('conditions'),
      transportRule: text('transportRule'),
      areaRule: text('areaRule'),
      sizeRule: text('sizeRule'),
      rentalRule: text('rentalRule'),
      fees: text('fees'),
      openingHours: text('openingHours'),
      sourceName: text('sourceName'),
      sourceUrl: text('sourceUrl'),
      indoorFacility: text('indoorFacility'),
      outdoorFacility: text('outdoorFacility'),
      referenceDate: value['referenceDate'] == null
          ? null
          : DateTime.parse(value['referenceDate'] as String),
      checkedAt: value['checkedAt'] == null
          ? null
          : DateTime.parse(value['checkedAt'] as String),
    );
  }
  Map<String, dynamic> toJson() => {
    'status': status.name,
    'conditions': conditions,
    'transportRule': transportRule,
    'areaRule': areaRule,
    'sizeRule': sizeRule,
    'rentalRule': rentalRule,
    'fees': fees,
    'openingHours': openingHours,
    'sourceName': sourceName,
    'sourceUrl': sourceUrl,
    'indoorFacility': indoorFacility,
    'outdoorFacility': outdoorFacility,
    if (referenceDate != null)
      'referenceDate': referenceDate!.toIso8601String(),
    if (checkedAt != null) 'checkedAt': checkedAt!.toIso8601String(),
  };
}
