import UIKit
import Flutter
import GoogleMobileAds
import google_mobile_ads
import FirebaseCore
import FirebaseMessaging
import UserNotifications
// Note: You generally don't need 'import google_mobile_ads' in Swift for this setup.
// The classes are exposed through the main Flutter plugin imports.

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        GeneratedPluginRegistrant.register(with: self)
        
        // Register native ad factory
        FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
            self,
            factoryId: "multiNativeAd",
            nativeAdFactory: MultiNativeAdFactory()
        )
        
        // Register video ad factory
        FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
            self,
            factoryId: "videoAd",
            nativeAdFactory: VideoAdFactory()
        )

        // FCM setup (currently disabled via iosNotificationAvailable flag in Dart)
        // When enabled, this will handle push notifications
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { _, _ in }
            )
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        application.registerForRemoteNotifications()
        
        // Set FCM messaging delegate
        Messaging.messaging().delegate = self

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Handle remote notification registration
    override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // Handle notification when app is in foreground
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Let Flutter handle this
        completionHandler([[.banner, .sound, .badge]])
    }
    
    // Handle notification tap
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        // Let Flutter handle this
        completionHandler()
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    // Handle FCM token refresh
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM registration token: \(String(describing: fcmToken))")
        // Token is handled by Flutter plugin
    }
}