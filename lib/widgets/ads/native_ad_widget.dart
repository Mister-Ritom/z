import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
      setState(() => _isLoading = true);
    }

    late NativeAd ad;
    ad = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'multiNativeAd',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (_isDisposed || !mounted) {
            developer.log('Ad loaded');
            ad.dispose();
            return;
          }
          setState(() => _isLoading = false);
        },
        onAdFailedToLoad: (failedAd, error) {
          developer.log('Ad failed ', error: error);
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
    setState(() => _isDismissed = true);
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  constraints.maxWidth > 0
                      ? constraints.maxWidth
                      : MediaQuery.of(context).size.width -
                          32; // Account for margin
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  SizedBox(
                    width: width,
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
                                Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
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
              );
            },
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ensure we have valid constraints before rendering the platform view
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return SizedBox(
            width:
                constraints.maxWidth > 0
                    ? constraints.maxWidth
                    : double.infinity,
            height: adHeight,
          );
        }

        return ClipRect(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              maxWidth: constraints.maxWidth,
              minHeight: adHeight,
              maxHeight: adHeight,
            ),
            child: SizedBox(
              width: constraints.maxWidth,
              height: adHeight,
              child: AdWidget(ad: ad),
            ),
          ),
        );
      },
    );
  }
}
