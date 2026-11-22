package com.example.mobarandom

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.card.MaterialCardView

class Bo3HeroAdapter(
    private val context: Context,
    private val repository: Bo3AvatarRepository,
    private val avatarSizePx: Int,
    private val onClick: (Bo3HeroAdapter.Item) -> Unit,
) : RecyclerView.Adapter<Bo3HeroAdapter.Holder>() {
    private val density = context.resources.displayMetrics.density
    data class Item(
        val name: String,
        val role: String,
        val lockLabel: String?,
        val available: Boolean,
    )

    private var items: List<Item> = emptyList()

    fun submit(newItems: List<Item>) {
        items = newItems
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder {
        val card = MaterialCardView(parent.context).apply {
            layoutParams = RecyclerView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { setMargins(dp(4), dp(4), dp(4), dp(4)) }
            radius = dp(14).toFloat()
            cardElevation = 0f
            strokeWidth = 0
            setCardBackgroundColor(ContextCompat.getColor(parent.context, R.color.surface))
        }
        val body = LinearLayout(parent.context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(6), dp(6), dp(6), dp(8))
        }
        card.addView(body)
        val avatarHost = FrameLayout(parent.context).apply {
            layoutParams = LinearLayout.LayoutParams(avatarSizePx, avatarSizePx)
        }
        val avatar = Bo3AvatarView(parent.context, repository = repository)
        avatarHost.addView(avatar)
        val lockBadge = badge(parent.context).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.START,
            )
        }
        avatarHost.addView(lockBadge)
        val roleBadge = badge(parent.context).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.END,
            )
        }
        avatarHost.addView(roleBadge)
        body.addView(avatarHost)
        val name = TextView(parent.context).apply {
            gravity = Gravity.CENTER
            setTypeface(typeface, Typeface.BOLD)
            textSize = 13f
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            setTextColor(themeColor(parent.context, com.google.android.material.R.attr.colorOnSurface))
        }
        body.addView(name, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { topMargin = dp(5) })
        card.setOnClickListener {
            val position = (card.tag as? Int) ?: return@setOnClickListener
            items.getOrNull(position)?.let(onClick)
        }
        return Holder(card, avatar, lockBadge, roleBadge, name)
    }

    override fun onBindViewHolder(holder: Holder, position: Int) {
        val item = items[position]
        holder.card.tag = position
        holder.avatar.setCharacter(item.name, avatarSizePx, used = !item.available)
        holder.name.text = item.name
        holder.roleBadge.text = item.role
        holder.roleBadge.setTextColor(Bo3Palette.role(item.role))
        holder.roleBadge.background = GradientDrawable().apply {
            cornerRadius = dp(5).toFloat()
            setColor(withAlpha(Bo3Palette.role(item.role), 0.16f))
        }
        if (item.lockLabel == null) {
            holder.lockBadge.visibility = android.view.View.GONE
        } else {
            holder.lockBadge.visibility = android.view.View.VISIBLE
            holder.lockBadge.text = item.lockLabel
            holder.lockBadge.background = GradientDrawable().apply {
                cornerRadius = dp(5).toFloat()
                setColor(0xCC111318.toInt())
            }
        }
        holder.card.alpha = if (item.available) 1f else 0.55f
        holder.card.contentDescription = buildString {
            append(item.name)
            append("，推荐位置 ")
            append(item.role)
            append(if (item.available) "，可选" else "，${item.lockLabel ?: "已锁定"}")
        }
    }

    override fun getItemCount(): Int = items.size

    class Holder(
        val card: MaterialCardView,
        val avatar: Bo3AvatarView,
        val lockBadge: TextView,
        val roleBadge: TextView,
        val name: TextView,
    ) : RecyclerView.ViewHolder(card)

    private fun badge(context: Context): TextView = TextView(context).apply {
        textSize = 8f
        setTypeface(typeface, Typeface.BOLD)
        setPadding(dp(4), dp(2), dp(4), dp(2))
        setTextColor(Color.WHITE)
        visibility = android.view.View.GONE
    }

    private fun themeColor(context: Context, attr: Int): Int {
        val value = android.util.TypedValue()
        context.theme.resolveAttribute(attr, value, true)
        return value.data
    }

    private fun withAlpha(color: Int, alpha: Float): Int =
        Color.argb((alpha * 255).toInt(), Color.red(color), Color.green(color), Color.blue(color))

    private fun dp(value: Int): Int = (value * density).toInt().coerceAtLeast(1)
}
