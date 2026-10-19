import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../data/pet_care_tips.dart';
import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/paw_background.dart';

class PetCareTipsScreen extends StatelessWidget {
  const PetCareTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedIn = supabase.auth.currentUser != null;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Image.asset('assets/images/logo.png', height: 56),
      ),
      bottomNavigationBar:
          loggedIn ? const AppBottomNav(currentRoute: Routes.tips) : null,
      body: PawBackground(
        seed: 9,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('Pet Care Tips',
                style: AppTheme.heading(size: 30)
                    .copyWith(fontStyle: FontStyle.italic)),
            const Text('Helpful advice for a happy and healthy pet.'),
            const SizedBox(height: 16),

            for (final tip in petCareTips) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border(
                    bottom: BorderSide(
                        color: AppColors.navy.withAlpha(90), width: 3),
                  ),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(tip.icon, size: 34, color: AppColors.textDark),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tip.title,
                              style: text.titleMedium?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(tip.body, style: text.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Closing banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.navy.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pets, size: 30, color: AppColors.textDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('A little care goes a long way',
                            style: text.titleMedium?.copyWith(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w700)),
                        Row(
                          children: [
                            Text('Healthy Pets. Happier Lives ',
                                style: AppTheme.tagline(size: 16)),
                            const Icon(Icons.favorite_border,
                                color: AppColors.red, size: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'These tips are general advice. If your pet seems unwell, please book an '
              'appointment or contact the clinic.',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
