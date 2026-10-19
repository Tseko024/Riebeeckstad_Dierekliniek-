import '../config/supabase_config.dart';
import '../models/appointment.dart';
import '../utils/formatters.dart';

class TimeSlot {
  const TimeSlot(
      {required this.dbTime,
      required this.clinicTime,
      required this.available});

  final String dbTime;
  final DateTime clinicTime;
  final bool available;
}

class AppointmentsRepo {
  AppointmentsRepo._();

  static const _columns =
      'appointment_id, appointment_date, appointment_time, status, service, urgency, reason, vet_id, '
      'pets(patient_name, species, age)';

  static Future<Appointment?> nextUpcoming() async {
    final uid = supabase.auth.currentUser!.id;

    final row = await supabase
        .from('appointments')
        .select(_columns)
        .eq('owner_id', uid)
        .inFilter('status', ['Pending', 'Confirmed', 'Rescheduled'])
        .gte('appointment_date', dateIso(DateTime.now()))
        .order('appointment_date', ascending: true)
        .order('appointment_time', ascending: true)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    final list = await _withVetNames([Appointment.fromMap(row)]);
    return list.first;
  }

  static Future<List<Appointment>> myAppointments() async {
    final uid = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('appointments')
        .select(_columns)
        .eq('owner_id', uid)
        .order('appointment_date', ascending: true)
        .order('appointment_time', ascending: true);
    return _withVetNames(rows.map(Appointment.fromMap).toList());
  }

  /// Client cancels their own booking (the database only allows status → cancelled).
  static Future<void> cancel(String appointmentId) async {
    await supabase
        .from('appointments')
        .update({'status': 'Cancelled'}).eq('appointment_id', appointmentId);
  }

  static Future<List<Appointment>> _withVetNames(List<Appointment> list) async {
    final ids = list.map((a) => a.vetId).whereType<String>().toSet().toList();
    if (ids.isEmpty) return list;
    final rows = await supabase
        .from('staff_directory')
        .select('id, full_name')
        .inFilter('id', ids);
    final names = {
      for (final r in rows) r['id'] as String: r['full_name'] as String?
    };
    return list
        .map((a) => a.vetId == null ? a : a.copyWith(vetName: names[a.vetId]))
        .toList();
  }

  static Future<List<TimeSlot>> slotsFor(DateTime day) async {
    final rows = await supabase.rpc('get_available_slots',
        params: {'p_day': dateIso(day)}) as List<dynamic>;
    return rows.map((r) {
      final time = r['slot_time'] as String; // "09:00:00"
      return TimeSlot(
        dbTime: time,
        clinicTime: DateTime.parse('${dateIso(day)}T$time'),
        available: r['available'] as bool,
      );
    }).toList();
  }

  static Future<void> book({
    required String petId,
    required String service,
    required DateTime date,
    required String time,
    required String reason,
    required String urgency,
  }) async {
    await supabase.from('appointments').insert({
      'owner_id': supabase.auth.currentUser!.id,
      'pet_id': petId,
      'appointment_date': dateIso(date),
      'appointment_time': time,
      'service': service,
      'reason': reason,
      'urgency': urgency,
      'status': 'Pending',
    });
  }
}
