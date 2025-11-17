import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:z/models/ad_model.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/utils/constants.dart';

/// Central ad management system for Z app
/// Handles ad loading, caching, preloading, and insertion logic
class AdManager {
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  final Random _random = Random();
  final Map<AdType, Queue<AdData>> _adCache = {};
  final Map<AdType, List<Completer<Ad?>>> _loadingAds = {};

  // Global lock to prevent multiple fullscreen ads from showing at once
  static bool _isFullScreenAdShowing = false;

  /// Check if a fullscreen ad is currently showing
  static bool get isFullScreenAdShowing => _isFullScreenAdShowing;

  /// Set the fullscreen ad lock
  static void setFullScreenAdShowing(bool value) {
    _isFullScreenAdShowing = value;
  }

  /// Initialize ad manager and preload ads
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    await _preloadAds();
  }

  /// Preload ads for better performance
  Future<void> _preloadAds() async {
    for (int i = 0; i < AppConstants.maxPreloadedAds; i++) {
      _loadAd(AdType.native);
      _loadAd(AdType.video);
    }
  }

  /// Load a single ad of the specified type
  Future<Ad?> _loadAd(AdType adType) async {
    final adUnitId = _getAdUnitId(adType);
    if (adUnitId == null) return null;

    final completer = Completer<Ad?>();
    final key = adType;
    if (!_loadingAds.containsKey(key)) {
      _loadingAds[key] = [];
    }
    _loadingAds[key]!.add(completer);

    // If already loading this type, wait for existing load
    if (_loadingAds[key]!.length > 1) {
      return completer.future;
    }

    try {
      Ad? ad;
      switch (adType) {
        case AdType.native:
          ad = await _loadNativeAd(adUnitId);
          break;
        case AdType.video:
          // Video ads now use InterstitialAd (RewardedAd removed)
          ad = await _loadVideoAd(adUnitId);
          break;
        case AdType.interstitial:
          ad = await _loadInterstitialAd(adUnitId);
          break;
        case AdType.smallPromo:
          ad = await _loadNativeAd(adUnitId);
          break;
      }

      // Complete all waiting completers
      for (var c in _loadingAds[key]!) {
        if (!c.isCompleted) {
          c.complete(ad);
        }
      }
      _loadingAds[key]!.clear();

      if (ad != null) {
        _cacheAd(adType, ad);
      }

      return ad;
    } catch (e) {
      // Complete with null on error
      for (var c in _loadingAds[key]!) {
        if (!c.isCompleted) {
          c.complete(null);
        }
      }
      _loadingAds[key]!.clear();
      return null;
    }
  }

  /// Load native ad
  Future<NativeAd?> _loadNativeAd(String adUnitId) async {
    final completer = Completer<NativeAd?>();

    late NativeAd ad;
    ad = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'multiNativeAd',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!completer.isCompleted) completer.complete(ad);
          developer.log("Ad  load");
        },
        onAdFailedToLoad: (failedAd, error) {
          if (!completer.isCompleted) completer.complete(null);
          developer.log("Ad failed to load", error: error);
          failedAd.dispose();
        },
      ),
    );

    ad.load();

    return completer.future.timeout(
      AppConstants.adPreloadTimeout,
      onTimeout: () {
        if (!completer.isCompleted) completer.complete(null);
        return null;
      },
    );
  }

  /// Load video ad (InterstitialAd - RewardedAd removed)
  Future<InterstitialAd?> _loadVideoAd(String adUnitId) async {
    final completer = Completer<InterstitialAd?>();

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) completer.complete(null);
          developer.log("Ad failed to load", error: error);
        },
      ),
    );

    return completer.future.timeout(
      AppConstants.adPreloadTimeout,
      onTimeout: () {
        if (!completer.isCompleted) completer.complete(null);
        return null;
      },
    );
  }

  /// Load interstitial ad
  Future<InterstitialAd?> _loadInterstitialAd(String adUnitId) async {
    final completer = Completer<InterstitialAd?>();

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) completer.complete(null);
          developer.log("Ad failed to load", error: error);
        },
      ),
    );

    return completer.future.timeout(
      AppConstants.adPreloadTimeout,
      onTimeout: () {
        if (!completer.isCompleted) completer.complete(null);
        return null;
      },
    );
  }

  /// Cache an ad for later use
  void _cacheAd(AdType adType, Ad ad) {
    if (!_adCache.containsKey(adType)) {
      _adCache[adType] = Queue<AdData>();
    }

    // Limit cache size - dispose old ads
    if (_adCache[adType]!.length >= AppConstants.maxPreloadedAds) {
      _adCache[adType]!.removeFirst();
      // Note: In current implementation, we don't store Ad objects in cache
      // They're disposed immediately after use
    }

    // Note: In a real implementation, you'd store the Ad object
    // For now, we'll reload when needed and dispose immediately after use
    _adCache[adType]!.add(
      AdData(
        adUnitId: _getAdUnitId(adType) ?? '',
        adType: adType,
        isLoaded: true,
        loadedAt: DateTime.now(),
      ),
    );
  }

  /// Get ad unit ID for platform and ad type
  String? _getAdUnitId(AdType adType) {
    if (Platform.isIOS) {
      switch (adType) {
        case AdType.native:
        case AdType.smallPromo:
          return AppConstants.nativeAdUnitIdIos;
        case AdType.video:
          return AppConstants.interstitialAdUnitIdIos;
        case AdType.interstitial:
          return AppConstants.interstitialAdUnitIdIos;
      }
    } else if (Platform.isAndroid) {
      switch (adType) {
        case AdType.native:
        case AdType.smallPromo:
          return AppConstants.nativeAdUnitIdAndroid;
        case AdType.video:
          return AppConstants.interstitialAdUnitIdAndroid;
        case AdType.interstitial:
          return AppConstants.interstitialAdUnitIdAndroid;
      }
    }
    return null;
  }

  /// Get a random ad type based on probabilities
  AdType getRandomAdType() {
    final rand = _random.nextDouble();

    if (rand < AppConstants.interstitialAdChance) {
      return AdType.video;
    } else if (rand <
        AppConstants.interstitialAdChance + AppConstants.interstitialAdChance) {
      return AdType.interstitial;
    } else {
      return AdType.native;
    }
  }

  /// Get a random INLINE ad type (for zap feed - no fullscreen ads)
  /// Only returns native or inline video ads
  AdType getRandomInlineAdType() {
    final rand = _random.nextDouble();

    // For inline ads, only use native or small promo
    // Video ads in feed should be inline (not fullscreen)
    if (rand < 0.3) {
      return AdType.smallPromo;
    } else {
      return AdType.native;
    }
  }

  /// Check if should show ad in story navigation
  bool shouldShowStoryAd() {
    return _random.nextDouble() < AppConstants.storyAdChance;
  }

  /// Check if should show ad in shorts feed
  bool shouldShowShortsAd() {
    return _random.nextDouble() < AppConstants.shortsAdChance;
  }

  /// Inject ads into zap feed batch
  /// Returns list with ads inserted at appropriate positions
  List<dynamic> injectAdsIntoZapBatch(List<ZapModel> zaps) {
    if (zaps.isEmpty) return zaps;

    // Check if we should insert ads for this batch
    if (_random.nextDouble() >= AppConstants.zapPageAdChance) {
      return zaps;
    }

    final result = <dynamic>[];
    final adCount =
        AppConstants.zapAdMin +
        _random.nextInt(AppConstants.zapAdMax - AppConstants.zapAdMin + 1);

    // Calculate positions for ads
    final positions = _calculateAdPositions(zaps.length, adCount);

    int zapIndex = 0;
    for (int i = 0; i < zaps.length + positions.length; i++) {
      if (positions.contains(i)) {
        // Insert ad - ONLY inline ads (native/smallPromo) for zap feed
        // NEVER rewarded/interstitial/fullscreen video in feed
        final adType = getRandomInlineAdType();
        result.add(
          AdPlacement(
            index: i,
            adType: adType,
            customOptions: _getCustomOptionsForAdType(adType),
          ),
        );
      } else {
        // Insert zap
        if (zapIndex < zaps.length) {
          result.add(zaps[zapIndex]);
          zapIndex++;
        }
      }
    }

    return result;
  }

  /// Calculate valid positions for ads ensuring minimum gap
  List<int> _calculateAdPositions(int contentCount, int adCount) {
    if (contentCount < AppConstants.minContentGap + 1) {
      return []; // Not enough content for ads
    }

    final positions = <int>[];
    int lastAdPosition = -AppConstants.minContentGap - 1;

    for (int i = 0; i < adCount; i++) {
      // Find next valid position
      int nextPosition = lastAdPosition + AppConstants.minContentGap + 1;

      // Ensure we don't go beyond content
      final maxPosition = contentCount + positions.length - 1;
      if (nextPosition > maxPosition) {
        break; // Can't fit more ads
      }

      // Add some randomness but maintain minimum gap
      final gap = (maxPosition - nextPosition).clamp(
        0,
        AppConstants.minContentGap,
      );
      final randomOffset = gap > 0 ? _random.nextInt(gap) : 0;

      nextPosition += randomOffset;

      positions.add(nextPosition);
      lastAdPosition = nextPosition;
    }

    return positions;
  }

  /// Get custom options for ad type
  Map<String, dynamic> _getCustomOptionsForAdType(AdType adType) {
    switch (adType) {
      case AdType.native:
        return {
          'adType': _random.nextBool() ? 'small' : 'large',
          'adLayout': _random.nextBool() ? 'horizontal' : 'vertical',
          'bgColor': 'F0F0F0',
          'textColor': '000000',
          'cornerRadius': 12.0,
        };
      case AdType.smallPromo:
        return {
          'adType': 'small',
          'adLayout': 'horizontal',
          'bgColor': 'FFFFFF',
          'textColor': '000000',
          'cornerRadius': 8.0,
        };
      case AdType.video:
      case AdType.interstitial:
        return {};
    }
  }

  /// Get native ad widget options
  Map<String, dynamic> getNativeAdOptions({
    String size = 'small',
    String layout = 'horizontal',
  }) {
    return {
      'adType': size,
      'adLayout': layout,
      'bgColor': 'F0F0F0',
      'textColor': '000000',
      'cornerRadius': 12.0,
    };
  }

  /// Dispose and cleanup
  /// CRITICAL: Dispose all ads safely
  void dispose() {
    // Clear all caches
    for (var cache in _adCache.values) {
      cache.clear();
    }
    _adCache.clear();

    // Cancel all pending loads
    for (var completers in _loadingAds.values) {
      for (var completer in completers) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    }
    _loadingAds.clear();

    // Reset global lock
    _isFullScreenAdShowing = false;
  }
}
