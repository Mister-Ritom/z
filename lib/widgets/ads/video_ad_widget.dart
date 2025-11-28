import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:z/services/ad_manager.dart';
import 'package:z/utils/constants.dart';

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
      setState(() => _isLoading = true);
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
          setState(() => _isDismissed = true);
          widget.onAdDismissed?.call();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _safeDisposeAd();
        AdManager.setFullScreenAdShowing(false);
        if (mounted && !_isDisposed) {
          setState(() => _isDismissed = true);
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
