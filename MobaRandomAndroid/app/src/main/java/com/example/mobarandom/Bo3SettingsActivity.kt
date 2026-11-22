package com.example.mobarandom

import android.graphics.Typeface
import android.os.Bundle
import android.text.InputType
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.content.edit
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.button.MaterialButton
import com.google.android.material.materialswitch.MaterialSwitch
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout

class Bo3SettingsActivity : AppCompatActivity() {
    private lateinit var seriesStore: Bo3SeriesStore
    private lateinit var teamAField: TextInputEditText
    private lateinit var teamBField: TextInputEditText
    private lateinit var poolField: TextInputEditText
    private lateinit var healthView: TextView
    private lateinit var errorView: TextView
    private lateinit var noBanSwitch: MaterialSwitch
    private lateinit var noBanHint: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        seriesStore = Bo3SeriesStore(this)
        setContentView(buildContent())
    }

    private fun buildContent(): LinearLayout {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(ContextCompat.getColor(this@Bo3SettingsActivity, R.color.surface))
        }
        root.addView(MaterialToolbar(this).apply {
            title = getString(R.string.bo3_settings_title)
            setNavigationIcon(androidx.appcompat.R.drawable.abc_ic_ab_back_material)
            setNavigationOnClickListener { finish() }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)))

        val scroll = ScrollView(this)
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(8), dp(16), dp(24))
        }
        content.addView(sectionTitle(getString(R.string.bo3_team_names)))
        teamAField = addTextField(
            content,
            getString(R.string.bo3_team_a),
            seriesStore.series.teamNames.a,
        )
        teamBField = addTextField(
            content,
            getString(R.string.bo3_team_b),
            seriesStore.series.teamNames.b,
            topMargin = dp(8),
        )
        content.addView(hint(getString(R.string.bo3_team_names_hint)))

        content.addView(sectionTitle(getString(R.string.bo3_role_pool)))
        poolField = TextInputEditText(this).apply {
            setText(
                getSharedPreferences(RoleWeightStorage.PREFERENCES_NAME, MODE_PRIVATE)
                    .getString(RoleWeightStorage.KEY_ROLE_POOL, GroupingEngine.DEFAULT_POOL_TEXT),
            )
            gravity = android.view.Gravity.TOP or android.view.Gravity.START
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
            minLines = 8
            textSize = 14f
            setPadding(dp(10), dp(10), dp(10), dp(10))
            setBackgroundColor(ContextCompat.getColor(this@Bo3SettingsActivity, R.color.surface))
        }
        content.addView(TextInputLayout(this).apply {
            hint = getString(R.string.bo3_role_pool)
            boxBackgroundMode = TextInputLayout.BOX_BACKGROUND_OUTLINE
            addView(poolField)
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { topMargin = dp(8) })
        healthView = TextView(this).apply {
            textSize = 12f
            setTextColor(ContextCompat.getColor(this@Bo3SettingsActivity, android.R.color.darker_gray))
            setPadding(0, dp(6), 0, 0)
        }
        content.addView(healthView)
        content.addView(MaterialButton(this).apply {
            text = getString(R.string.bo3_restore_default)
            textSize = 12f
            isAllCaps = false
            setOnClickListener {
                poolField.setText(GroupingEngine.DEFAULT_POOL_TEXT)
                updateHealth()
            }
        })

        content.addView(sectionTitle(getString(R.string.bo3_no_ban_game3)))
        noBanSwitch = MaterialSwitch(this).apply {
            text = getString(R.string.bo3_no_ban_game3)
            isChecked = seriesStore.series.noBanGame3
            setOnCheckedChangeListener { _, _ -> updateHealth() }
        }
        content.addView(noBanSwitch)
        noBanHint = hint(getString(R.string.bo3_no_ban_game3_hint))
        content.addView(noBanHint)
        if (seriesStore.series.games.getOrNull(2)?.started == true) {
            content.addView(hint(getString(R.string.bo3_no_ban_started)))
        }

        errorView = TextView(this).apply {
            setTextColor(0xFFB3261E.toInt())
            textSize = 12f
            setPadding(0, dp(8), 0, 0)
        }
        content.addView(errorView)

        scroll.addView(content)
        root.addView(scroll, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        root.addView(MaterialButton(this).apply {
            text = getString(R.string.bo3_apply)
            textSize = 15f
            isAllCaps = false
            setOnClickListener { applySettings() }
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { setMargins(dp(16), dp(8), dp(16), dp(16)) })

        poolField.addTextChangedListener(object : android.text.TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: android.text.Editable?) {
                errorView.text = ""
                updateHealth()
            }
        })

        updateHealth()
        return root
    }

    private fun applySettings() {
        val poolText = poolField.text?.toString().orEmpty()
        val pool = Bo3Pool(poolText)
        if (pool.total < Bo3DraftEngine.MINIMUM_POOL_FOR_GAME) {
            errorView.text = getString(R.string.bo3_pool_too_small_settings, Bo3DraftEngine.MINIMUM_POOL_FOR_GAME)
            return
        }
        getSharedPreferences(RoleWeightStorage.PREFERENCES_NAME, MODE_PRIVATE).edit {
            putString(RoleWeightStorage.KEY_ROLE_POOL, poolText)
        }
        seriesStore.updateTeamNames(Bo3TeamNames(
            a = teamAField.text?.toString().orEmpty(),
            b = teamBField.text?.toString().orEmpty(),
        ))
        seriesStore.updateNoBanGame3(noBanSwitch.isChecked)
        setResult(RESULT_OK)
        finish()
    }

    private fun updateHealth() {
        val pool = Bo3Pool(poolField.text?.toString().orEmpty())
        val canStart = pool.total >= Bo3DraftEngine.MINIMUM_POOL_FOR_GAME
        val health = when {
            pool.total >= Bo3DraftEngine.MINIMUM_POOL_FOR_FULL_GAME_3 -> getString(R.string.bo3_health_full)
            pool.total >= Bo3DraftEngine.MINIMUM_POOL_FOR_NO_BAN_GAME_3 -> getString(R.string.bo3_health_no_ban)
            canStart -> getString(R.string.bo3_health_game)
            else -> getString(
                R.string.bo3_pool_too_small_settings,
                Bo3DraftEngine.MINIMUM_POOL_FOR_GAME,
            )
        }
        healthView.text = getString(R.string.bo3_pool_health, pool.categories.size, pool.total) + " · " + health +
            if (pool.duplicates.isNotEmpty()) {
                " · 已忽略重复：" + pool.duplicates.take(8).joinToString("、") +
                    if (pool.duplicates.size > 8) " 等" else ""
            } else {
                ""
            }
        healthView.setTextColor(
            if (canStart) ContextCompat.getColor(this, android.R.color.darker_gray)
            else 0xFFB3261E.toInt(),
        )
        noBanHint.text = if (seriesStore.series.games.getOrNull(2)?.started == true) {
            getString(R.string.bo3_no_ban_started)
        } else {
            getString(R.string.bo3_no_ban_game3_hint)
        }
    }

    private fun sectionTitle(value: String): TextView = TextView(this).apply {
        text = value
        textSize = 15f
        setTypeface(typeface, Typeface.BOLD)
        setPadding(0, dp(18), 0, dp(6))
    }

    private fun hint(value: String): TextView = TextView(this).apply {
        text = value
        textSize = 12f
        setTextColor(ContextCompat.getColor(this@Bo3SettingsActivity, android.R.color.darker_gray))
    }

    private fun addTextField(
        parent: LinearLayout,
        hintValue: String,
        value: String,
        topMargin: Int = 0,
    ): TextInputEditText {
        val input = TextInputEditText(this).apply {
            setText(value)
            inputType = InputType.TYPE_CLASS_TEXT
            maxLines = 1
        }
        parent.addView(TextInputLayout(this).apply {
            hint = hintValue
            boxBackgroundMode = TextInputLayout.BOX_BACKGROUND_OUTLINE
            addView(input)
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { this.topMargin = topMargin })
        return input
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
