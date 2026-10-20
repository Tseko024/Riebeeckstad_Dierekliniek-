import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../data/clinic_services.dart';
import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/paw_background.dart';
import '../widgets/pill_button.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  static const _pink = Color(0xFFF2C4C8);
  static const _blue = Color(0xFFC6D4EC);

  bool get _loggedIn => supabase.auth.currentUser != null;

  void _showService(BuildContext context, ClinicService s, Color circle) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: circle,
                child: Icon(s.icon, size: 36, color: AppColors.red),
              ),
              const SizedBox(height: 12),
              Text(s.title,
                  style: AppTheme.heading(size: 26),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(s.details, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: PillButton(
                  label: 'Book this service',
                  color: AppColors.red,
                  icon: Icons.calendar_month,
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (_loggedIn) {
                      Navigator.pushNamed(context, Routes.book,
                          arguments: s.bookingValue);
                    } else {
                      Navigator.pushNamed(context, Routes.login);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Image.asset('assets/images/logo.png', height: 56),
      ),
      bottomNavigationBar:
          _loggedIn ? const AppBottomNav(currentRoute: Routes.services) : null,
      body: PawBackground(
        seed: 8,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Our Services',
                      style: AppTheme.heading(size: 30)
                          .copyWith(fontStyle: FontStyle.italic)),
                ),
                const Icon(Icons.pets, color: AppColors.textDark, size: 28),
              ],
            ),
            const Text('Comprehensive care for your furry friends'),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: clinicServices.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemBuilder: (context, i) {
                final s = clinicServices[i];
                final circle =
                    i.isEven ? _pink : _blue; // alternate like the mockup
                return _ServiceTile(
                  service: s,
                  circleColor: circle,
                  onTap: () => _showService(context, s, circle),
                );
              },
            ),
            const SizedBox(height: 12),
            const Center(child: Icon(Icons.pets, color: AppColors.textDark)),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.circleColor,
    required this.onTap,
  });

  final ClinicService service;
  final Color circleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration:
                    BoxDecoration(color: circleColor, shape: BoxShape.circle),
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(service.icon, color: AppColors.red),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            service.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            service.blurb,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(fontSize: 11, height: 1.2),
          ),
        ],
      ),
    );
  }
}
