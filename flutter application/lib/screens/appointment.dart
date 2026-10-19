const serviceLabels = {
  'general_checkup': 'General Checkup',
  'vaccination': 'Vaccination',
  'surgery': 'Surgery',
  'dental': 'Dental',
  'other': 'Other',
};

const statusLabels = {
  'pending': 'Pending',
  'confirmed': 'Confirmed',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
  'rescheduled': 'Rescheduled',
  'no_show': 'Missed',
};

const urgencyLabels = {
  'routine': 'Routine',
  'soon': 'Soon',
  'urgent': 'Urgent',
};

class Appointment {
  const Appointment({
    required this.id,
    required this.startsAt,
    required this.status,
    required this.service,
    required this.urgency,
    required this.reason,
    required this.petName,
    required this.petSpecies,
    this.petAge,
    this.vetId,
    this.vetName,
  });

  final String id;
  final DateTime startsAt;
  final String status;
  final String service;
  final String urgency;
  final String reason;
  final String petName;
  final String petSpecies;
  final int? petAge;
  final String? vetId;
  final String? vetName;

  String get serviceLabel => serviceLabels[service] ?? service;
  String get statusLabel => statusLabels[status] ?? status;
  String get urgencyLabel => urgencyLabels[urgency] ?? urgency;

  String get petSummary {
    final species = petSpecies.isEmpty
        ? ''
        : petSpecies[0].toUpperCase() + petSpecies.substring(1);
    final age = petAge == null
        ? ''
        : (petAge! < 1
            ? 'Under 1 year'
            : '$petAge year${petAge == 1 ? '' : 's'}');
    return [species, age].where((s) => s.isNotEmpty).join(' · ');
  }

  bool get isCancelled => status == 'cancelled';

  bool get isUpcoming =>
      (status == 'pending' ||
          status == 'confirmed' ||
          status == 'rescheduled') &&
      startsAt.isAfter(DateTime.now());

  factory Appointment.fromMap(Map<String, dynamic> map) {
    final pet = (map['pets'] as Map<String, dynamic>?) ?? const {};
    final date = map['appointment_date'] as String;
    final time = (map['appointment_time'] as String?) ?? '00:00:00';
    return Appointment(
      id: map['appointment_id'] as String,
      startsAt: DateTime.parse('${date}T$time'),
      status: ((map['status'] as String?) ?? 'pending').toLowerCase(),
      service: (map['service'] as String?) ?? 'general_checkup',
      urgency: ((map['urgency'] as String?) ?? 'routine').toLowerCase(),
      reason: (map['reason'] as String?) ?? '',
      petName: (pet['patient_name'] as String?) ?? 'Pet',
      petSpecies: ((pet['species'] as String?) ?? '').toLowerCase(),
      petAge: (pet['age'] as num?)?.toInt(),
      vetId: map['vet_id'] as String?,
    );
  }

  Appointment copyWith({String? vetName}) => Appointment(
        id: id,
        startsAt: startsAt,
        status: status,
        service: service,
        urgency: urgency,
        reason: reason,
        petName: petName,
        petSpecies: petSpecies,
        petAge: petAge,
        vetId: vetId,
        vetName: vetName ?? this.vetName,
      );
}
