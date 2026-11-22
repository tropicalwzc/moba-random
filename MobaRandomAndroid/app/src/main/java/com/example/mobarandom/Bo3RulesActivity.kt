package com.example.mobarandom

import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.card.MaterialCardView

class Bo3RulesActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(ContextCompat.getColor(this@Bo3RulesActivity, R.color.surface))
        }
        root.addView(MaterialToolbar(this).apply {
            title = getString(R.string.bo3_rule_title)
            setNavigationIcon(androidx.appcompat.R.drawable.abc_ic_ab_back_material)
            setNavigationOnClickListener { finish() }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)))
        val scroll = ScrollView(this)
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(8), dp(18), dp(28))
        }
        content.addView(hero())
        content.addView(ruleSection(
            getString(R.string.bo3_rule_game1),
            getString(R.string.bo3_rule_game1_body),
            Bo3DraftEngine.stepSequence,
        ))
        content.addView(ruleSection(
            getString(R.string.bo3_rule_game2),
            getString(R.string.bo3_rule_game2_body),
            Bo3DraftEngine.game2StepSequence,
        ))
        content.addView(ruleSection(
            getString(R.string.bo3_rule_game3),
            getString(R.string.bo3_rule_game3_body),
            Bo3DraftEngine.game3NoBanSequence,
        ))
        content.addView(ruleSection(
            getString(R.string.bo3_rule_global),
            getString(R.string.bo3_rule_global_body),
            null,
        ))
        content.addView(ruleSection(
            getString(R.string.bo3_rule_positions),
            getString(R.string.bo3_rule_positions_body),
            null,
        ))
        content.addView(ruleSection(
            getString(R.string.bo3_rule_reset),
            getString(R.string.bo3_rule_reset_body),
            null,
        ))
        content.addView(attribution())
        scroll.addView(content)
        root.addView(scroll, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        setContentView(root)
    }

    private fun hero(): View {
        val card = MaterialCardView(this).apply {
            radius = dp(16).toFloat()
            cardElevation = 0f
            setCardBackgroundColor(themeColor(com.google.android.material.R.attr.colorSurfaceContainerHigh))
            strokeColor = 0x44C9A24A
            strokeWidth = dp(1)
        }
        val body = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(14), dp(16), dp(14))
        }
        body.addView(text("BO3 · 全局 BP", 18f, Bo3Palette.GOLD, bold = true))
        body.addView(text(
            "共 3 局，先胜 2 局者赢得系列赛。每局单独征召；前序对局已选用的角色全局锁定，禁用每局重置。",
            13f,
            themeColor(com.google.android.material.R.attr.colorOnSurfaceVariant),
        ).apply { setPadding(0, dp(4), 0, 0) })
        card.addView(body, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        return card
    }

    private fun ruleSection(title: String, body: String, steps: List<Bo3Step>?): View {
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(18), 0, 0)
        }
        val heading = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        heading.addView(TextView(this).apply {
            text = "  "
            background = GradientDrawable().apply {
                cornerRadius = dp(2).toFloat()
                setColor(Bo3Palette.GOLD)
            }
        }, LinearLayout.LayoutParams(dp(3), dp(14)).apply { marginEnd = dp(7) })
        heading.addView(text(title, 15f, bold = true))
        box.addView(heading)
        if (steps != null) {
            box.addView(flowGrid(steps), LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(8) })
        }
        box.addView(text(body, 13f, themeColor(com.google.android.material.R.attr.colorOnSurfaceVariant)).apply { setPadding(0, dp(8), 0, 0) })
        return box
    }

    private fun flowGrid(steps: List<Bo3Step>): View {
        val grid = GridLayout(this).apply {
            columnCount = 4
            alignmentMode = GridLayout.ALIGN_MARGINS
        }
        steps.forEachIndexed { index, step ->
            val chip = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                setPadding(dp(4), dp(6), dp(4), dp(6))
                background = GradientDrawable().apply {
                    cornerRadius = dp(6).toFloat()
                    setColor(withAlpha(themeColor(com.google.android.material.R.attr.colorOnSurface), 0.05f))
                    setStroke(dp(1), withAlpha(themeColor(com.google.android.material.R.attr.colorOnSurface), 0.08f))
                }
            }
            chip.addView(text(if (index < 9) "0${index + 1}" else "${index + 1}", 9f, themeColor(com.google.android.material.R.attr.colorOnSurfaceVariant), bold = true))
            chip.addView(text("${step.team.shortLabel}${step.type.shortLabel}", 9f, Bo3Palette.team(step.team), bold = true))
            grid.addView(chip, GridLayout.LayoutParams().apply {
                width = 0
                height = ViewGroup.LayoutParams.WRAP_CONTENT
                columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                setMargins(dp(3), dp(3), dp(3), dp(3))
            })
        }
        return grid
    }

    private fun attribution(): View {
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(20), 0, 0)
        }
        box.addView(text(getString(R.string.bo3_rule_attribution), 12f, Bo3Palette.GOLD, bold = true).apply {
            setOnClickListener {
                runCatching {
                    startActivity(android.content.Intent(
                        android.content.Intent.ACTION_VIEW,
                        Uri.parse("https://baike.mihoyo.com/ys/obc/channel/map/189/25"),
                    ))
                }
            }
        })
        box.addView(text(getString(R.string.bo3_rule_disclaimer), 10f, themeColor(com.google.android.material.R.attr.colorOnSurfaceVariant)))
        return box
    }

    private fun text(value: String, size: Float, color: Int = themeColor(com.google.android.material.R.attr.colorOnSurface), bold: Boolean = false): TextView =
        TextView(this).apply {
            text = value
            textSize = size
            setTextColor(color)
            if (bold) setTypeface(typeface, Typeface.BOLD)
        }

    private fun themeColor(attr: Int): Int {
        val value = android.util.TypedValue()
        theme.resolveAttribute(attr, value, true)
        return value.data
    }

    private fun withAlpha(color: Int, alpha: Float): Int =
        android.graphics.Color.argb(
            (alpha * 255).toInt(),
            android.graphics.Color.red(color),
            android.graphics.Color.green(color),
            android.graphics.Color.blue(color),
        )

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
