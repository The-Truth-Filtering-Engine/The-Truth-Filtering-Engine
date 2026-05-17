import 'package:shared_preferences/shared_preferences.dart';

class GoogleSourceSession {
  static const _sessionReadyKey = 'google_source_external_session_ready';

  static Future<bool> isReady() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sessionReadyKey) ?? false;
  }

  static Future<void> markReady() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionReadyKey, true);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionReadyKey);
  }

  static bool isGoogleSourceUri(Uri uri) {
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final path = uri.path.toLowerCase();
    return host == 'youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'youtu.be' ||
        host == 'blogger.com' ||
        host.endsWith('.blogger.com') ||
        host == 'blogspot.com' ||
        host.endsWith('.blogspot.com') ||
        host == 'maps.app.goo.gl' ||
        (host == 'google.com' && path.startsWith('/maps')) ||
        (host.endsWith('.google.com') && path.startsWith('/maps')) ||
        (host.endsWith('.google.co.kr') && path.startsWith('/maps'));
  }
}
