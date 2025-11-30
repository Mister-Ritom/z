import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/utils/logger.dart';
import '../models/zap_model.dart';
import '../services/content/recommendations/recommendation_service.dart';
import '../services/content/recommendations/recommendation_cache_service.dart';
import '../services/content/zaps/zap_service.dart';
import '../utils/constants.dart';
import 'recommendation_provider.dart';

final zapServiceProvider = Provider.family<ZapService, bool>((ref, isShort) {
  return ZapService(isShort: isShort);
});

class ForYouFeedState {
  const ForYouFeedState({
    this.zaps = const <ZapModel>[],
    this.isLoading = false,
    this.hasMore = true,
    this.nextLastZap,
    this.lastViewedZapId,
  });

  final List<ZapModel> zaps;
  final bool isLoading;
  final bool hasMore;
  final String? nextLastZap;
  final String?
  lastViewedZapId; // Last zap ID the user viewed (for resuming position)

  ForYouFeedState copyWith({
    List<ZapModel>? zaps,
    bool? isLoading,
    bool? hasMore,
    String? nextLastZap,
    String? lastViewedZapId,
  }) {
    return ForYouFeedState(
      zaps: zaps ?? this.zaps,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      nextLastZap: nextLastZap ?? this.nextLastZap,
      lastViewedZapId: lastViewedZapId ?? this.lastViewedZapId,
    );
  }
}

final forYouFeedProvider =
    StateNotifierProvider.family<ForYouFeedNotifier, ForYouFeedState, bool>((
      ref,
      isShort,
    ) {
      final recommendationService = ref.watch(recommendationServiceProvider);
      return ForYouFeedNotifier(recommendationService, isShort: isShort);
    });

class ForYouFeedNotifier extends StateNotifier<ForYouFeedState> {
  ForYouFeedNotifier(
    this._recommendationService, {
    required this.isShort,
    RecommendationCacheService? cacheService,
  }) : _cacheService = cacheService ?? RecommendationCacheService(),
       super(const ForYouFeedState());

  final RecommendationService _recommendationService;
  final RecommendationCacheService _cacheService;
  final bool isShort;

  Future<void> loadInitial({String? lastViewedZapId}) async {
    if (state.isLoading) return;

    // Try to load from cache first (for offline support)
    final cached = await _cacheService.loadRecommendations(isShort: isShort);
    if (cached != null && cached.zaps.isNotEmpty) {
      // Use cached lastViewedZapId if not provided
      final viewId = lastViewedZapId ?? cached.lastViewedZapId;

      state = state.copyWith(
        zaps: cached.zaps,
        hasMore: cached.hasMore,
        nextLastZap: cached.nextLastZap,
        lastViewedZapId: viewId,
        isLoading: false,
      );

      AppLogger.info(
        'ForYouFeedNotifier',
        'Loaded initial recommendations from cache',
        data: {
          'isShort': isShort,
          'count': cached.zaps.length,
          'hasMore': cached.hasMore,
        },
      );
    } else {
      state = state.copyWith(
        hasMore: true,
        nextLastZap: null,
        zaps: const <ZapModel>[],
        lastViewedZapId: lastViewedZapId,
      );
    }

    // Always try to fetch fresh data (will update cache on success)
    await _fetchRecommendations(reset: true);
  }

  Future<void> loadMore({String? lastViewedZapId}) async {
    if (state.isLoading || !state.hasMore) return;
    if (lastViewedZapId != null) {
      state = state.copyWith(lastViewedZapId: lastViewedZapId);
    }
    await _fetchRecommendations(reset: false);
  }

  /// Update the last viewed zap ID (called when user scrolls)
  void updateLastViewedZapId(String? zapId) {
    if (zapId != null && zapId != state.lastViewedZapId) {
      state = state.copyWith(lastViewedZapId: zapId);
      // Save to cache asynchronously (don't await to avoid blocking UI)
      _cacheService.updateLastViewedZapId(isShort: isShort, zapId: zapId);
    }
  }

  Future<void> refreshFeed() async {
    if (state.isLoading) return;
    state = state.copyWith(
      zaps: const <ZapModel>[],
      hasMore: true,
      nextLastZap: null,
    );
    await _fetchRecommendations(reset: true);
  }

