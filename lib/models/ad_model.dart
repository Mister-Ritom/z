/// Ad model to represent different types of ads in the feed
enum AdType { native, video, interstitial, smallPromo }

/// Ad placement model
class AdPlacement {
  final int index; // Position in the feed
  final AdType adType;
  final Map<String, dynamic>? customOptions;

  AdPlacement({required this.index, required this.adType, this.customOptions});
}

/// Ad data model
class AdData {
  final String adUnitId;
  final AdType adType;
  final Map<String, dynamic>? customOptions;
  final bool isLoaded;
  final DateTime? loadedAt;

  AdData({
    required this.adUnitId,
    required this.adType,
    this.customOptions,
    this.isLoaded = false,
    this.loadedAt,
  });

  AdData copyWith({
    String? adUnitId,
    AdType? adType,
    Map<String, dynamic>? customOptions,
    bool? isLoaded,
    DateTime? loadedAt,
  }) {
    return AdData(
      adUnitId: adUnitId ?? this.adUnitId,
      adType: adType ?? this.adType,
      customOptions: customOptions ?? this.customOptions,
      isLoaded: isLoaded ?? this.isLoaded,
      loadedAt: loadedAt ?? this.loadedAt,
    );
  }
}
