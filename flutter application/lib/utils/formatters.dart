const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC'
];
const _monthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December'
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String two(int n) => n.toString().padLeft(2, '0');

String monthShort(DateTime d) => _months[d.month - 1];

String yearShort(DateTime d) => two(d.year % 100);

String timeHm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String dateLong(DateTime d) =>
    '${_days[d.weekday - 1]}, ${d.day} ${_monthsLong[d.month - 1]} ${d.year}';

String dateIso(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