  Future<void> _fetchRecommendations({required bool reset}) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);

    try {
      final result = await _recommendationService
          .getRecommendationsWithZaps(
            perPage: AppConstants.zapsPerPage,
            lastZap: reset ? null : state.nextLastZap,
            lastViewedZapId:
                reset
                    ? state.lastViewedZapId
                    : null, // Only send on initial load
            isShort: isShort,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'Recommendation fetch timed out',
                const Duration(seconds: 30),
              );
            },
          );

      final fetched = (result['zaps'] as List<ZapModel>?) ?? <ZapModel>[];
      final hasMore = result['hasMore'] as bool? ?? false;
      final nextLastZap = result['nextLastZap'] as String?;
      final source = result['source'] as String? ?? 'unknown';

      AppLogger.info(
        'ForYouFeedNotifier',
        'Received recommendations response',
        data: {
          'isShort': isShort,
          'fetched': fetched.length,
          'hasMore': hasMore,
          'source': source,
          'reset': reset,
        },
      );

      // If we got empty results on initial load, this might indicate an issue
      if (reset && fetched.isEmpty) {
        AppLogger.warn(
          'ForYouFeedNotifier',
          'Received empty results on initial load',
          data: {
            'isShort': isShort,
            'hasMore': hasMore,
            'source': source,
          },
        );
      }

      final updated = reset ? <ZapModel>[] : List<ZapModel>.from(state.zaps);
      for (final zap in fetched) {
        final index = updated.indexWhere((existing) => existing.id == zap.id);
        if (index >= 0) {
          updated[index] = zap;
        } else {
          updated.add(zap);
        }
      }

      // Update lastViewedZapId to the last zap in the list if we have zaps
      final newLastViewedZapId =
          updated.isNotEmpty ? updated.last.id : state.lastViewedZapId;

      // If we got empty results from cache source, clear local cache
      // This happens when server-side cache is corrupted or empty
      if (fetched.isEmpty && (source == 'cache' || source == 'cache_fallback')) {
        AppLogger.warn(
          'ForYouFeedNotifier',
          'Received empty results from cache source, clearing local cache',
          data: {
            'isShort': isShort,
            'source': source,
            'reset': reset,
          },
        );
        
        // Clear local cache since server cache is empty/corrupted
        await _cacheService.clearCache(isShort: isShort);
        
        // If this was initial load with empty results, set hasMore to false
        // This will prevent infinite loading attempts
        if (reset && updated.isEmpty) {
          state = state.copyWith(
            zaps: updated,
            hasMore: false, // No more content available
            nextLastZap: null,
            isLoading: false,
            lastViewedZapId: newLastViewedZapId,
          );
          
          AppLogger.warn(
            'ForYouFeedNotifier',
            'Empty cache results on initial load - no content available',
            data: {'isShort': isShort, 'source': source},
          );
          return; // Don't save empty cache
        }
      }

      // Always update state, even if fetched is empty (to show "No zaps yet" properly)
      state = state.copyWith(
        zaps: updated,
        hasMore: hasMore,
        nextLastZap: nextLastZap,
        isLoading: false,
        lastViewedZapId: newLastViewedZapId,
      );

      // Only save to cache if we have zaps (don't save empty results)
      if (updated.isNotEmpty) {
        await _cacheService.saveRecommendations(
          isShort: isShort,
          zaps: updated,
          hasMore: hasMore,
          nextLastZap: nextLastZap,
          lastViewedZapId: newLastViewedZapId,
        );
      } else if (reset) {
        // If we got empty results on initial load from non-cache source, clear cache
        // This ensures we don't keep stale empty cache
        AppLogger.info(
          'ForYouFeedNotifier',
          'Clearing cache after empty initial load',
          data: {'isShort': isShort, 'source': source},
        );
        await _cacheService.clearCache(isShort: isShort);
      }

      AppLogger.info(
        'ForYouFeedNotifier',
        'Loaded recommendations',
        data: {
          'isShort': isShort,
          'fetched': fetched.length,
          'total': state.zaps.length,
          'hasMore': hasMore,
          'source': source,
        },
      );
    } catch (e, st) {
      AppLogger.error(
        'ForYouFeedNotifier',
        'Failed to load recommendations',
        error: e,
        stackTrace: st,
        data: {'isShort': isShort, 'reset': reset},
      );

      // Always try to load from cache as fallback when fetch fails
      // This ensures users can still see content even if server is down
      final cached = await _cacheService.loadRecommendations(isShort: isShort);

      if (cached != null && cached.zaps.isNotEmpty) {
        // Merge cached zaps with existing state (if any)
        final existingZapIds = state.zaps.map((z) => z.id).toSet();
        final newZaps =
            cached.zaps.where((z) => !existingZapIds.contains(z.id)).toList();
        final mergedZaps = reset ? cached.zaps : [...state.zaps, ...newZaps];

        state = state.copyWith(
          zaps: mergedZaps,
          hasMore: cached.hasMore || state.hasMore, // Keep hasMore if we had it
          nextLastZap: cached.nextLastZap ?? state.nextLastZap,
          lastViewedZapId: cached.lastViewedZapId ?? state.lastViewedZapId,
          isLoading: false,
        );

        AppLogger.info(
          'ForYouFeedNotifier',
          'Using cached recommendations after fetch failure',
          data: {
            'isShort': isShort,
            'cachedCount': cached.zaps.length,
            'mergedCount': mergedZaps.length,
            'error': e.toString(),
          },
        );
        return;
      }

      // If no cache available and we have no zaps, show error state
      if (state.zaps.isEmpty) {
        state = state.copyWith(isLoading: false, hasMore: false);
      } else {
        // If we have some zaps, just stop loading (keep what we have)
        state = state.copyWith(isLoading: false);
      }
    }
  }
}

