package com.example.mobarandom

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.drawable.GradientDrawable
import android.util.AttributeSet
import android.util.TypedValue
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import kotlin.math.roundToInt

class Bo3AvatarView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    private val repository: Bo3AvatarRepository = Bo3AvatarRepository(context),
) : FrameLayout(context, attrs) {
    private val imageView = ImageView(context).apply {
        scaleType = ImageView.ScaleType.CENTER_CROP
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
    }
    private val fallbackView = TextView(context).apply {
        gravity = Gravity.CENTER
        setTextColor(Color.WHITE)
        setTypeface(typeface, android.graphics.Typeface.BOLD)
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
    }
    private var currentName: String = ""

    init {
        addView(fallbackView)
        addView(imageView)
        clipToOutline = true
    }

    fun setCharacter(name: String, sizePx: Int, used: Boolean = false, showRing: Boolean = true) {
        currentName = name
        val params = layoutParams ?: LayoutParams(sizePx, sizePx)
        params.width = sizePx
        params.height = sizePx
        layoutParams = params
        val descriptor = repository.descriptor(name)
        val corner = sizePx * 0.28f
        val background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            this.cornerRadius = corner
            setColor(Color.TRANSPARENT)
        }
        this.background = background
        this.foreground = if (showRing && descriptor.hasImage) {
            GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                this.cornerRadius = corner
                setColor(Color.TRANSPARENT)
                setStroke(
                    maxOf(1, (sizePx / 40f).roundToInt()),
                    Bo3Palette.element(descriptor.element) ?: Color.WHITE,
                )
            }
        } else {
            null
        }
        fallbackView.text = descriptor.displayName.take(1)
        fallbackView.setTextSize(TypedValue.COMPLEX_UNIT_PX, sizePx * 0.42f)
        val colors = Bo3Palette.fallbackColors(descriptor.fallbackSeed)
        fallbackView.background = GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(colors.first, colors.second),
        ).apply { this.cornerRadius = corner }
        fallbackView.visibility = VISIBLE
        imageView.visibility = GONE
        imageView.setImageBitmap(null)
        imageView.alpha = 1f
        fallbackView.alpha = 1f
        imageView.colorFilter = null
        contentDescription = descriptor.displayName

        repository.load(name, sizePx) { bitmap ->
            if (currentName != name) return@load
            showBitmap(bitmap)
        }
        if (used) {
            imageView.alpha = 0.55f
            fallbackView.alpha = 0.55f
            imageView.colorFilter = ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(0f) })
        }
    }

    private fun showBitmap(bitmap: Bitmap?) {
        if (bitmap == null) return
        imageView.setImageBitmap(bitmap)
        imageView.visibility = VISIBLE
        fallbackView.visibility = GONE
    }
}
