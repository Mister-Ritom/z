import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:z/services/ad_manager.dart';
import 'package:z/utils/constants.dart';

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
          setState(() => _ad = ad);
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
