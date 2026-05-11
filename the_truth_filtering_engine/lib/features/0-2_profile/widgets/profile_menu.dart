import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/theme/app_theme.dart';

/// 프로필 아이콘/이메일 탭 → 로그아웃 팝업 메뉴
class ProfileMenuButton extends ConsumerWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(appAuthProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final email = authState.email ?? '';

    return GestureDetector(
      onTapDown: (details) => _showMenu(context, ref, details.globalPosition),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary50,
            child: Text(
              email.isNotEmpty ? email[0].toUpperCase() : '?',
              style: AppText.subtitle().copyWith(color: AppColors.primary500),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  email,
                  style: AppText.subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile != null)
                  Text(
                    profile.isPremium ? '프리미엄' : '일반 회원',
                    style: AppText.caption()
                        .copyWith(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more, size: 18, color: AppColors.textHint),
        ],
      ),
    );
  }

  Future<void> _showMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final result = await showMenu<_MenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      items: [
        PopupMenuItem(
          value: _MenuAction.logout,
          child: Row(
            children: [
              const Icon(Icons.logout_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Text('로그아웃',
                  style:
                      AppText.body().copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );

    if (result == _MenuAction.logout && context.mounted) {
      _confirmLogout(context, ref);
    }
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('로그아웃', style: AppText.title()),
        content: Text(
          '정말 로그아웃 하시겠어요?',
          style: AppText.body().copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소',
                style: AppText.body().copyWith(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
              ref.read(appAuthProvider.notifier).signOut();
            },
            child: Text('로그아웃',
                style: AppText.body().copyWith(color: AppColors.danger400)),
          ),
        ],
      ),
    );
  }
}

enum _MenuAction { logout }
