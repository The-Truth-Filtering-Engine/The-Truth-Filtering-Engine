import 'package:shared_preferences/shared_preferences.dart';

class NaverWebViewSession {
  static const _sessionReadyKey = 'naver_webview_session_ready';

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

  static Uri loginUri({required Uri redirectUri}) {
    return Uri.https(
      'nid.naver.com',
      '/nidlogin.login',
      {'url': redirectUri.toString()},
    );
  }

  static bool isLoginUri(Uri uri) {
    return uri.host.toLowerCase() == 'nid.naver.com' &&
        uri.path.contains('nidlogin');
  }

  static bool isNaverSourceUri(Uri uri) {
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    return host == 'blog.naver.com' ||
        host == 'm.blog.naver.com' ||
        host == 'cafe.naver.com' ||
        host == 'm.cafe.naver.com';
  }
}
