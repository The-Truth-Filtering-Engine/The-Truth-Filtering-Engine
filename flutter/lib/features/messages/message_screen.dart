import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_tokens.dart';
import 'message_models.dart';
import 'message_provider.dart';

class MessageEntryButton extends ConsumerWidget {
  const MessageEntryButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount =
        ref.watch(friendMessagesProvider.select((state) => state.unreadCount));

    return IconButton(
      onPressed: onPressed,
      tooltip: '메시지',
      icon: Badge.count(
        count: unreadCount,
        isLabelVisible: unreadCount > 0,
        child: const Icon(Icons.mail_outline_rounded),
      ),
    );
  }
}

class FriendMessagesScreen extends ConsumerWidget {
  const FriendMessagesScreen({
    super.key,
    this.onViewRestaurant,
  });

  final ValueChanged<RestaurantCardPayload>? onViewRestaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(friendMessagesProvider);
    final notifier = ref.read(friendMessagesProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('메시지', style: AppText.title()),
        actions: [
          IconButton(
            onPressed: () => _showAddFriendDialog(context, notifier),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: '친구 추가',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x4,
          AppSpacing.x4,
          AppSpacing.x8,
        ),
        children: [
          _MessageSectionHeader(
            icon: Icons.people_alt_outlined,
            label: '친구 목록',
            trailing: '${state.friends.length}명',
          ),
          const SizedBox(height: AppSpacing.x2),
          if (state.friends.isEmpty)
            const _EmptyMessagePanel(label: '아직 추가한 친구가 없습니다')
          else
            ...state.friends.map(
              (friend) => _FriendTile(
                friend: friend,
                onDelete: () => notifier.deleteFriend(friend.id),
              ),
            ),
          const SizedBox(height: AppSpacing.x6),
          _MessageSectionHeader(
            icon: Icons.mark_email_unread_outlined,
            label: '받은 메시지',
            trailing: '${state.unreadCount}개 안 읽음',
          ),
          const SizedBox(height: AppSpacing.x2),
          if (state.inbox.isEmpty)
            const _EmptyMessagePanel(label: '받은 식당 카드가 없습니다')
          else
            ...state.inbox.map(
              (message) => _MessageTile(
                message: message,
                onTap: () async {
                  notifier.markRead(message.id);
                  await showMessageLetterDialog(
                    context,
                    message.copyWith(isRead: true),
                    onViewRestaurant: onViewRestaurant == null
                        ? null
                        : () => onViewRestaurant!(message.restaurant),
                  );
                },
                onDelete: () => notifier.deleteMessage(message.id),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddFriendDialog(
    BuildContext context,
    FriendMessagesNotifier notifier,
  ) async {
    final nameController = TextEditingController();
    final handleController = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('친구 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '친구 이름',
                  hintText: '예: 민지',
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              TextField(
                controller: handleController,
                decoration: const InputDecoration(
                  labelText: '아이디',
                  hintText: '선택 사항',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('추가'),
            ),
          ],
        );
      },
    );

    if (added != true) return;
    notifier.addFriend(
      displayName: nameController.text,
      handle: handleController.text,
    );
  }
}

Future<void> showMessageLetterDialog(
  BuildContext context,
  FriendMessage message, {
  VoidCallback? onViewRestaurant,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.x5),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.x5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.5),
              boxShadow: AppShadows.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary50,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.markunread_mailbox_rounded,
                        color: AppColors.primary700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Text(
                        '${message.senderName}님의 식당 카드',
                        style: AppText.title(),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: '닫기',
                    ),
                  ],
                ),
                if (message.note != null) ...[
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    message.note!,
                    style: AppText.body().copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.x4),
                _LetterRestaurantCard(restaurant: message.restaurant),
                if (message.appointmentTime != null) ...[
                  const SizedBox(height: AppSpacing.x3),
                  _AppointmentPanel(message: message),
                ],
                const SizedBox(height: AppSpacing.x5),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('닫기'),
                      ),
                    ),
                    if (onViewRestaurant != null) ...[
                      const SizedBox(width: AppSpacing.x2),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            onViewRestaurant();
                          },
                          icon: const Icon(Icons.map_rounded, size: 18),
                          label: const Text('지도 보기'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _MessageSectionHeader extends StatelessWidget {
  const _MessageSectionHeader({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary500),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(label, style: AppText.subtitle()),
        ),
        Text(
          trailing,
          style: AppText.caption().copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.onDelete,
  });

  final TruthFriend friend;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.x2),
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary50,
            foregroundColor: AppColors.primary700,
            child: Text(friend.avatarText ?? '?'),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.displayName, style: AppText.subtitle()),
                if (friend.handle != null)
                  Text(
                    friend.handle!,
                    style: AppText.caption().copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.textHint,
            tooltip: '친구 삭제',
          ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.onTap,
    required this.onDelete,
  });

  final FriendMessage message;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.x2),
          padding: const EdgeInsets.all(AppSpacing.x3),
          decoration: _panelDecoration(),
          child: Row(
            children: [
              Icon(
                message.isRead
                    ? Icons.drafts_outlined
                    : Icons.mark_email_unread_rounded,
                color:
                    message.isRead ? AppColors.textHint : AppColors.primary500,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.subtitle(),
                    ),
                    Text(
                      '${message.senderName} · ${message.restaurant.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption().copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.close_rounded),
                color: AppColors.textHint,
                tooltip: '메시지 삭제',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LetterRestaurantCard extends StatelessWidget {
  const _LetterRestaurantCard({required this.restaurant});

  final RestaurantCardPayload restaurant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(),
                ),
              ),
              _MiniPill(label: restaurant.category),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            restaurant.address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body().copyWith(color: AppColors.textSecondary),
          ),
          if (restaurant.reviewSummary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2),
            Text(
              restaurant.reviewSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption().copyWith(color: AppColors.textHint),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppointmentPanel extends StatelessWidget {
  const _AppointmentPanel({required this.message});

  final FriendMessage message;

  @override
  Widget build(BuildContext context) {
    final appointment = message.appointmentTime!;
    final reminder = message.reminderTime!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: AppColors.primary700,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              '약속 ${_formatDateTime(appointment)} · 알림 ${_formatTime(reminder)}',
              style: AppText.caption().copyWith(
                color: AppColors.primary700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppText.caption().copyWith(
          color: AppColors.primary700,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyMessagePanel extends StatelessWidget {
  const _EmptyMessagePanel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: _panelDecoration(),
      child: Text(
        label,
        style: AppText.body().copyWith(color: AppColors.textHint),
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    border: Border.all(color: AppColors.border, width: 0.5),
  );
}

String _formatDateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month.$day ${_formatTime(value)}';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
