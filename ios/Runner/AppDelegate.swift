import UIKit
import Flutter
import GoogleMobileAds
import google_mobile_ads
// Note: You generally don't need 'import google_mobile_ads' in Swift for this setup.
// The classes are exposed through the main Flutter plugin imports.

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

GeneratedPluginRegistrant.register(with: self)
        FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      self,
      factoryId: "multiFactory",
    nativeAdFactory: MultiNativeAdFactory()
    )


        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}