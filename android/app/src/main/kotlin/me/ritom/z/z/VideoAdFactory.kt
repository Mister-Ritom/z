package me.ritom.z.z

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.view.ViewGroup
import android.widget.*
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import com.google.android.gms.ads.nativead.MediaView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

/// Video Ad Factory for Android
/// Creates full-screen video ad views for rewarded and interstitial ads
class VideoAdFactory(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {
    
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        val showSkip = customOptions?.get("showSkip") as? Boolean ?: true
        
        val adView = NativeAdView(context)
        adView.setBackgroundColor(Color.BLACK)
        
        // Main container
        val mainContainer = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.BLACK)
        }
        
        // Media view for video
        val mediaView = MediaView(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        mainContainer.addView(mediaView)
        
        // Skip button
        if (showSkip) {
            val skipButton = Button(context).apply {
                text = "Skip"
                setTextColor(Color.WHITE)
                setBackgroundColor(Color.parseColor("#99000000"))
                setPadding(32, 16, 32, 16)
                textSize = 14f
                layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    gravity = Gravity.TOP or Gravity.END
                    topMargin = 32
                    rightMargin = 32
                }
            }
            mainContainer.addView(skipButton)
        }
        
        // Ad label
        val adLabel = TextView(context).apply {
            text = "AD"
            setBackgroundColor(Color.parseColor("#FFA500"))
            setTextColor(Color.WHITE)
            textSize = 10f
            setPadding(12, 4, 12, 4)
            gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                topMargin = 32
                leftMargin = 32
            }
        }
        mainContainer.addView(adLabel)
        
        // Bottom container for headline and CTA
        val bottomContainer = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 64)
            gravity = Gravity.BOTTOM
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.BOTTOM
            }
        }
        
        // Headline
        val headlineView = TextView(context).apply {
            text = nativeAd.headline
            setTextColor(Color.WHITE)
            textSize = 18f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
            setLines(2)
        }
        bottomContainer.addView(headlineView)
        
        // CTA Button
        val ctaButton = Button(context).apply {
            text = nativeAd.callToAction
            setBackgroundColor(Color.parseColor("#1E88E5"))
            setTextColor(Color.WHITE)
            setPadding(48, 24, 48, 24)
            textSize = 16f
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 32
            }
        }
        bottomContainer.addView(ctaButton)
        
        mainContainer.addView(bottomContainer)
        adView.addView(mainContainer)
        
        // Assign views for tracking
        adView.headlineView = headlineView
        adView.callToActionView = ctaButton
        adView.mediaView = mediaView
        adView.setNativeAd(nativeAd)
        
        return adView
    }
}

