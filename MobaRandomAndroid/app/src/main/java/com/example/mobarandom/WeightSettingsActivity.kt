package com.example.mobarandom

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Typeface
import android.os.Bundle
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.view.Gravity
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.HorizontalScrollView
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.button.MaterialButton
import com.google.android.material.card.MaterialCardView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout

class WeightSettingsActivity : AppCompatActivity() {
    private lateinit var categories: List<RoleCategory>
    private lateinit var configuration: RoleWeightConfiguration
    private lateinit var characterContainer: GridLayout
    private val fields = linkedMapOf<Pair<String, String>, TextInputEditText>()
    private val totals = linkedMapOf<String, TextView>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val preferences = getSharedPreferences(RoleWeightStorage.PREFERENCES_NAME, Context.MODE_PRIVATE)
        val poolText = intent.getStringExtra(EXTRA_POOL_TEXT)
            ?: preferences.getString(KEY_ROLE_POOL, GroupingEngine.DEFAULT_POOL_TEXT).orEmpty()
        categories = GroupingEngine.parseRolePool(poolText)
        if (categories.isEmpty()) {
            finish()
            return
        }
        configuration = RoleWeightStorage.load(this, poolText)
        setContentView(buildContent())
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = attemptClose()
        })
    }

    private fun buildContent(): LinearLayout {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        }
        val toolbar = MaterialToolbar(this).apply {
            title = getString(R.string.weight_settings_title)
            setNavigationIcon(androidx.appcompat.R.drawable.abc_ic_ab_back_material)
            setNavigationOnClickListener { attemptClose() }
        }
        root.addView(toolbar, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(56)))

        val scroll = ScrollView(this)
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(12), dp(16), dp(24))
        }
        content.addView(TextView(this).apply {
            text = getString(R.string.weight_settings_hint)
            setTextColor(resolveColor(com.google.android.material.R.attr.colorOnSurfaceVariant))
            setPadding(0, 0, 0, dp(12))
        })
        content.addView(LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            addView(MaterialButton(this@WeightSettingsActivity).apply {
                text = getString(R.string.export_weights_json)
                setOnClickListener { exportJson() }
            }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginEnd = dp(6)
            })
            addView(MaterialButton(this@WeightSettingsActivity).apply {
                text = getString(R.string.import_weights_json)
                setOnClickListener { importJson() }
            }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(6)
            })
        }, marginParams())
        characterContainer = GridLayout(this).apply {
            columnCount = weightGridColumnCount(resources.configuration.screenWidthDp)
            alignmentMode = GridLayout.ALIGN_MARGINS
        }
        content.addView(
            characterContainer,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        renderCharacterCards()
        scroll.addView(content)
        root.addView(scroll, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))

        root.addView(MaterialButton(this).apply {
            text = getString(R.string.save_weights)
            setOnClickListener { save() }
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            setMargins(dp(16), dp(8), dp(16), dp(16))
        })
        return root
    }

    private fun renderCharacterCards() {
        fields.clear()
        totals.clear()
        characterContainer.removeAllViews()
        val columns = characterContainer.columnCount
        configuration.characters.forEachIndexed { index, entry ->
            characterContainer.addView(buildCharacterCard(entry), GridLayout.LayoutParams().apply {
                width = 0
                height = GridLayout.LayoutParams.WRAP_CONTENT
                rowSpec = GridLayout.spec(index / columns)
                columnSpec = GridLayout.spec(index % columns, 1f)
                setMargins(dp(6), 0, dp(6), dp(12))
            })
        }
    }

    private fun buildCharacterCard(entry: CharacterLaneWeights): MaterialCardView {
        val card = MaterialCardView(this)
        val body = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(10), dp(12), dp(10), dp(12))
        }
        val heading = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        heading.addView(TextView(this).apply {
            text = entry.character
            textSize = 17f
            setTypeface(typeface, Typeface.BOLD)
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val totalView = TextView(this).apply {
            textSize = 12f
            setTypeface(typeface, Typeface.BOLD)
        }
        totals[entry.character] = totalView
        heading.addView(totalView)
        body.addView(heading)

        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(10), 0, 0)
        }
        categories.forEach { category ->
            val input = TextInputEditText(this).apply {
                setText((entry.laneWeights[category.name] ?: 0).toString())
                inputType = InputType.TYPE_CLASS_NUMBER
                gravity = Gravity.CENTER
                imeOptions = EditorInfo.IME_ACTION_DONE
                contentDescription = getString(R.string.weight_field_description, entry.character, category.name)
                setOnFocusChangeListener { _, hasFocus -> if (!hasFocus) commitRow(entry.character) }
                setOnEditorActionListener { _, _, _ ->
                    commitRow(entry.character)
                    clearFocus()
                    true
                }
                addTextChangedListener(object : TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = updateTotal(entry.character)
                    override fun afterTextChanged(s: Editable?) = Unit
                })
            }
            fields[entry.character to category.name] = input
            row.addView(TextInputLayout(this).apply {
                hint = category.name
                addView(input)
            }, LinearLayout.LayoutParams(dp(60), ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                marginEnd = dp(4)
            })
        }
        body.addView(HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            addView(row)
        })
        card.addView(body)
        updateTotal(entry.character)
        return card
    }

    private fun parsedValues(character: String): List<Int>? {
        val values = mutableListOf<Int>()
        for (category in categories) {
            val raw = fields[character to category.name]?.text?.toString().orEmpty()
            val value = raw.toIntOrNull() ?: return null
            if (value < 0) return null
            values += value
        }
        return values
    }

    private fun commitRow(character: String) {
        val values = parsedValues(character) ?: return
        val normalized = RoleWeightConfiguration.normalizeToHundred(values) ?: return
        if (normalized != values) {
            categories.forEachIndexed { index, category ->
                fields[character to category.name]?.setText(normalized[index].toString())
            }
        }
        updateTotal(character)
    }

    private fun updateTotal(character: String) {
        val values = parsedValues(character)
        val total = values?.sum()
        totals[character]?.apply {
            text = when {
                total == null -> getString(R.string.weight_invalid_integer)
                total == 100 -> getString(R.string.weight_total_complete)
                total < 100 -> getString(R.string.weight_remaining, 100 - total)
                else -> getString(R.string.weight_will_normalize)
            }
            setTextColor(
                ContextCompat.getColor(
                    this@WeightSettingsActivity,
                    if (total == 100) android.R.color.holo_green_dark else android.R.color.holo_orange_dark,
                )
            )
        }
    }

    private fun save() {
        configuration.characters.forEach { commitRow(it.character) }
        val updated = draftConfiguration()
        if (updated == null) {
            MaterialAlertDialogBuilder(this)
                .setTitle(R.string.weight_invalid_title)
                .setMessage(R.string.weight_invalid_message)
                .setPositiveButton(R.string.confirm, null)
                .show()
            return
        }
        RoleWeightStorage.save(this, updated)
        setResult(RESULT_OK)
        finish()
    }

    private fun draftConfiguration(): RoleWeightConfiguration? {
        val entries = configuration.characters.mapNotNull { entry ->
            val values = parsedValues(entry.character) ?: return@mapNotNull null
            if (values.sum() != 100) return@mapNotNull null
            CharacterLaneWeights(
                character = entry.character,
                laneWeights = categories.mapIndexed { index, category ->
                    category.name to values[index]
                }.toMap(linkedMapOf()),
                sourceLane = entry.sourceLane,
            )
        }
        return entries.takeIf { it.size == configuration.characters.size }
            ?.let { RoleWeightConfiguration(characters = it) }
    }

    private fun exportJson() {
        currentFocus?.clearFocus()
        configuration.characters.forEach { commitRow(it.character) }
        val updated = draftConfiguration()
        if (updated == null) {
            showNotice(R.string.weight_invalid_title, getString(R.string.weight_export_invalid))
            return
        }
        runCatching {
            RoleWeightTransfer.exportJson(categories.map { it.name }, updated)
        }.onSuccess { json ->
            getSystemService(ClipboardManager::class.java).setPrimaryClip(
                ClipData.newPlainText(getString(R.string.weight_settings_title), json)
            )
            showNotice(R.string.weight_export_success_title, getString(R.string.weight_export_success_message))
        }.onFailure { error ->
            showNotice(R.string.weight_invalid_title, error.message ?: getString(R.string.weight_export_invalid))
        }
    }

    private fun importJson() {
        currentFocus?.clearFocus()
        val clipboard = getSystemService(ClipboardManager::class.java)
        val json = clipboard.primaryClip?.getItemAt(0)?.coerceToText(this)?.toString().orEmpty()
        if (json.isBlank()) {
            showNotice(R.string.weight_import_failed_title, getString(R.string.weight_clipboard_empty))
            return
        }
        runCatching {
            RoleWeightTransfer.importJson(json, categories.map { it.name })
        }.onSuccess { imported ->
            RoleWeightStorage.saveImported(this, imported)
            categories = GroupingEngine.parseRolePool(imported.poolText)
            configuration = imported.configuration
            renderCharacterCards()
            setResult(RESULT_OK)
            showNotice(R.string.weight_import_success_title, getString(R.string.weight_import_success_message))
        }.onFailure { error ->
            showNotice(
                R.string.weight_import_failed_title,
                error.message ?: getString(R.string.weight_invalid_message),
            )
        }
    }

    private fun showNotice(title: Int, message: String) {
        MaterialAlertDialogBuilder(this)
            .setTitle(title)
            .setMessage(message)
            .setPositiveButton(R.string.confirm, null)
            .show()
    }

    private fun attemptClose() {
        currentFocus?.clearFocus()
        configuration.characters.forEach { commitRow(it.character) }
        val valid = configuration.characters.all { parsedValues(it.character)?.sum() == 100 }
        if (valid) {
            finish()
        } else {
            MaterialAlertDialogBuilder(this)
                .setTitle(R.string.discard_weights_title)
                .setMessage(R.string.discard_weights_message)
                .setNegativeButton(R.string.continue_editing, null)
                .setPositiveButton(R.string.discard_changes) { _, _ -> finish() }
                .show()
        }
    }

    private fun marginParams() = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT,
    ).apply { bottomMargin = dp(12) }

    private fun resolveColor(attribute: Int): Int {
        val typedValue = android.util.TypedValue()
        theme.resolveAttribute(attribute, typedValue, true)
        return typedValue.data
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    companion object {
        const val EXTRA_POOL_TEXT = "pool_text"
        private const val KEY_ROLE_POOL = "moba_role_pool"
    }
}

internal fun weightGridColumnCount(screenWidthDp: Int): Int = when {
    screenWidthDp >= 900 -> 3
    screenWidthDp >= 600 -> 2
    else -> 1
}
