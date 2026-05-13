import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class TestAdminAuthConfig {
  static const email = 'test@example.com';
  static const userId = 0;
  static const headerName = 'X-Temporary-Admin-Email';

  static Map<String, String> headers({required bool isAdmin}) {
    final token = _currentAccessToken();
    if (token != null) {
      return {'Authorization': 'Bearer $token'};
    }
    if (isAdmin) {
      return {headerName: email};
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
