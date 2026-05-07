import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/backend_config.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/providers/analysis_mode_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  UserProfile? _profile;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isSaving = false;

  String? get _accessToken {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  bool get _hasGoogleSession => _accessToken != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasGoogleSession) {
        _loadProfile();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(analysisModeProvider);
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '광고 판별 방식',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.memory,
                    color:
                        currentMode == AnalysisMode.model ? color : Colors.grey,
                  ),
                  title: const Text('AI 모델'),
                  subtitle: const Text('파인튜닝된 언어 모델로 판별'),
                  trailing: currentMode == AnalysisMode.model
                      ? Icon(Icons.check_circle, color: color)
                      : const Icon(
                          Icons.radio_button_unchecked,
                          color: Colors.grey,
                        ),
                  onTap: () => ref.read(analysisModeProvider.notifier).state =
                      AnalysisMode.model,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: Icon(
                    Icons.psychology,
                    color:
                        currentMode == AnalysisMode.llm ? color : Colors.grey,
                  ),
                  title: const Text('LLM (GPT)'),
                  subtitle: const Text('GPT로 판별'),
                  trailing: currentMode == AnalysisMode.llm
                      ? Icon(Icons.check_circle, color: color)
                      : const Icon(
                          Icons.radio_button_unchecked,
                          color: Colors.grey,
                        ),
                  onTap: () => ref.read(analysisModeProvider.notifier).state =
                      AnalysisMode.llm,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '계정',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          _accountSection(),
          const SizedBox(height: 12),
          _logoutButton(),
        ],
      ),
    );
  }

  Widget _accountSection() {
    if (!_hasGoogleSession) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.admin_panel_settings_outlined),
                title: Text('임시 관리자 로그인'),
                subtitle: Text('Google 로그인 사용자가 아니어서 결제 설정은 비활성화됩니다.'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  OutlinedButton(
                    onPressed: null,
                    child: Text('프리미엄 설정'),
                  ),
                  OutlinedButton(
                    onPressed: null,
                    child: Text('1,000 코인 충전'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading && _profile == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_errorMessage != null && _profile == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _loadProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Google 로그인 정보를 확인할 수 없습니다'),
        ),
      );
    }

    return Column(
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(profile.email),
                subtitle: Text(profile.isPremium ? '프리미엄 사용자' : '일반 사용자'),
              ),
              const Divider(height: 0),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _statTile('Coin', profile.coin.toString()),
                    _statTile('Free', profile.freecount.toString()),
                    _statTile('Premium', profile.premiumcount.toString()),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '프리미엄',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '현재 계정의 premium 값을 ${profile.isPremium ? 0 : 1}로 저장합니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _togglePremium,
                  icon: Icon(
                    profile.isPremium
                        ? Icons.workspace_premium
                        : Icons.workspace_premium_outlined,
                  ),
                  label: Text(profile.isPremium ? '프리미엄 해제' : '프리미엄 설정'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '코인 충전',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '테스트용 충전 버튼입니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1000, 2000, 3000]
                      .map(
                        (amount) => OutlinedButton.icon(
                          onPressed:
                              _isSaving ? null : () => _chargeCoins(amount),
                          icon: const Icon(Icons.monetization_on_outlined),
                          label: Text(amount.toString()),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ],
    );
  }

  Widget _statTile(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _logoutButton() {
    return OutlinedButton.icon(
      onPressed: _logout,
      icon: const Icon(Icons.logout),
      label: const Text('로그아웃'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        minimumSize: const Size.fromHeight(46),
      ),
    );
  }

  Future<void> _loadProfile() async {
    final token = _accessToken;
    if (token == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _requestProfile(token);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _togglePremium() async {
    final token = _accessToken;
    final profile = _profile;
    if (token == null || profile == null) return;

    await _mutateProfile(
      () => _requestProfile(
        token,
        method: 'PATCH',
        path: '/user/me/premium',
        body: {'premium': !profile.isPremium},
      ),
      profile.isPremium ? '프리미엄이 해제되었습니다' : '프리미엄이 설정되었습니다',
    );
  }

  Future<void> _chargeCoins(int amount) async {
    final token = _accessToken;
    if (token == null) return;

    await _mutateProfile(
      () => _requestProfile(
        token,
        method: 'POST',
        path: '/user/me/coins',
        body: {'amount': amount},
      ),
      '$amount 코인이 충전되었습니다',
    );
  }

  Future<void> _mutateProfile(
    Future<UserProfile> Function() request,
    String successMessage,
  ) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final profile = await request();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<UserProfile> _requestProfile(
    String token, {
    String method = 'GET',
    String path = '/user/me',
    Map<String, Object?>? body,
  }) async {
    final uri = BackendConfig.apiUri(path);
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final response = switch (method) {
      'PATCH' => await http.patch(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
      'POST' => await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
      _ => await http.get(uri, headers: headers),
    };

    final text = utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? null : jsonDecode(text);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? decoded['detail']?.toString() ?? '요청 실패: ${response.statusCode}'
          : '요청 실패: ${response.statusCode}';
      throw Exception(message);
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('사용자 응답 형식이 올바르지 않습니다');
    }

    return UserProfile.fromJson(decoded);
  }

  Future<void> _logout() async {
    try {
      if (SupabaseConfig.isConfigured &&
          Supabase.instance.client.auth.currentSession != null) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃하지 못했습니다')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }
}

class UserProfile {
  const UserProfile({
    required this.email,
    required this.premium,
    required this.coin,
    required this.freecount,
    required this.premiumcount,
    this.store,
    this.bookmark,
  });

  final String email;
  final int premium;
  final int coin;
  final int freecount;
  final int premiumcount;
  final Object? store;
  final String? bookmark;

  bool get isPremium => premium == 1;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      email: json['email']?.toString() ?? '',
      premium: _intFromJson(json['premium']),
      coin: _intFromJson(json['coin']),
      freecount: _intFromJson(json['freecount']),
      premiumcount: _intFromJson(json['premiumcount']),
      store: json['store'],
      bookmark: json['bookmark']?.toString(),
    );
  }

  static int _intFromJson(Object? value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }
}
