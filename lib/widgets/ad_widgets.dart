import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:z/services/ad_manager.dart';
import 'package:z/utils/constants.dart';

class NativeAdWidget extends StatefulWidget {
  final Map<String, dynamic>? customOptions;
  final bool showSkipButton;
  final String? adKey;

  const NativeAdWidget({
    super.key,
    this.customOptions,
    this.showSkipButton = true,
    this.adKey,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget>
    with AutomaticKeepAliveClientMixin {
  NativeAd? _ad;
  bool _isLoading = true;
  bool _isDismissed = false;
  bool _isDisposed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (_isDisposed) return;

    final adUnitId =
        Platform.isIOS
            ? AppConstants.nativeAdUnitIdIos
            : AppConstants.nativeAdUnitIdAndroid;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    late NativeAd ad;
    ad = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'multiNativeAd',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (_isDisposed || !mounted) {
            developer.log("Ad loaded");
            ad.dispose();
            return;
          }
          setState(() {
            _isLoading = false;
          });
        },
        onAdFailedToLoad: (failedAd, error) {
          developer.log("Ad failed ", error: error);
          if (_isDisposed || !mounted) {
            failedAd.dispose();
            return;
          }
          setState(() {
            _isLoading = false;
            _isDismissed = true;
          });
          failedAd.dispose();
        },
      ),
    );

    _ad = ad;
    ad.load();
  }

  void _skipAd() {
    if (_isDisposed) return;
    setState(() {
      _isDismissed = true;
    });
    _safeDisposeAd();
  }

  void _safeDisposeAd() {
    final adToDispose = _ad;
    _ad = null;
    adToDispose?.dispose();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _safeDisposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isDismissed) {
      return const SizedBox.shrink();
    }

    if (_isLoading || _ad == null) {
      return Container(
        height: 200,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final adType = (widget.customOptions?['adType'] as String?) ?? 'small';
    final adHeight = adType == 'small' ? 250.0 : 300.0;

    return ClipRect(
      child: Container(
        width: double.infinity,
        height: adHeight,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              SizedBox(
                width: double.infinity,
                height: adHeight,
                child: NativeAdWidgetView(
                  ad: _ad!,
                  customOptions: widget.customOptions,
                ),
              ),
              if (widget.showSkipButton)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: _skipAd,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Skip',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NativeAdWidgetView extends StatelessWidget {
  final NativeAd ad;
  final Map<String, dynamic>? customOptions;

  const NativeAdWidgetView({super.key, required this.ad, this.customOptions});

  @override
  Widget build(BuildContext context) {
    final adType = (customOptions?['adType'] as String?) ?? 'small';
    final adHeight = adType == 'small' ? 250.0 : 300.0;

    return ClipRect(
      child: SizedBox(
        width: double.infinity,
        height: adHeight,
        child: AdWidget(ad: ad),
      ),
    );
  }
}

class VideoAdWidget extends StatefulWidget {
  final bool showSkipButton;
  final VoidCallback? onAdDismissed;
  final Duration? skipDelay;

  const VideoAdWidget({
    super.key,
    this.showSkipButton = true,
    this.onAdDismissed,
    this.skipDelay,
  });

  @override
  State<VideoAdWidget> createState() => _VideoAdWidgetState();
}

class _VideoAdWidgetState extends State<VideoAdWidget> {
  InterstitialAd? _ad;
  bool _isLoading = true;
  bool _isDismissed = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (_isDisposed) return;

    final adUnitId =
        Platform.isIOS
            ? AppConstants.interstitialAdUnitIdIos
            : AppConstants.interstitialAdUnitIdAndroid;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (_isDisposed || !mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad;
            _isLoading = false;
          });
          _showAd();
        },
        onAdFailedToLoad: (error) {
          if (_isDisposed || !mounted) return;
          setState(() {
            _isLoading = false;
            _isDismissed = true;
          });
          widget.onAdDismissed?.call();
        },
      ),
    );
  }

  void _showAd() {
    if (_isDisposed || !mounted || _ad == null) return;

    if (AdManager.isFullScreenAdShowing) {
      _safeDisposeAd();
      widget.onAdDismissed?.call();
      return;
    }

    AdManager.setFullScreenAdShowing(true);

    _ad?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _safeDisposeAd();
        AdManager.setFullScreenAdShowing(false);
        if (mounted && !_isDisposed) {
          setState(() {
            _isDismissed = true;
          });
          widget.onAdDismissed?.call();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _safeDisposeAd();
        AdManager.setFullScreenAdShowing(false);
        if (mounted && !_isDisposed) {
          setState(() {
            _isDismissed = true;
          });
          widget.onAdDismissed?.call();
        }
      },
    );

    _ad?.show();
  }

  void _safeDisposeAd() {
    final adToDispose = _ad;
    _ad = null;
    adToDispose?.dispose();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _safeDisposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class InterstitialAdWidget extends StatefulWidget {
  final VoidCallback? onAdDismissed;

  const InterstitialAdWidget({super.key, this.onAdDismissed});

  @override
  State<InterstitialAdWidget> createState() => _InterstitialAdWidgetState();
}

class _InterstitialAdWidgetState extends State<InterstitialAdWidget> {
  InterstitialAd? _ad;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (_isDisposed) return;

    final adUnitId =
        Platform.isIOS
            ? AppConstants.interstitialAdUnitIdIos
            : AppConstants.interstitialAdUnitIdAndroid;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (_isDisposed || !mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad;
          });
          _showAd();
        },
        onAdFailedToLoad: (error) {
          if (_isDisposed || !mounted) return;
          widget.onAdDismissed?.call();
        },
      ),
    );
  }

  void _showAd() {
    if (_isDisposed || !mounted || _ad == null) return;

    if (AdManager.isFullScreenAdShowing) {
      _safeDisposeAd();
      widget.onAdDismissed?.call();
      return;
    }

    AdManager.setFullScreenAdShowing(true);

    _ad?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _safeDisposeAd();
        AdManager.setFullScreenAdShowing(false);
        if (mounted && !_isDisposed) {
          widget.onAdDismissed?.call();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _safeDisposeAd();
        AdManager.setFullScreenAdShowing(false);
        if (mounted && !_isDisposed) {
          widget.onAdDismissed?.call();
        }
      },
    );

    _ad?.show();
  }

  void _safeDisposeAd() {
    final adToDispose = _ad;
    _ad = null;
    adToDispose?.dispose();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _safeDisposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
