import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/info/zap/zap_detail_screen.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/services/ad_manager.dart';
import 'package:z/services/recommendation_cache_service.dart';
import 'package:z/widgets/ads/feed_with_ads.dart';

class ForYouTab extends ConsumerStatefulWidget {
  const ForYouTab({super.key});

  @override
  ConsumerState<ForYouTab> createState() => _ForYouTabState();
}

class _ForYouTabState extends ConsumerState<ForYouTab> {
  final ScrollController _scrollController = ScrollController();
  final AdManager _adManager = AdManager();
  late final _forYouFeed = forYouFeedProvider(false);
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AppTrackingTransparency.requestTrackingAuthorization();
      if (!mounted) return;
      _hasInitialized = true;
      
      // Load lastViewedZapId from cache
      final cacheService = RecommendationCacheService();
      final lastViewedZapId = await cacheService.getLastViewedZapId(isShort: false);
      
      await ref.read(_forYouFeed.notifier).loadInitial(
        lastViewedZapId: lastViewedZapId,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(_forYouFeed.notifier).refreshFeed();
  }

  bool _handleScrollNotification(
    ScrollNotification notification,
    ForYouFeedState feedState,
  ) {
    if (!_hasInitialized || !mounted) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    
    // Track last viewed zap ID based on scroll position
    if (notification is ScrollUpdateNotification) {
      final scrollPosition = notification.metrics.pixels;
      final viewportHeight = notification.metrics.viewportDimension;
      final viewportStart = scrollPosition;
      final viewportEnd = scrollPosition + viewportHeight;
      
      // Find the zap that's most visible in the viewport
      int? mostVisibleIndex;
      double maxVisibleArea = 0;
      
      for (int i = 0; i < feedState.zaps.length; i++) {
        // Estimate item position (assuming ~400px per item)
        final itemStart = i * 400.0;
        final itemEnd = itemStart + 400.0;
        
        // Calculate visible area (intersection of viewport and item)
        final visibleStart = itemStart < viewportEnd ? itemStart : viewportEnd;
        final visibleEnd = itemEnd > viewportStart ? itemEnd : viewportStart;
        final visibleArea = (visibleEnd - visibleStart).clamp(0.0, 400.0);
        
        if (visibleArea > maxVisibleArea) {
          maxVisibleArea = visibleArea;
          mostVisibleIndex = i;
        }
      }
      
      if (mostVisibleIndex != null && mostVisibleIndex < feedState.zaps.length) {
        final visibleZapId = feedState.zaps[mostVisibleIndex].id;
        ref.read(_forYouFeed.notifier).updateLastViewedZapId(visibleZapId);
      }
    }
    
    if (feedState.isLoading || !feedState.hasMore) return false;
    if (notification is! ScrollUpdateNotification ||
        notification.dragDetails == null) {
      return false;
    }

    const threshold = 600.0;
    if (notification.metrics.extentAfter <= threshold) {
      ref.read(_forYouFeed.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(_forYouFeed);
    final zaps = feedState.zaps;
    final hasMore = feedState.hasMore;
    final isLoading = feedState.isLoading;

    if (zaps.isEmpty) {
      if (isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(child: Text('No zaps yet'));
    }

    final feedItems = _adManager.injectAdsIntoZapBatch(zaps);
    final items = createFeedItems(feedItems);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification:
            (notification) =>
                _handleScrollNotification(notification, feedState),
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == items.length) {
              if (hasMore || isLoading) {
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return const SizedBox(
                height: 160,
                child: Center(child: Text('You reached the end')),
              );
            }

            final item = items[index];
            final key =
                item is ZapFeedItem
                    ? ValueKey('zap_${item.zap.id}')
                    : item is AdFeedItem
                    ? ValueKey('ad_${item.placement.index}')
                    : ValueKey('item_$index');

            return FeedItemWidget(
              key: key,
              item: item,
              onZapTap: () {
                if (item is ZapFeedItem) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ZapDetailScreen(zapId: item.zap.id),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}
