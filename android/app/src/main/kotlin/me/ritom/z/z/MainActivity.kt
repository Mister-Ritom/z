package me.ritom.z.z

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register native ad factory
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "multiNativeAd",
            MultiNativeAdFactory(this)
        )
        
        // Register video ad factory
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "videoAd",
            VideoAdFactory(this)
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "multiNativeAd")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "videoAd")
    }
}
