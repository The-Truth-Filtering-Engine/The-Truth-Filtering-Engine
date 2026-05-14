import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class TestAccountAuthConfig {
  static const email = 'test@example.com';
  static const headerName = 'X-Test-Account-Email';

  static Map<String, String> headers({required bool isTestAccountLogin}) {
    if (isTestAccountLogin) {
      return {headerName: email};
    }

    final token = _currentAccessToken();
    if (token != null) {
      return {'Authorization': 'Bearer $token'};
    }

    return const {};
  }

  static String? _currentAccessToken() {
    if (!SupabaseConfig.isConfigured) return null;
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) return null;
    return token;
  }
}
