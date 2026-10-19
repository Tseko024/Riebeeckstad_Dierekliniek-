import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/opening_hours_card.dart';

/// Contact Us: call, directions, WhatsApp, Facebook, address, phone, opening hours.
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  static const _clinicName = 'Riebeeckstad Dierekliniek';
  static const _address = '138 Mc Lean St, Riebeeckstad, Welkom, 9459';
  static const _phoneDisplay = '057 388 1409';
  static const _phoneDial = '+27573881409';

  static const _whatsappNumber = '27573881409';

  static const _facebookUrl =
      'https://www.facebook.com/search/top?q=Riebeeckstad%20Dierekliniek';

  static const _mapsUrl =
      'https://www.google.com/maps/search/?api=1&query=Riebeeckstad+Dierekliniek+138+Mc+Lean+St+Welkom';

  // Colours
  static const _navy = Color(0xFF323376);
  static const _red = Color(0xFF97080F);
  static const _whatsappGreen = Color(0xFF25D366);
  static const _facebookBlue = Color(0xFF1877F2);

  static String get _whatsappUrl =>
      'https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent('Hello Riebeeckstad Dierekliniek, ')}';

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this on your phone.')),
      );
    }
  }

  void _copy(BuildContext context, String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$what copied')));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Contact Us'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Heading
            Text(
              _clinicName,
              style: textTheme.headlineSmall
                  ?.copyWith(color: _navy, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Veterinarian · Welkom, Free State',
              style: textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 16),

            // Quick actions: Call + Directions
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.call,
                    label: 'Call',
                    color: _red,
                    onTap: () => _open(context, Uri.parse('tel:$_phoneDial')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.directions,
                    label: 'Directions',
                    color: _navy,
                    onTap: () => _open(context, Uri.parse(_mapsUrl)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // WhatsApp + Facebook
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.chat,
                    label: 'WhatsApp',
                    color: _whatsappGreen,
                    onTap: () => _open(context, Uri.parse(_whatsappUrl)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.facebook,
                    label: 'Facebook',
                    color: _facebookBlue,
                    onTap: () => _open(context, Uri.parse(_facebookUrl)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Address + phone
            _InfoTile(
              icon: Icons.location_on_outlined,
              title: 'Address',
              value: _address,
              onTap: () => _open(context, Uri.parse(_mapsUrl)),
              onLongPress: () => _copy(context, _address, 'Address'),
            ),
            _InfoTile(
              icon: Icons.phone_outlined,
              title: 'Phone',
              value: _phoneDisplay,
              onTap: () => _open(context, Uri.parse('tel:$_phoneDial')),
              onLongPress: () => _copy(context, _phoneDisplay, 'Phone number'),
            ),
            const SizedBox(height: 16),

            // Opening hours (from lib/data/clinic_hours.dart)
            const OpeningHoursCard(),
            const SizedBox(height: 16),

            // Emergency note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x1497080F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: _red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Emergency? Please phone the clinic on $_phoneDisplay '
                      'instead of booking online.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF2F3F8),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF323376)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
