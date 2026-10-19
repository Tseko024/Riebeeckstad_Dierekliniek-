class ClinicInfo {
  ClinicInfo._();

  static const name = 'Riebeeckstad Dierekliniek';
  static const address = '138 Mc Lean St, Riebeeckstad, Welkom, 9459';

  static const phoneDisplay = '057 357 1234';
  static const phoneDial = '0573571234';

  static const whatsappDisplay = '082 123 4567';
  static const whatsappInternational = '27821234567'; // 082… → 27 82…

  static const email = 'info@riebeeckstadvets.co.za';
  static const facebookName = 'Riebeeckstad & Toronto Animal Clinic';

  static const hours = [
    ('Monday – Friday', '08:00 – 17:00'),
    ('Saturday', '08:00 – 12:00'),
    ('Sunday', 'Closed'),
  ];

  static Uri get phoneUri => Uri(scheme: 'tel', path: phoneDial);
  static Uri get whatsappUri =>
      Uri.parse('https://wa.me/$whatsappInternational');
  static Uri get emailUri => Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'Enquiry from the app'});
  static Uri get mapsUri => Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$name, $address')}');
  static Uri get facebookUri => Uri.parse(
      'https://www.facebook.com/search/top?q=${Uri.encodeComponent(facebookName)}');
}
