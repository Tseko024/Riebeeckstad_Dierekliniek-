import 'package:flutter/material.dart';
import 'screens/my_appointments_screen.dart';
import 'config/session_prefs.dart';
import 'config/supabase_config.dart';
import 'routes.dart';
import 'screens/book_appointment_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/services_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/pet_care_tips_screen.dart';
import 'screens/messages_screen.dart';
import 'services/message_notifier.dart';
import 'screens/my_pets_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();

  final rememberMe = await SessionPrefs.getRememberMe();
  if (!rememberMe && supabase.auth.currentSession != null) {
    try {
      await supabase.auth.signOut();
    } catch (_) {}
  }

  // NEW: listen for clinic messages (badge + pop-up banner) while the app is open.
  // It follows log-in / log-out by itself.
  MessageNotifier.instance.start();

  final loggedIn = supabase.auth.currentSession != null;
  runApp(RiebeeckstadApp(startRoute: loggedIn ? Routes.home : Routes.welcome));
}

class RiebeeckstadApp extends StatelessWidget {
  const RiebeeckstadApp({super.key, required this.startRoute});

  final String startRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riebeeckstad Dierekliniek',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey:
          MessageNotifier.navigatorKey, // NEW: lets "VIEW" open Messages
      scaffoldMessengerKey: MessageNotifier
          .messengerKey, // NEW: lets the banner show on any screen
      initialRoute: startRoute,
      routes: {
        Routes.welcome: (_) => const WelcomeScreen(),
        Routes.register: (_) => const RegisterScreen(),
        Routes.login: (_) => const LoginScreen(),
        Routes.home: (_) => const HomeScreen(),
        Routes.book: (_) => const BookAppointmentScreen(),
        Routes.pets: (_) => const MyPetsScreen(),
        Routes.appointments: (_) => const MyAppointmentsScreen(),
        Routes.services: (_) => const ServicesScreen(),
        Routes.tips: (_) => const PetCareTipsScreen(),
        Routes.contact: (_) => const ContactsScreen(),
        Routes.messages: (_) => const MessagesScreen(),
        Routes.profile: (_) => const ProfileScreen(),
      },
    );
  }
}
