import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../data/models/review_like_model.dart';
import '../../../data/repositories/review_like_repository.dart';
import '../../../data/sources/review_like_remote_source.dart';

// ── 의존성 ────────────────────────────────────
final reviewLikeRepositoryProvider = Provider<ReviewLikeRepository>(
  (ref) => ReviewLikeRepository(
    ReviewLikeRemoteSource(Supabase.instance.client),
  ),
);

// ── 상태 ──────────────────────────────────────
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

// ── Notifier ──────────────────────────────────
class ReviewLikeNotifier extends StateNotifier<ReviewLikeNotifierState> {
  final ReviewLikeRepository _repo;
  final String _reviewId;
  final String _userEmail;

  ReviewLikeNotifier({
    required ReviewLikeRepository repo,
    required String reviewId,
    required String userEmail,
  })  : _repo = repo,
        _reviewId = reviewId,
        _userEmail = userEmail,
        super(ReviewLikeNotifierState(likeState: const ReviewLikeState())) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final likeState = await _repo.fetchState(
      reviewId: _reviewId,
      userEmail: _userEmail,
    );
    state = state.copyWith(isLoading: false, likeState: likeState);
  }

  Future<void> toggle(LikeType type) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);

    final likeState = await _repo.toggle(
      reviewId: _reviewId,
      userEmail: _userEmail,
      type: type,
    );

    state = state.copyWith(isLoading: false, likeState: likeState);
  }
}

// reviewId 별로 provider 생성
final reviewLikeProvider = StateNotifierProviderFamily<
    ReviewLikeNotifier, ReviewLikeNotifierState, String>(
  (ref, reviewId) {
    final email = ref.watch(currentUserEmailProvider) ?? '';
    return ReviewLikeNotifier(
      repo: ref.read(reviewLikeRepositoryProvider),
      reviewId: reviewId,
      userEmail: email,
    );
  },
);