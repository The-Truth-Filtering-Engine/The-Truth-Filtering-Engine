import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/providers/analysis_mode_provider.dart';
import '../../../core/providers/user_profile_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _errorMessage;
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
        ref.read(userProfileProvider.notifier).loadIfPossible(force: true);
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
    final profileState = ref.watch(userProfileProvider);
    final profile = profileState.asData?.value;
    final profileError =
        profileState.hasError ? profileState.error.toString() : null;

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

    if (profileState.isLoading && profile == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (profileError != null && profile == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                profileError,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: profileState.isLoading ? null : _loadProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

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
    setState(() {
      _errorMessage = null;
    });
    await ref.read(userProfileProvider.notifier).loadIfPossible(force: true);
  }

  Future<void> _togglePremium() async {
    final profile = ref.read(userProfileProvider).asData?.value;
    if (!_hasGoogleSession || profile == null) return;

    await _mutateProfile(
      () =>
          ref.read(userProfileProvider.notifier).setPremium(!profile.isPremium),
      profile.isPremium ? '프리미엄이 해제되었습니다' : '프리미엄이 설정되었습니다',
    );
  }

  Future<void> _chargeCoins(int amount) async {
    if (!_hasGoogleSession) return;

    await _mutateProfile(
      () => ref.read(userProfileProvider.notifier).chargeCoins(amount),
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
      await request();
      if (!mounted) return;
      setState(() {
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
