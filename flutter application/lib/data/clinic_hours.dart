class OpeningPeriod {
  final int startMinute;
  final int endMinute;

  const OpeningPeriod(this.startMinute, this.endMinute);

  String get label =>
      '${ClinicHours.formatMinutes(startMinute)} – ${ClinicHours.formatMinutes(endMinute)}';
}

class ClinicStatus {
  final bool isOpen;
  final String text;

  const ClinicStatus(this.isOpen, this.text);
}

class ClinicHours {
  ClinicHours._();

  static const List<OpeningPeriod> _weekday = [
    OpeningPeriod(9 * 60, 11 * 60),
    OpeningPeriod(16 * 60, 18 * 60),
  ];

  static const Map<int, List<OpeningPeriod>> week = {
    DateTime.monday: _weekday,
    DateTime.tuesday: _weekday,
    DateTime.wednesday: _weekday,
    DateTime.thursday: _weekday,
    DateTime.friday: _weekday,
    DateTime.saturday: [OpeningPeriod(9 * 60, 12 * 60)],
    DateTime.sunday: [OpeningPeriod(11 * 60, 12 * 60)],
  };

  /// One-line summary, e.g. for the booking screen.
  static const String summary =
      'Mon–Fri 09:00–11:00 & 16:00–18:00 · Sat 09:00–12:00 · Sun 11:00–12:00';

  static const List<int> daysInOrder = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  static const Map<int, String> dayNames = {
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
  };

  static List<OpeningPeriod> periodsFor(int weekday) =>
      week[weekday] ?? const [];

  static String hoursText(int weekday) {
    final periods = periodsFor(weekday);
    return periods.isEmpty ? 'Closed' : periods.map((p) => p.label).join('\n');
  }

  static String formatMinutes(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  static DateTime nowInClinic() =>
      DateTime.now().toUtc().add(const Duration(hours: 2));

  static ClinicStatus statusAt(DateTime now) {
    final minute = now.hour * 60 + now.minute;

    for (final p in periodsFor(now.weekday)) {
      if (minute >= p.startMinute && minute < p.endMinute) {
        return ClinicStatus(
            true, 'Open now · closes ${formatMinutes(p.endMinute)}');
      }
    }

    for (final p in periodsFor(now.weekday)) {
      if (p.startMinute > minute) {
        return ClinicStatus(
            false, 'Closed · opens at ${formatMinutes(p.startMinute)}');
      }
    }

    for (var add = 1; add <= 7; add++) {
      final day = (now.weekday - 1 + add) % 7 + 1;
      final periods = periodsFor(day);
      if (periods.isNotEmpty) {
        final when = add == 1 ? 'tomorrow' : dayNames[day]!;
        return ClinicStatus(false,
            'Closed · opens $when at ${formatMinutes(periods.first.startMinute)}');
      }
    }
    return const ClinicStatus(false, 'Closed');
  }
}
