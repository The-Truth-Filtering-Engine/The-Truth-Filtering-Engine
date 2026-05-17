import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'message_models.dart';

final friendMessagesProvider =
    StateNotifierProvider<FriendMessagesNotifier, FriendMessagesState>((ref) {
  return FriendMessagesNotifier();
});

class FriendMessagesState {
  const FriendMessagesState({
    this.friends = const [],
    this.inbox = const [],
  });

  final List<TruthFriend> friends;
  final List<FriendMessage> inbox;

  int get unreadCount => inbox.where((message) => !message.isRead).length;

  FriendMessagesState copyWith({
    List<TruthFriend>? friends,
    List<FriendMessage>? inbox,
  }) {
    return FriendMessagesState(
      friends: friends ?? this.friends,
      inbox: inbox ?? this.inbox,
    );
  }
}

class FriendMessagesNotifier extends StateNotifier<FriendMessagesState> {
  FriendMessagesNotifier() : super(const FriendMessagesState());

  TruthFriend addFriend({
    required String displayName,
    String? handle,
  }) {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', '이름이 비어 있습니다.');
    }

    final now = DateTime.now();
    final friend = TruthFriend(
      id: _newId('friend', now),
      displayName: trimmedName,
      handle: _normalizeOptional(handle),
      avatarText: _avatarText(trimmedName),
      addedAt: now,
    );

    state = state.copyWith(friends: [...state.friends, friend]);
    return friend;
  }

  void deleteFriend(String friendId) {
    state = state.copyWith(
      friends: state.friends.where((friend) => friend.id != friendId).toList(),
      inbox:
          state.inbox.where((message) => message.friendId != friendId).toList(),
    );
  }

  FriendMessage sendRestaurantCard(FriendMessageDraft draft) {
    final friend = _friendById(draft.friendId);
    final now = DateTime.now();
    final message = FriendMessage(
      id: _newId('message', now),
      friendId: friend.id,
      senderName: '나',
      type: draft.appointmentTime == null
          ? FriendMessageType.restaurantCard
          : FriendMessageType.appointment,
      restaurant: draft.restaurant,
      note: _normalizeOptional(draft.note),
      appointmentTime: draft.appointmentTime,
      sentAt: now,
      isRead: true,
    );

    state = state.copyWith(inbox: [message, ...state.inbox]);
    return message;
  }

  FriendMessage receiveRestaurantCard({
    required String friendId,
    required RestaurantCardPayload restaurant,
    String? note,
    DateTime? appointmentTime,
  }) {
    final friend = _friendById(friendId);
    final now = DateTime.now();
    final message = FriendMessage(
      id: _newId('message', now),
      friendId: friend.id,
      senderName: friend.displayName,
      type: appointmentTime == null
          ? FriendMessageType.restaurantCard
          : FriendMessageType.appointment,
      restaurant: restaurant,
      note: _normalizeOptional(note),
      appointmentTime: appointmentTime,
      sentAt: now,
    );

    state = state.copyWith(inbox: [message, ...state.inbox]);
    return message;
  }

  void markRead(String messageId) {
    state = state.copyWith(
      inbox: [
        for (final message in state.inbox)
          if (message.id == messageId)
            message.copyWith(isRead: true)
          else
            message,
      ],
    );
  }

  void deleteMessage(String messageId) {
    state = state.copyWith(
      inbox: state.inbox.where((message) => message.id != messageId).toList(),
    );
  }

  void setAppointmentTime(String messageId, DateTime appointmentTime) {
    state = state.copyWith(
      inbox: [
        for (final message in state.inbox)
          if (message.id == messageId)
            message.copyWith(
              type: FriendMessageType.appointment,
              appointmentTime: appointmentTime,
            )
          else
            message,
      ],
    );
  }

  TruthFriend _friendById(String friendId) {
    return state.friends.firstWhere(
      (friend) => friend.id == friendId,
      orElse: () => throw StateError('친구를 찾을 수 없습니다: $friendId'),
    );
  }

  String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _avatarText(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first);
  }

  String _newId(String prefix, DateTime now) {
    return '${prefix}_${now.microsecondsSinceEpoch}';
  }
}
