package me.ritom.z.z

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.*
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import com.google.android.gms.ads.nativead.MediaView
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
            cornerRadius = this@MultiNativeAdFactory.context.resources.displayMetrics.density * cornerRadiusPara
            setStroke(1, Color.parseColor("#80CCCCCC"))
        }
        adView.background = background
        // CRITICAL: Use MATCH_PARENT for both dimensions to respect Flutter's exact constraints
        // Flutter will provide the exact size via PlatformView, so we must fill it exactly
        adView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 
            ViewGroup.LayoutParams.MATCH_PARENT // Match Flutter's exact height
        )
        adView.setPadding(padding, padding, padding, padding)

        val headlineView = TextView(context).apply {
            text = nativeAd.headline
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

        val ctaButton = Button(context).apply {
            text = nativeAd.callToAction
            setBackgroundColor(Color.parseColor("#1E88E5"))
            setTextColor(Color.WHITE)
            setPadding(30, 15, 30, 15)
            textSize = 14f
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
            // Fixed size for icon - prevents layout issues
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                weight = 0f // Don't expand
            }
            scaleType = ImageView.ScaleType.FIT_CENTER
            adjustViewBounds = true // Maintain aspect ratio
            nativeAd.icon?.let { setImageDrawable(it.drawable) }
        }

        // MediaView with proper sizing based on adType
        // CRITICAL: Must fit within Flutter's 300px height constraint
        // Small ad: ~120px media, Large ad: ~160px media
        val mediaView = MediaView(context).apply {
            val mediaHeight = if (adType == "small") {
                // Small ad: 300px total - padding(48) - icon/text(132) = ~120px for media
                120
            } else {
                // Large ad: 300px total - padding(48) - icon/text(92) = ~160px for media
                160
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                mediaHeight
            ).apply {
                weight = 0f // Don't expand
            }
            scaleType = ImageView.ScaleType.CENTER_CROP
        }

        // FIXED: Correct orientation handling
        val mainLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL // Always vertical for proper stacking
            // CRITICAL: MATCH_PARENT to fill Flutter's exact constraints
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 
                ViewGroup.LayoutParams.MATCH_PARENT // Fill Flutter's exact height
            )
            setPadding(0, 0, 0, 0)
        }

        if (adLayout == "vertical") {
            val topRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(iconView)
                addView(TextView(context).apply {
                    width = 8
                })
                val headlineRow = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    addView(headlineView)
                    addView(adLabel)
                }
                val textColumn = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    addView(headlineRow)
                    addView(bodyView)
                }
                addView(textColumn, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            }

            mainLayout.addView(topRow)
            mainLayout.addView(mediaView)
            mainLayout.addView(ctaButton)
        } else {
            val adLabelRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(headlineView)
                addView(Space(context), LinearLayout.LayoutParams(8, 0))
                addView(adLabel)
            }

            val textBlock = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                addView(adLabelRow)
                addView(bodyView)
                addView(ctaButton)
            }

            val bottomRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(iconView)
                addView(Space(context), LinearLayout.LayoutParams(12, 0))
                addView(textBlock, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            }

            mainLayout.addView(mediaView)
            mainLayout.addView(bottomRow)
        }

        // CRITICAL: Add mainLayout with MATCH_PARENT to fill adView exactly
        adView.addView(mainLayout, ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT // Fill adView exactly
        ))

        // Assign views for tracking - MUST be done before setNativeAd
        adView.headlineView = headlineView
        adView.bodyView = bodyView
        adView.callToActionView = ctaButton
        adView.iconView = iconView
        adView.mediaView = mediaView
        
        // CRITICAL: Set native ad AFTER all views are assigned
        adView.setNativeAd(nativeAd)

        return adView
    }
}
