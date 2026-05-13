import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/test_admin_auth_config.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../data/models/review_like_model.dart';
import '../../../../data/repositories/review_like_repository.dart';
import '../../../../data/sources/review_like_remote_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final reviewLikeRepositoryProvider = Provider<ReviewLikeRepository>(
  (ref) => ReviewLikeRepository(
    ReviewLikeRemoteSource(Supabase.instance.client),
  ),
);

class ReviewLikeNotifierState {
  final bool isLoading;
  final ReviewLikeState likeState;

  const ReviewLikeNotifierState({
    this.isLoading = false,
    required this.likeState,
  });

  ReviewLikeNotifierState copyWith({
    bool? isLoading,
    ReviewLikeState? likeState,
  }) =>
      ReviewLikeNotifierState(
        isLoading: isLoading ?? this.isLoading,
        likeState: likeState ?? this.likeState,
      );
}

class ReviewLikeProviderKey {
  final String reviewId;
  final int userId;

  const ReviewLikeProviderKey({
    required this.reviewId,
    required this.userId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewLikeProviderKey &&
          runtimeType == other.runtimeType &&
          reviewId == other.reviewId &&
          userId == other.userId;

  @override
  int get hashCode => Object.hash(reviewId, userId);
}

class ReviewLikeNotifier extends StateNotifier<ReviewLikeNotifierState> {
  final ReviewLikeRepository _repo;
  final String _reviewId;
  final int _userId;
  final Map<String, String> _authHeaders;
  bool _hasUserToggled = false;
  bool _isToggling = false;

  ReviewLikeNotifier({
    required ReviewLikeRepository repo,
    required String reviewId,
    required int userId,
    required Map<String, String> authHeaders,
  })  : _repo = repo,
        _reviewId = reviewId,
        _userId = userId,
        _authHeaders = authHeaders,
        super(ReviewLikeNotifierState(likeState: const ReviewLikeState())) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      final likeState = await _repo.fetchState(
        reviewId: _reviewId,
        userId: _userId,
        authHeaders: _authHeaders,
      );
      if (_hasUserToggled) {
        state = state.copyWith(isLoading: false);
        return;
      }
      state = state.copyWith(isLoading: false, likeState: likeState);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<ReviewLikeState> toggleHeart() async {
    if (_isToggling) return state.likeState;

    _hasUserToggled = true;
    _isToggling = true;

    final previous = state.likeState;
    final nextCount = previous.likeCount + (previous.isLiked ? -1 : 1);
    final optimistic = previous.copyWith(
      isLiked: !previous.isLiked,
      likeCount: nextCount < 0 ? 0 : nextCount,
    );

    state = state.copyWith(isLoading: true, likeState: optimistic);

    try {
      final likeState = await _repo.toggleHeart(
        reviewId: _reviewId,
        userId: _userId,
        authHeaders: _authHeaders,
      );

      state = state.copyWith(isLoading: false, likeState: likeState);
      return likeState;
    } catch (_) {
      state = state.copyWith(isLoading: false, likeState: previous);
      return previous;
    } finally {
      _isToggling = false;
    }
  }

  void markUnliked() {
    _hasUserToggled = true;

    final previous = state.likeState;
    final nextCount = previous.isLiked && previous.likeCount > 0
        ? previous.likeCount - 1
        : previous.likeCount;

    state = state.copyWith(
      isLoading: false,
      likeState: previous.copyWith(
        isLiked: false,
        likeCount: nextCount,
      ),
    );
  }
}

final reviewLikeProvider = StateNotifierProviderFamily<ReviewLikeNotifier,
    ReviewLikeNotifierState, ReviewLikeProviderKey>(
  (ref, key) {
    final authState = ref.watch(appAuthProvider);
    return ReviewLikeNotifier(
      repo: ref.read(reviewLikeRepositoryProvider),
      reviewId: key.reviewId,
      userId: key.userId,
      authHeaders: TestAdminAuthConfig.headers(isAdmin: authState.isAdmin),
    );
  },
);
