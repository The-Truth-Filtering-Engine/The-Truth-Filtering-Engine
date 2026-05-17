import 'package:shared_preferences/shared_preferences.dart';

class KakaoWebViewSession {
  static const _sessionReadyKey = 'kakao_webview_session_ready';

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
      'accounts.kakao.com',
      '/login/',
      {'continue': redirectUri.toString()},
    );
  }

  static bool isLoginUri(Uri uri) {
    return uri.host.toLowerCase() == 'accounts.kakao.com' &&
        uri.path.contains('login');
  }

  static bool isKakaoSourceUri(Uri uri) {
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    return host == 'tistory.com' ||
        host.endsWith('.tistory.com') ||
        host == 'brunch.co.kr' ||
        host == 'brunchstory.co.kr' ||
        host == 'cafe.daum.net' ||
        host == 'm.cafe.daum.net';
  }
}
