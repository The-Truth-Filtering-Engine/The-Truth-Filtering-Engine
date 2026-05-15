part of 'settings_screen.dart';

const _initialBookmarkRegion = '광교';

extension _SettingsAccountSection on _SettingsScreenState {
  Widget _accountSection() {
    final profileState = ref.watch(userProfileProvider);
    final profile = profileState.asData?.value;
    final profileError =
        profileState.hasError ? profileState.error.toString() : null;

    if (!_hasGoogleSession) {
      return Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.admin_panel_settings_outlined),
                    title: Text('임시 관리자 로그인'),
                    subtitle: Text('소셜 로그인 계정이 아니어서 결제 설정은 비활성화됩니다.'),
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
          ),
          const SizedBox(height: 12),
          _premiumCard(null),
          const SizedBox(height: 12),
          _coinChargeCard(),
          const SizedBox(height: 12),
          _accountManagementCard(),
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

    if (profileState.isLoading && profile == null) {
      return Column(
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          const SizedBox(height: 12),
          _linkedLoginAccountsCard(),
          const SizedBox(height: 12),
          _accountManagementCard(),
          const SizedBox(height: 12),
          _premiumCard(null),
          const SizedBox(height: 12),
          _coinChargeCard(),
        ],
      );
    }

    if (profileError != null && profile == null) {
      final accountErrorMessage = _accountLoadErrorMessage(profileError);
      return Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '계정 정보를 불러오지 못했습니다',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    accountErrorMessage,
                    style: const TextStyle(color: Colors.grey),
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
          ),
          const SizedBox(height: 12),
          _premiumCard(null),
          const SizedBox(height: 12),
          _coinChargeCard(),
          const SizedBox(height: 12),
          _accountManagementCard(),
        ],
      );
    }

    if (profile == null) {
      return Column(
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('로그인 정보를 확인할 수 없습니다'),
            ),
          ),
          const SizedBox(height: 12),
          _premiumCard(null),
          const SizedBox(height: 12),
          _coinChargeCard(),
          const SizedBox(height: 12),
          _accountManagementCard(),
        ],
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
        _linkedLoginAccountsCard(),
        const SizedBox(height: 12),
        _accountManagementCard(),
        const SizedBox(height: 12),
        _premiumCard(profile),
        const SizedBox(height: 12),
        _coinChargeCard(),
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

  Widget _premiumCard(UserProfile? profile) {
    final canEdit = _hasGoogleSession && profile != null && !_isSaving;

    return Card(
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
              profile == null
                  ? '소셜 로그인 계정에서 사용할 수 있습니다.'
                  : '현재 계정의 premium 값을 ${profile.isPremium ? 0 : 1}로 저장합니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: canEdit ? _togglePremium : null,
              icon: Icon(
                profile?.isPremium == true
                    ? Icons.workspace_premium
                    : Icons.workspace_premium_outlined,
              ),
              label: Text(
                profile?.isPremium == true ? '프리미엄 해제' : '프리미엄 설정',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coinChargeCard() {
    final canCharge = _hasGoogleSession && !_isSaving;

    return Card(
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
              canCharge ? '테스트용 충전 버튼입니다.' : '소셜 로그인 계정에서 사용할 수 있습니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [1000, 2000, 3000]
                  .map(
                    (amount) => OutlinedButton.icon(
                      onPressed: canCharge ? () => _chargeCoins(amount) : null,
                      icon: const Icon(Icons.monetization_on_outlined),
                      label: Text(amount.toString()),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountManagementCard() {
    final disabled = _isSaving;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '계정 관리',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _hasGoogleSession
                  ? '이용 정보 리셋 또는 소셜 연동 전체 해제 및 계정 삭제를 진행할 수 있습니다.'
                  : '이 기기의 사용 기록을 비우거나, 임시 세션을 종료할 수 있습니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: disabled ? null : _confirmResetAccountData,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('이용 정보 리셋'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: disabled ? null : _confirmDeleteAccount,
              icon: const Icon(Icons.person_remove_alt_1_outlined),
              label: const Text('계정 삭제 — 소셜 연동 전체 해제'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.redAccent),
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkedLoginAccountsCard() {
    final providers = const [
      _LoginProviderOption(
        id: 'kakao',
        label: '카카오',
        provider: OAuthProvider.kakao,
        color: Color(0xFFFEE500),
        foreground: Color(0xFF191919),
        mark: 'K',
      ),
      _LoginProviderOption(
        id: 'naver',
        label: '네이버',
        provider: OAuthProvider('naver'),
        color: Color(0xFF03C75A),
        foreground: Colors.white,
        mark: 'N',
      ),
      _LoginProviderOption(
        id: 'google',
        label: 'Google',
        provider: OAuthProvider.google,
        color: Colors.white,
        foreground: Color(0xFF333333),
        mark: 'G',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '로그인 계정',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  tooltip: '연동 상태 새로고침',
                  onPressed:
                      _isLoadingLinkedProviders ? null : _loadLinkedProviders,
                  icon: _isLoadingLinkedProviders
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '처음 한 번만 연동하면 이후에는 같은 계정으로 바로 로그인할 수 있어요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...providers.map(
              (provider) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _linkedLoginAccountTile(provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkedLoginAccountTile(_LoginProviderOption option) {
    final linked = _linkedProviders.contains(option.id);
    final loading = _linkingProvider == option.id;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: option.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12),
            ),
            alignment: Alignment.center,
            child: Text(
              option.mark,
              style: TextStyle(
                color: option.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  linked ? '연결됨' : '연결 필요',
                  style: TextStyle(
                    fontSize: 12,
                    color: linked ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (linked)
            const Icon(Icons.check_circle, color: Colors.green)
          else
            OutlinedButton(
              onPressed: loading ? null : () => _linkLoginProvider(option),
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('연동'),
            ),
        ],
      ),
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
    _updateSettingsState(() {
      _errorMessage = null;
    });
    await ref.read(userProfileProvider.notifier).loadIfPossible(force: true);
  }

  Future<void> _loadLinkedProviders() async {
    if (!SupabaseConfig.isConfigured ||
        Supabase.instance.client.auth.currentSession == null) {
      return;
    }

    _updateSettingsState(() {
      _isLoadingLinkedProviders = true;
    });

    try {
      final identities =
          await Supabase.instance.client.auth.getUserIdentities();
      if (!mounted) return;
      _updateSettingsState(() {
        _linkedProviders = identities
            .map((identity) => _normalizedProviderId(identity.provider))
            .toSet();
        _isLoadingLinkedProviders = false;
      });
    } catch (error) {
      if (!mounted) return;
      _updateSettingsState(() {
        _isLoadingLinkedProviders = false;
        _linkedProviders = const {};
      });
      debugPrint('Linked providers load failed: $error');
    }
  }

  Future<void> _linkLoginProvider(_LoginProviderOption option) async {
    if (!SupabaseConfig.isConfigured ||
        Supabase.instance.client.auth.currentSession == null) {
      return;
    }

    _updateSettingsState(() {
      _linkingProvider = option.id;
      _errorMessage = null;
    });

    try {
      final redirectTo =
          kIsWeb ? '${Uri.base.origin}/' : SupabaseConfig.mobileRedirectUrl;
      final response = await Supabase.instance.client.auth.getLinkIdentityUrl(
        option.provider,
        redirectTo: redirectTo,
      );
      final opened = await launchUrl(
        Uri.parse(response.url),
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception('${option.label} 연동 화면을 열지 못했습니다');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${option.label} 계정 연동을 진행해 주세요')),
      );
    } catch (error) {
      if (!mounted) return;
      _updateSettingsState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        _updateSettingsState(() {
          _linkingProvider = null;
        });
      }
    }
  }

  String _accountLoadErrorMessage(String error) {
    if (error.contains('403')) {
      return '로그인 세션이 만료됐거나 서버 권한 확인에 실패했습니다. 다시 로그인하거나 잠시 후 다시 시도해 주세요.';
    }
    return '서버 연결 상태를 확인한 뒤 다시 시도해 주세요.';
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

  Future<void> _confirmResetAccountData() async {
    final confirmed = await _showDestructiveConfirmDialog(
      title: '이용 정보를 리셋할까요?',
      message: _hasGoogleSession
          ? '북마크, 최근 본 리뷰, 리뷰 좋아요/싫어요, 검색 기록이 삭제됩니다. 로그인 계정과 코인/프리미엄 정보는 유지됩니다.'
          : '이 기기에 저장된 북마크와 최근 기록이 삭제됩니다.',
      confirmLabel: '리셋',
    );
    if (!confirmed) return;

    await _resetAccountData();
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await _showDestructiveConfirmDialog(
      title: _hasGoogleSession ? '계정을 삭제할까요?' : '임시 세션을 종료할까요?',
      message: _hasGoogleSession
          ? '소셜 연동 전체가 해제되고 앱 계정과 개인 사용 데이터가 삭제됩니다. 이 작업은 되돌릴 수 없으며, 다시 이용하려면 새로 로그인해야 합니다.'
          : '이 기기의 사용 기록을 비우고 시작 화면으로 돌아갑니다.',
      confirmLabel: _hasGoogleSession ? '삭제' : '종료',
    );
    if (!confirmed) return;

    await _deleteAccount();
  }

  Future<bool> _showDestructiveConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _resetAccountData() async {
    if (!_hasGoogleSession) {
      _updateSettingsState(() {
        _isSaving = true;
        _errorMessage = null;
      });
      try {
        await _resetLocalAccountData();
        if (!mounted) return;
        _updateSettingsState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이용 정보가 리셋되었습니다')),
        );
      } catch (error) {
        if (!mounted) return;
        _updateSettingsState(() {
          _isSaving = false;
          _errorMessage = error.toString();
        });
      }
      return;
    }

    await _mutateProfile(
      () => ref.read(userProfileProvider.notifier).resetAccountData(),
      '계정 정보가 리셋되었습니다',
      afterSuccess: _resetLocalAccountData,
    );
  }

  Future<void> _deleteAccount() async {
    _updateSettingsState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_hasGoogleSession) {
        await _unlinkAllSocialAccounts();
        await ref.read(userProfileProvider.notifier).deleteAccount();
      }
      await _clearDeletedAccountLocalData();

      try {
        if (SupabaseConfig.isConfigured) {
          await Supabase.instance.client.auth.signOut();
        }
      } catch (_) {}

      ref.read(appAuthProvider.notifier).signOut();

      if (!mounted) return;
      _updateSettingsState(() {
        _isSaving = false;
      });
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } catch (error) {
      if (!mounted) return;
      _updateSettingsState(() {
        _isSaving = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _unlinkAllSocialAccounts() async {
    if (!SupabaseConfig.isConfigured ||
        Supabase.instance.client.auth.currentSession == null) {
      return;
    }

    try {
      final identities =
          await Supabase.instance.client.auth.getUserIdentities();
      final targets = identities
          .where((identity) => _isManagedSocialProvider(identity.provider))
          .toList();

      await Future.wait(
        targets.map((identity) async {
          try {
            await Supabase.instance.client.auth.unlinkIdentity(identity);
          } catch (error) {
            debugPrint(
              '${identity.provider} 연동 해제 실패 또는 미연동 상태: $error',
            );
          }
        }),
      );
    } catch (error) {
      debugPrint('소셜 연동 전체 해제 확인 실패: $error');
    }
  }

  bool _isManagedSocialProvider(String provider) {
    final normalized = _normalizedProviderId(provider);
    return normalized == 'kakao' ||
        normalized == 'naver' ||
        normalized == 'google';
  }

  String _normalizedProviderId(String provider) {
    final normalized = provider.toLowerCase();
    if (normalized == 'kakao' ||
        normalized == 'naver' ||
        normalized == 'google') {
      return normalized;
    }
    return normalized.replaceAll('_oauth2', '');
  }

  Future<void> _clearLocalAccountData() async {
    await ref.read(bookmarkRestaurantsProvider.notifier).clearLocal();
    await ref.read(recentVisitProvider.notifier).clear();
    ref.invalidate(likedReviewsProvider);
    ref.invalidate(reviewLikeProvider);
  }

  Future<void> _resetLocalAccountData() async {
    await ref
        .read(bookmarkRestaurantsProvider.notifier)
        .resetWithInitialBookmarks(region: _initialBookmarkRegion);
    await ref.read(recentVisitProvider.notifier).clear();
    ref.invalidate(likedReviewsProvider);
    ref.invalidate(reviewLikeProvider);
  }

  Future<void> _clearDeletedAccountLocalData() async {
    await _clearLocalAccountData();

    try {
      await WebViewCookieManager().clearCookies();
    } catch (error) {
      debugPrint('WebView 쿠키 초기화 실패: $error');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> _mutateProfile(
    Future<UserProfile> Function() request,
    String successMessage, {
    Future<void> Function()? afterSuccess,
  }) async {
    _updateSettingsState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await request();
      if (afterSuccess != null) {
        await afterSuccess();
      }
      if (!mounted) return;
      _updateSettingsState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      _updateSettingsState(() {
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
      ref.read(appAuthProvider.notifier).signOut();
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

class _LoginProviderOption {
  final String id;
  final String label;
  final OAuthProvider provider;
  final Color color;
  final Color foreground;
  final String mark;

  const _LoginProviderOption({
    required this.id,
    required this.label,
    required this.provider,
    required this.color,
    required this.foreground,
    required this.mark,
  });
}
