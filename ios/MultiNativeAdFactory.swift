import Foundation
import GoogleMobileAds
import google_mobile_ads
import Flutter
import UIKit

// MARK: - Native Ad Factory

class MultiNativeAdFactory: NSObject, FLTNativeAdFactory {

    func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable : Any]?) -> NativeAdView? {

        // --- 1. Custom Options & Styling ---
        
        let adType = customOptions?["adType"] as? String ?? "small"
        // New: Determine layout (horizontal or vertical)
        let adLayout = customOptions?["adLayout"] as? String ?? "horizontal" 
        
        let bgColor = (customOptions?["bgColor"] as? String).flatMap { UIColor(hexString: $0) } ?? UIColor(hexString: "F0F0F0")! // Light gray default
        let textColor = (customOptions?["textColor"] as? String).flatMap { UIColor(hexString: $0) } ?? UIColor.black
        let cornerRadius = (customOptions?["cornerRadius"] as? CGFloat) ?? 12.0
        let padding: CGFloat = 12.0 // Consistent inner padding
        
        // --- 2. AdView Setup (Container) ---

        let adView = NativeAdView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        adView.backgroundColor = bgColor
        adView.layer.cornerRadius = cornerRadius
        adView.clipsToBounds = true
        
        // Add a subtle border for decoration
        adView.layer.borderWidth = 1.0
        adView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.5).cgColor

        // --- 3. Component Views ---

        // Headline
        let headlineView = UILabel()
        headlineView.text = nativeAd.headline
        headlineView.font = UIFont.boldSystemFont(ofSize: adType == "small" ? 15 : 19)
        headlineView.textColor = textColor
        headlineView.numberOfLines = 2

        // Body
        let bodyView = UILabel()
        bodyView.text = nativeAd.body
        bodyView.font = UIFont.systemFont(ofSize: adType == "small" ? 12 : 15)
        bodyView.textColor = textColor.withAlphaComponent(0.8)
        bodyView.numberOfLines = 3

        // CTA Button
        let ctaButton = UIButton(type: .system)
        ctaButton.setTitle(nativeAd.callToAction, for: .normal)
        ctaButton.backgroundColor = UIColor(hexString: "1E88E5") // A nice blue
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.layer.cornerRadius = 8
        ctaButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 15, bottom: 8, right: 15)
        ctaButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        // Ad Label (Decoration)
        let adLabel = UILabel()
        adLabel.text = "AD"
        adLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        adLabel.textColor = .white
        adLabel.backgroundColor = .orange
        adLabel.layer.cornerRadius = 3
        adLabel.clipsToBounds = true
        adLabel.textAlignment = .center
        adLabel.widthAnchor.constraint(equalToConstant: 20).isActive = true
        adLabel.heightAnchor.constraint(equalToConstant: 12).isActive = true

        // Icon View
        let iconSize: CGFloat = adType == "small" ? 40 : 56
        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: iconSize).isActive = true
        if let icon = nativeAd.icon?.image {
            iconView.image = icon
        }

        // Media View
        let mediaHeight: CGFloat = adType == "small" ? 120 : 180
        let mediaView = MediaView()
        mediaView.mediaContent = nativeAd.mediaContent
        mediaView.heightAnchor.constraint(equalToConstant: mediaHeight).isActive = true

        // --- 4. Layout Stacks (Conditional) ---

        var mainStack: UIStackView
        
        if adLayout == "vertical" {
            // VERTICAL LAYOUT (Icon, Text, Media, CTA stacked)
            let topRowStack = UIStackView(arrangedSubviews: [iconView, headlineView, adLabel])
            topRowStack.axis = .horizontal
            topRowStack.spacing = 8
            topRowStack.alignment = .center // Vertically align items in the row
            
            mainStack = UIStackView(arrangedSubviews: [topRowStack, bodyView, mediaView, ctaButton])
            mainStack.axis = .vertical
            mainStack.spacing = padding
            
            // Ensure components fill the horizontal space
            headlineView.setContentCompressionResistancePriority(.required, for: .horizontal)
            
        } else {
            // DEFAULT HORIZONTAL LAYOUT (Media on top, Icon/Text/CTA below in a horizontal block)
            
            // Text Block (Headline + Body + CTA)
            let textAndCtaStack = UIStackView(arrangedSubviews: [headlineView, bodyView, ctaButton])
            textAndCtaStack.axis = .vertical
            textAndCtaStack.spacing = 4
            
            // Bottom Row (Icon + Text Block)
            let bottomRowStack = UIStackView(arrangedSubviews: [iconView, textAndCtaStack])
            bottomRowStack.axis = .horizontal
            bottomRowStack.spacing = padding
            bottomRowStack.alignment = .top
            
            // Main Stack (Media on top of the Bottom Row)
            mainStack = UIStackView(arrangedSubviews: [mediaView, bottomRowStack])
            mainStack.axis = .vertical
            mainStack.spacing = padding
            
            // Move Ad Label to the media view or similar top-right corner location
            // For simplicity in a single stack, we'll keep the adLabel out of the main stack
            // and position it later, or integrate it differently.
            // For now, let's include it in the text block.
            let adLabelContainer = UIStackView(arrangedSubviews: [headlineView, adLabel])
            adLabelContainer.axis = .horizontal
            adLabelContainer.spacing = 4
            textAndCtaStack.insertArrangedSubview(adLabelContainer, at: 0)
        }

        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        // --- 5. Final Assembly and Constraints ---

        adView.addSubview(mainStack)
        
        // Pin mainStack to the adView with padding
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: adView.topAnchor, constant: padding),
            mainStack.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: padding),
            mainStack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -padding),
            mainStack.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -padding)
        ])

        // Assign views for tracking
        adView.headlineView = headlineView
        adView.bodyView = bodyView
        adView.callToActionView = ctaButton
        adView.iconView = iconView
        adView.mediaView = mediaView
        adView.nativeAd = nativeAd
        return adView
    }
}

// MARK: - UIColor Extension

extension UIColor {
    convenience init?(hexString: String) {
        var hex = hexString
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6 else { return nil }
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return nil }
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF)/255,
            green: CGFloat((rgb >> 8) & 0xFF)/255,
            blue: CGFloat(rgb & 0xFF)/255,
            alpha: 1
        )
    }
}