import 'package:flutter/material.dart';
import '../data/appointments_repo.dart';
import '../data/pet_care_tips.dart';
import '../data/profile_repo.dart';
import '../models/appointment.dart';
import '../routes.dart';
import '../services/message_notifier.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer.dart';
import '../widgets/home_tile.dart';
import '../widgets/paw_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _fullName = '';
  Appointment? _next;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final name = await ProfileRepo.myFullName();
      final next = await AppointmentsRepo.nextUpcoming();
      if (!mounted) return;
      setState(() {
        _fullName = name;
        _next = next;
      });
      // Keep the bell's red number up to date
      MessageNotifier.instance.refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _error = 'Could not load your information. Pull down to try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) _load();
  }

  String get _firstName {
    if (_fullName.isEmpty) return 'there';
    return _fullName.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(name: _fullName),
      appBar: AppBar(
        toolbarHeight: 72,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu, size: 30),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Image.asset('assets/images/logo.png', height: 56),
        actions: [
          // Yellow bell: red badge = unread messages from the clinic. Tap → Messages.
          ValueListenableBuilder<int>(
            valueListenable: MessageNotifier.instance.unread,
            builder: (context, count, _) => IconButton(
              tooltip: count > 0
                  ? '$count new message${count == 1 ? '' : 's'} from the clinic'
                  : 'Messages',
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text(count > 9 ? '9+' : '$count'),
                backgroundColor: AppColors.red,
                child: const Icon(Icons.notifications,
                    color: Color(0xFFF2B705), size: 30),
              ),
              onPressed: () => _open(Routes.messages),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentRoute: Routes.home,
        onRouteSelected: _open,
      ),
      body: PawBackground(
        seed: 4,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _greeting(),
              const SizedBox(height: 12),
              _tiles(),
              const SizedBox(height: 20),
              _upcomingCard(),
              const SizedBox(height: 16),
              _tipCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _greeting() {
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Hello,\n$_firstName! '),
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child:
                      Icon(Icons.waving_hand, color: AppColors.navy, size: 28),
                ),
              ],
            ),
            style: AppTheme.heading(size: 34)
                .copyWith(fontStyle: FontStyle.italic, height: 1.15),
          ),
        ),
        Image.asset('assets/images/pets.png', height: 130),
      ],
    );
  }

  Widget _tiles() {
    Widget tile(IconData icon, Color iconColor, String title, Color titleColor,
            String subtitle, String route) =>
        HomeTile(
          icon: icon,
          iconColor: iconColor,
          title: title,
          titleColor: titleColor,
          subtitle: subtitle,
          onTap: () => _open(route),
        );

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: tile(Icons.pets, AppColors.textDark, 'My Pets',
                  AppColors.red, 'View and manage your pets', Routes.pets),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: tile(
                  Icons.calendar_month,
                  AppColors.navy,
                  'Book Appointment',
                  AppColors.navy,
                  'Schedule a visit with our vets',
                  Routes.book),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: tile(
                  Icons.monitor_heart_outlined,
                  Colors.green,
                  'Our Services',
                  AppColors.textDark,
                  'Explore our veterinary services',
                  Routes.services),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 1),
            Expanded(
              flex: 4,
              child: tile(
                  Icons.lightbulb_outline,
                  const Color(0xFFB8860B),
                  'Pet Care Tips',
                  const Color(0xFFB8860B),
                  'Helpful advice for happier and healthier pets',
                  Routes.tips),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: tile(Icons.phone, AppColors.navy, 'Contact Us',
                  AppColors.navy, 'Get in touch with our team', Routes.contact),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ],
    );
  }

  Widget _upcomingCard() {
    final text = Theme.of(context).textTheme;

    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    } else if (_next == null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('You have no upcoming appointments.'),
            TextButton.icon(
              onPressed: () => _open(Routes.book),
              icon: const Icon(Icons.add),
              label: const Text('Book an appointment'),
            ),
          ],
        ),
      );
    } else {
      body = _appointmentRow(_next!);
    }

    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month, color: AppColors.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Upcoming Appointment',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: () => _open(Routes.appointments),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text('View All'), Icon(Icons.chevron_right)],
                  ),
                ),
              ],
            ),
            body,
          ],
        ),
      ),
    );
  }

  Widget _appointmentRow(Appointment a) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 8),
      child: Row(
        children: [
          // Date block
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Text(two(a.startsAt.day),
                    style: text.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700, height: 1)),
                Text('${monthShort(a.startsAt)} ${yearShort(a.startsAt)}',
                    style: text.bodySmall),
                Text(timeHm(a.startsAt), style: text.bodySmall),
              ],
            ),
          ),
          Container(width: 1, height: 56, color: Colors.black26),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.tile,
            child: Icon(
              a.petSpecies == 'cat' ? Icons.pets_outlined : Icons.pets,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.petName, style: AppTheme.heading(size: 20)),
                Text(a.serviceLabel, style: text.bodySmall),
                if (a.vetName != null)
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: AppColors.navy),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(a.vetName!,
                            style: text.bodySmall,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          _statusChip(a.status, a.statusLabel),
        ],
      ),
    );
  }

  Widget _statusChip(String status, String label) {
    final (bg, fg) = switch (status) {
      'confirmed' => (const Color(0xFFD7F5D9), const Color(0xFF1B7A2B)),
      'pending' => (const Color(0xFFFFF1C9), const Color(0xFF8A6200)),
      _ => (AppColors.tile, AppColors.textDark),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style:
              TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _tipCard() {
    final tip = tipOfTheDay();
    final text = Theme.of(context).textTheme;

    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(Routes.tips),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.pets_outlined,
                  size: 34, color: AppColors.textDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pet Care Tip of the Day',
                        style: text.titleSmall?.copyWith(
                            color: AppColors.red, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(tip.title,
                        style: text.bodyMedium?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700)),
                    Text(tip.body, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Image.asset('assets/images/pets.png', height: 64),
            ],
          ),
        ),
      ),
    );
  }
}
