import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/zap_service.dart';
import '../models/zap_model.dart';

final zapServiceProvider = Provider.family<ZapService, bool>((ref, isShort) {
  return ZapService(isShort: isShort);
});

final forYouFeedProvider =
    StateNotifierProvider.family<ForYouFeedNotifier, List<ZapModel>, bool>((
      ref,
      isShort,
    ) {
      final zapService = ref.watch(zapServiceProvider(isShort));
      return ForYouFeedNotifier(zapService);
    });

class ForYouFeedNotifier extends StateNotifier<List<ZapModel>> {
  final ZapService _zapService;
  bool _isLoading = false;
  bool _hasMore = true;
  final List<StreamSubscription<List<ZapModel>>> _pageSubs = [];

  ForYouFeedNotifier(this._zapService) : super([]) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    if (_isLoading) return;
    _isLoading = true;

    final firstPageStream = _zapService.getForYouFeed();
    _subscribeToPage(firstPageStream);

    _isLoading = false;
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore || state.isEmpty) return;
    _isLoading = true;

    final lastDoc = state.last.docSnapshot;
    final nextPageStream = _zapService.getForYouFeed(lastDoc: lastDoc);
    _subscribeToPage(nextPageStream);

    _isLoading = false;
  }

  Future<void> refreshFeed() async {
    for (var sub in _pageSubs) {
      await sub.cancel();
    }
    _pageSubs.clear();
    state = [];
    _hasMore = true;
    _isLoading = false;

    await loadInitial();
  }

  void _subscribeToPage(Stream<List<ZapModel>> pageStream) {
    final sub = pageStream.listen((zaps) {
      if (zaps.isEmpty) {
        _hasMore = false;
      } else {
        final currentMap = {for (var t in state) t.id: t};
        for (var zap in zaps) {
          currentMap[zap.id] = zap;
        }
        state = currentMap.values.toList();
      }
    });
    _pageSubs.add(sub);
  }

  @override
  void dispose() {
    for (var sub in _pageSubs) {
      sub.cancel();
    }
    super.dispose();
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
        log("Error checking bookmark", error: e, stackTrace: st);
        return false;
      }
    });
