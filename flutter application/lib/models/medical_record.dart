class MedicalRecord {
  const MedicalRecord({
    required this.visitDate,
    this.diagnosis,
    this.treatment,
    this.medications,
    this.notes,
  });

  final DateTime visitDate;
  final String? diagnosis;
  final String? treatment;
  final String? medications;
  final String? notes;

  factory MedicalRecord.fromMap(Map<String, dynamic> map) => MedicalRecord(
        visitDate: DateTime.parse(map['visit_date'] as String),
        diagnosis: map['diagnosis'] as String?,
        treatment: map['treatment'] as String?,
        medications: map['medications'] as String?,
        notes: map['notes'] as String?,
      );
}
