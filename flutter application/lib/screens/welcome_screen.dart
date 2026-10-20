import 'package:flutter/material.dart';
import '../widgets/paw_background.dart';
import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/pill_button.dart';
import '../widgets/shortcut_tile.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void go(String route) => Navigator.pushNamed(context, route);

    return Scaffold(
      body: PawBackground(
        seed: 1,
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      _logo(),
                      const SizedBox(height: 32),
                      _tagline(),
                      const SizedBox(height: 28),
                      _shortcuts(go),
                      const SizedBox(height: 32),
                      _authButtons(go),
                      const SizedBox(height: 24),
                      _pets(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Center(
      child: Semantics(
        label: 'Riebeeckstad and Toronto Dierekliniek Animal Clinic logo',
        image: true,
        child: Image.asset(
          'assets/images/logo.png',
          width: 210,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _tagline() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'Healthy Pets. Happier Lives',
            textAlign: TextAlign.center,
            style: AppTheme.tagline(size: 22),
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.favorite, color: AppColors.red, size: 24),
      ],
    );
  }

  Widget _shortcuts(void Function(String) go) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: ShortcutTile(
              icon: Icons.calendar_month,
              iconColor: AppColors.navy,
              label: 'Book Appointment',
              // Booking needs an account, so start at login.
              onTap: () => go(Routes.login),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ShortcutTile(
              icon: Icons.pets,
              iconColor: Colors.black,
              label: 'Our Services',
              onTap: () => go(Routes.services),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ShortcutTile(
              icon: Icons.monitor_heart,
              iconColor: AppColors.red,
              label: 'Pet Care Tips',
              onTap: () => go(Routes.tips),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authButtons(void Function(String) go) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: Column(
          children: [
            PillButton(
              label: 'Log In',
              color: AppColors.navy,
              onPressed: () => go(Routes.login),
            ),
            const SizedBox(height: 12),
            PillButton(
              label: 'Register',
              color: AppColors.red,
              onPressed: () => go(Routes.register),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pets() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: ExcludeSemantics(
        child: Image.asset(
          'assets/images/pets.png',
          height: 170,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
