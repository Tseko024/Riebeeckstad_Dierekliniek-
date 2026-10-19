import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static Future<void> init() async {
    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'Missing Supabase keys. Run with:\n'
        'flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...',
      );
    }
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }
}

/// Shortcut used by all screens.
SupabaseClient get supabase => Supabase.instance.client;
