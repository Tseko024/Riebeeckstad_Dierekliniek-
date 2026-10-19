import 'package:shared_preferences/shared_preferences.dart';

class SessionPrefs {
  SessionPrefs._();

  static const _rememberMeKey = 'remember_me';

  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  static Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }
}
