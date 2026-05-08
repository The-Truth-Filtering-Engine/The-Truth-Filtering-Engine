import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/review_like_model.dart';
import '../../../data/repositories/review_like_repository.dart';
import '../../../data/sources/review_like_remote_source.dart';

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
  final String? _accessToken;

  ReviewLikeNotifier({
    required ReviewLikeRepository repo,
    required String reviewId,
    required int userId,
    String? accessToken,
  })  : _repo = repo,
        _reviewId = reviewId,
        _userId = userId,
        _accessToken = accessToken,
        super(ReviewLikeNotifierState(likeState: const ReviewLikeState())) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final likeState = await _repo.fetchState(
      reviewId: _reviewId,
      userId: _userId,
    );
    state = state.copyWith(isLoading: false, likeState: likeState);
  }

  Future<void> toggle(LikeType type) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);

    final likeState = await _repo.toggle(
      reviewId: _reviewId,
      userId: _userId,
      type: type,
      accessToken: _accessToken,
    );

    state = state.copyWith(isLoading: false, likeState: likeState);
  }
}

final reviewLikeProvider = StateNotifierProviderFamily<ReviewLikeNotifier,
    ReviewLikeNotifierState, ReviewLikeProviderKey>(
  (ref, key) => ReviewLikeNotifier(
    repo: ref.read(reviewLikeRepositoryProvider),
    reviewId: key.reviewId,
    userId: key.userId,
    accessToken: Supabase.instance.client.auth.currentSession?.accessToken,
  ),
);
