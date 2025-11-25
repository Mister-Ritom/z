package me.ritom.z.z

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.*
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
class MultiNativeAdFactory(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        val adType = customOptions?.get("adType") as? String ?: "small"
        val adLayout = customOptions?.get("adLayout") as? String ?: "horizontal"
        val bgColor = (customOptions?.get("bgColor") as? String)?.let { Color.parseColor("#${it.removePrefix("#")}") } ?: Color.parseColor("#F0F0F0")
        val textColor = (customOptions?.get("textColor") as? String)?.let { Color.parseColor("#${it.removePrefix("#")}") } ?: Color.BLACK
        val cornerRadiusPara = ((customOptions?.get("cornerRadius") as? Double)?.toFloat()) ?: 12f
        val padding = 24

        val adView = NativeAdView(context)

        val background = GradientDrawable().apply {
            setColor(bgColor)
            cornerRadius = context.resources.displayMetrics.density * cornerRadiusPara
            setStroke(1, Color.parseColor("#80CCCCCC"))
        }
        adView.background = background
        adView.layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        // Padding moved to mainLayout to prevent bounds conflicts with Flutter's container

        val headlineView = TextView(context).apply {
            text = nativeAd.headline ?: ""
            setTextColor(textColor)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (adType == "small") 15f else 19f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setLines(2)
        }

        val bodyView = TextView(context).apply {
            text = nativeAd.body
            setTextColor(textColor)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (adType == "small") 12f else 15f)
            alpha = 0.8f
            setLines(3)
        }

        val ctaButton = TextView(context).apply {
            text = nativeAd.callToAction ?: ""
            setBackgroundColor(Color.parseColor("#1E88E5"))
            setTextColor(Color.WHITE)
            setPadding(30, 20, 30, 20)
            textSize = 14f
            gravity = Gravity.CENTER
            isClickable = true
            isFocusable = true
        }

        val adLabel = TextView(context).apply {
            text = "AD"
            setBackgroundColor(Color.parseColor("#FFA500"))
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            setPadding(6, 1, 6, 1)
            gravity = Gravity.CENTER
        }

        val iconView = ImageView(context).apply {
            val size = if (adType == "small") 80 else 110
            layoutParams = LinearLayout.LayoutParams(size, size)
            scaleType = ImageView.ScaleType.FIT_CENTER
            adjustViewBounds = true
        }

        nativeAd.icon?.let { iconView.setImageDrawable(it.drawable) } ?: run { iconView.visibility = ImageView.GONE }

        val mediaHeight = if (adType == "small") 120 else 160

        val mediaContainer = FrameLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, mediaHeight)
            clipChildren = true
            clipToPadding = true
        }

        val mediaView = MediaView(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        mediaContainer.addView(mediaView)

        val mainLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
            setPadding(padding, padding, padding, padding)  // Padding moved here to prevent bounds conflicts
        }

        // Variable to hold advertiser view for tracking (used in both layouts)
        var advertiserView: TextView? = null
        
        if (adLayout == "vertical") {
            val headlineRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(headlineView)
                addView(adLabel)
            }
            
            val textColumn = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                addView(headlineRow)
                if (nativeAd.body != null) addView(bodyView)
            }
            
            // Add advertiser view in vertical layout if present
            nativeAd.advertiser?.let {
                advertiserView = TextView(context).apply {
                    text = it
                    setTextColor(textColor)
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                    alpha = 0.7f
                }
                textColumn.addView(advertiserView)
            }
            
            val topRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(iconView)
                addView(Space(context).apply {
                    layoutParams = LinearLayout.LayoutParams(8, 0)
                })
                addView(textColumn, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            }

            mainLayout.addView(topRow)
            mainLayout.addView(mediaContainer)
            mainLayout.addView(ctaButton)
        } else {
            val adLabelRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(headlineView)
                addView(Space(context).apply {
                    layoutParams = LinearLayout.LayoutParams(8, 0)
                })
                addView(adLabel)
            }

            val textBlock = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                addView(adLabelRow)
                if (nativeAd.body != null) addView(bodyView)
                addView(ctaButton)
            }

            nativeAd.advertiser?.let {
                advertiserView = TextView(context).apply {
                    text = it
                    setTextColor(textColor)
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                    alpha = 0.7f
                }
                adView.advertiserView = advertiserView
                textBlock.addView(advertiserView)
            }

            val bottomRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(iconView)
                addView(Space(context).apply {
                    layoutParams = LinearLayout.LayoutParams(12, 0)
                })
                addView(textBlock, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            }

            mainLayout.addView(mediaContainer)
            mainLayout.addView(bottomRow)
        }

        adView.addView(mainLayout, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))

        adView.headlineView = headlineView
        if (nativeAd.body != null) adView.bodyView = bodyView
        adView.callToActionView = ctaButton
        if (nativeAd.icon != null) adView.iconView = iconView
        adView.mediaView = mediaView
        // Assign advertiser view if present (for tracking)
        advertiserView?.let {
            adView.advertiserView = it
        }

        adView.setNativeAd(nativeAd)

        return adView
    }
}
