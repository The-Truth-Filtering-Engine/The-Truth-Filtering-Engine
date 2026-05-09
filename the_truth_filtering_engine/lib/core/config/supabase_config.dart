class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String mobileRedirectUrl =
      'com.juyeong.truthfilteringengine://login-callback';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
