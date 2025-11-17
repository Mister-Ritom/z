import Foundation
import GoogleMobileAds
import google_mobile_ads
import Flutter
import UIKit
import AVKit

/// Video Ad Factory for iOS
/// Creates full-screen video ad views for rewarded and interstitial ads
class VideoAdFactory: NSObject, FLTNativeAdFactory {
    
    func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable : Any]?) -> NativeAdView? {
        // This factory is primarily for video ads displayed via RewardedAd/InterstitialAd
        // Native ads with video content can also be handled here
        
        let adView = NativeAdView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        adView.backgroundColor = .black
        
        // Video container
        let videoContainer = UIView()
        videoContainer.translatesAutoresizingMaskIntoConstraints = false
        videoContainer.backgroundColor = .black
        
        // Media view for video content
        let mediaView = MediaView()
        mediaView.mediaContent = nativeAd.mediaContent
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        
        videoContainer.addSubview(mediaView)
        
        // Skip button (if enabled)
        let showSkip = customOptions?["showSkip"] as? Bool ?? true
        if showSkip {
            let skipButton = UIButton(type: .system)
            skipButton.setTitle("Skip", for: .normal)
            skipButton.setTitleColor(.white, for: .normal)
            skipButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            skipButton.layer.cornerRadius = 20
            skipButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            skipButton.translatesAutoresizingMaskIntoConstraints = false
            skipButton.tag = 999 // Tag for identification
            
            videoContainer.addSubview(skipButton)
            
            NSLayoutConstraint.activate([
                skipButton.topAnchor.constraint(equalTo: videoContainer.topAnchor, constant: 16),
                skipButton.trailingAnchor.constraint(equalTo: videoContainer.trailingAnchor, constant: -16),
            ])
        }
        
        // Ad label
        let adLabel = UILabel()
        adLabel.text = "AD"
        adLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        adLabel.textColor = .white
        adLabel.backgroundColor = .orange
        adLabel.layer.cornerRadius = 3
        adLabel.clipsToBounds = true
        adLabel.textAlignment = .center
        adLabel.translatesAutoresizingMaskIntoConstraints = false
        adLabel.widthAnchor.constraint(equalToConstant: 30).isActive = true
        adLabel.heightAnchor.constraint(equalToConstant: 16).isActive = true
        
        videoContainer.addSubview(adLabel)
        
        // Headline (optional, shown at bottom)
        let headlineView = UILabel()
        headlineView.text = nativeAd.headline
        headlineView.font = UIFont.boldSystemFont(ofSize: 18)
        headlineView.textColor = .white
        headlineView.numberOfLines = 2
        headlineView.textAlignment = .center
        headlineView.translatesAutoresizingMaskIntoConstraints = false
        
        videoContainer.addSubview(headlineView)
        
        // CTA Button
        let ctaButton = UIButton(type: .system)
        ctaButton.setTitle(nativeAd.callToAction, for: .normal)
        ctaButton.backgroundColor = UIColor(hexString: "1E88E5") ?? .systemBlue
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.layer.cornerRadius = 8
        ctaButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        videoContainer.addSubview(ctaButton)
        
        adView.addSubview(videoContainer)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Video container fills the ad view
            videoContainer.topAnchor.constraint(equalTo: adView.topAnchor),
            videoContainer.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            videoContainer.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            videoContainer.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
            
            // Media view fills container
            mediaView.topAnchor.constraint(equalTo: videoContainer.topAnchor),
            mediaView.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: videoContainer.trailingAnchor),
            mediaView.bottomAnchor.constraint(equalTo: videoContainer.bottomAnchor),
            
            // Ad label
            adLabel.topAnchor.constraint(equalTo: videoContainer.topAnchor, constant: 16),
            adLabel.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor, constant: 16),
            
            // Headline at bottom
            headlineView.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor, constant: 16),
            headlineView.trailingAnchor.constraint(equalTo: videoContainer.trailingAnchor, constant: -16),
            headlineView.bottomAnchor.constraint(equalTo: ctaButton.topAnchor, constant: -16),
            
            // CTA button
            ctaButton.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor, constant: 16),
            ctaButton.trailingAnchor.constraint(equalTo: videoContainer.trailingAnchor, constant: -16),
            ctaButton.bottomAnchor.constraint(equalTo: videoContainer.bottomAnchor, constant: -32),
        ])
        
        // Assign views for tracking
        adView.headlineView = headlineView
        adView.callToActionView = ctaButton
        adView.mediaView = mediaView
        adView.nativeAd = nativeAd
        
        return adView
    }
}

