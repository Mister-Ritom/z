import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/info/zap/zap_detail_screen.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/services/ad_manager.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AppTrackingTransparency.requestTrackingAuthorization();
    });
    Future.microtask(() {
      ref.read(_forYouFeed.notifier).loadInitial();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(_forYouFeed.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(_forYouFeed.notifier).refreshFeed();
  }

  @override
  Widget build(BuildContext context) {
    final zaps = ref.watch(_forYouFeed);

    if (zaps.isEmpty) {
      return const Center(child: Text('No zaps yet'));
    }

    final feedItems = _adManager.injectAdsIntoZapBatch(zaps);
    final items = createFeedItems(feedItems);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == items.length) {
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
    );
  }
}
