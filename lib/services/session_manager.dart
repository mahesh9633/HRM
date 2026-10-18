import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyLastUrl = 'last_url';
  static const String _keySharedStorage = 'shared_storage_json';
  static const String _keySharedCookies = 'shared_cookies_json';

  static Future<void> saveSession(
    String url, {
    String? storageJson,
    String? cookiesJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyLastUrl, url);
    if (storageJson != null) {
      await prefs.setString(_keySharedStorage, storageJson);
    }
    if (cookiesJson != null) {
      await prefs.setString(_keySharedCookies, cookiesJson);
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyLastUrl);
    await prefs.remove(_keySharedStorage);
    await prefs.remove(_keySharedCookies);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<String?> getLastUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastUrl);
  }

  static Future<String?> getSharedStorage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySharedStorage);
  }

  static Future<String?> getSharedCookies() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySharedCookies);
  }

  static Map<String, dynamic> cookieToMap(Cookie c) {
    return {
      'name': c.name,
      'value': c.value,
      'domain': c.domain,
      'path': c.path,
      'isSecure': c.isSecure,
      'isHttpOnly': c.isHttpOnly,
      'expiresDate': c.expiresDate,
    };
  }

  static Cookie mapToCookie(Map<String, dynamic> map) {
    return Cookie(
      name: map['name']?.toString() ?? '',
      value: map['value'] ?? '',
      domain: map['domain']?.toString(),
      path: map['path']?.toString() ?? '/',
      isSecure: map['isSecure'] as bool?,
      isHttpOnly: map['isHttpOnly'] as bool?,
      expiresDate: map['expiresDate'] as int?,
    );
  }
}