// Following feed provider (isShort not needed here unless you want to separate short/fulls)
final followingFeedProvider = StreamProvider.family<List<ZapModel>, String>((
  ref,
  userId,
) {
  final zapService = ref.watch(zapServiceProvider(false)); // full zaps
  return zapService.getFollowingFeed(userId);
});

final userZapsProvider = StreamProvider.family<List<ZapModel>, String>((
  ref,
  userId,
) {
  final zapService = ref.watch(zapServiceProvider(false));
  return zapService.getUserZaps(userId);
});

final searchZapsProvider = FutureProvider.family<List<ZapModel>, String>((
  ref,
  query,
) async {
  final zapService = ref.watch(zapServiceProvider(false));
  return await zapService.searchZaps(query);
});

final zapRepliesProvider = StreamProvider.family<List<ZapModel>, String>((
  ref,
  zapId,
) {
  final zapService = ref.watch(zapServiceProvider(false));
  return zapService.getZapReplies(zapId);
});

final userRepliesProvider = StreamProvider.family<List<ZapModel>, String>((
  ref,
  userId,
) {
  final zapService = ref.watch(zapServiceProvider(false));
  return zapService.getUserReplies(userId);
});

final userLikedZapsProvider = StreamProvider.family<List<ZapModel>, String>((
  ref,
  userId,
) {
  final zapService = ref.watch(zapServiceProvider(false));
  return zapService.getUserLikedZaps(userId);
});

final userRezapedZapsProvider = StreamProvider.family<List<ZapModel>, String>((
  ref,
  userId,
) {
  final zapService = ref.watch(zapServiceProvider(false));
  return zapService.getUserRezapedZaps(userId);
});

final userBookmarkedZapsProvider =
    StreamProvider.family<List<ZapModel>, String>((ref, userId) {
      final zapService = ref.watch(zapServiceProvider(false));
      return zapService.getUserBookmarkedZaps(userId);
    });

final zapProvider = FutureProvider.family<ZapModel?, String>((ref, zapId) {
  final zapService = ref.watch(zapServiceProvider(false));
  return zapService.getZapById(zapId);
});

final isBookmarkedProvider =
    FutureProvider.family<bool, ({String zapId, String userId})>((
      ref,
      args,
    ) async {
      final zapService = ref.watch(zapServiceProvider(false));
      try {
        return await zapService.isBookmarked(args.zapId, args.userId);
      } catch (e, st) {
        AppLogger.error(
          'ZapProvider',
          'Error checking bookmark',
          error: e,
          stackTrace: st,
          data: {'zapId': args.zapId, 'userId': args.userId},
        );
        return false;
      }
    });
