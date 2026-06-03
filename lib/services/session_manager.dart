
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {

  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyLastUrl    = 'last_url';


  static Future<void> saveSession(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyLastUrl, url);
  }


  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyLastUrl);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<String?> getLastUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastUrl);
  }
}