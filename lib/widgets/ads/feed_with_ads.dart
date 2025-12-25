import 'package:flutter/material.dart';
import 'package:z/models/ad_model.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/widgets/ads/ad_widgets.dart';
import 'package:z/widgets/zap/card/zap_card.dart';

/// Feed item that can be either a Zap or an Ad
abstract class FeedItem {}

class ZapFeedItem extends FeedItem {
  final ZapModel zap;
  ZapFeedItem(this.zap);
}

class AdFeedItem extends FeedItem {
  final AdPlacement placement;
  AdFeedItem(this.placement);
}

/// Widget that builds feed items (zaps or ads)
class FeedItemWidget extends StatelessWidget {
  final FeedItem item;
  final VoidCallback? onZapTap;

  const FeedItemWidget({super.key, required this.item, this.onZapTap});

  @override
  Widget build(BuildContext context) {
    if (item is ZapFeedItem) {
      final zapItem = item as ZapFeedItem;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: ZapCard(zap: zapItem.zap),
      );
    } else if (item is AdFeedItem) {
      final adItem = item as AdFeedItem;
      return _buildAdWidget(adItem.placement);
    }
    return const SizedBox.shrink();
  }

  Widget _buildAdWidget(AdPlacement placement) {
    // Safety check: Zap feed should NEVER show fullscreen ads
    // Only native/smallPromo are allowed in feed
    if (placement.adType == AdType.video ||
        placement.adType == AdType.interstitial) {
      // This should never happen due to AdManager.getRandomInlineAdType()
      // But if it does, show empty container instead of fullscreen ad
      return const SizedBox(height: 0);
    }

    switch (placement.adType) {
      case AdType.native:
      case AdType.smallPromo:
        // CRITICAL: Use unique key based on placement index to prevent rebuild issues
        // This ensures the ad widget persists during scroll
        return NativeAdWidget(
          key: ValueKey('ad_${placement.index}'),
          adKey: 'ad_${placement.index}',
          customOptions: placement.customOptions,
          showSkipButton: true,
        );
      case AdType.video:
      case AdType.interstitial:
        // Should never reach here, but return empty if it does
        return const SizedBox(height: 0);
    }
  }
}

/// Helper to convert zap list with ad placements to feed items
List<FeedItem> createFeedItems(List<dynamic> items) {
  return items
      .map((item) {
        if (item is ZapModel) {
          return ZapFeedItem(item);
        } else if (item is AdPlacement) {
          return AdFeedItem(item);
        }
        return null;
      })
      .whereType<FeedItem>()
      .toList();
}
