package com.example.mobarandom

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.HapticFeedbackConstants
import android.view.View
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.edit
import androidx.core.widget.NestedScrollView
import com.google.android.material.button.MaterialButton
import com.google.android.material.card.MaterialCardView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.materialswitch.MaterialSwitch
import com.google.android.material.snackbar.Snackbar
import com.google.android.material.textfield.TextInputEditText

class MainActivity : AppCompatActivity() {
    private lateinit var scrollView: NestedScrollView
    private lateinit var rolePoolInput: TextInputEditText
    private lateinit var lastGameInput: TextInputEditText
    private lateinit var allowDuplicateSwitch: MaterialSwitch
    private lateinit var mirrorBadge: TextView
    private lateinit var resultCard: MaterialCardView
    private lateinit var seedText: TextView
    private lateinit var playersAText: TextView
    private lateinit var playersBText: TextView
    private lateinit var rolesAText: TextView
    private lateinit var rolesBText: TextView
    private lateinit var copyButton: MaterialButton

    private var currentResult: GroupingResult? = null
    private val preferences by lazy {
        getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        bindViews()
        configureRolePool()
        configureActions()
        generateGroups(scrollToResult = false)
    }

    private fun bindViews() {
        scrollView = findViewById(R.id.mainScroll)
        rolePoolInput = findViewById(R.id.rolePoolInput)
        lastGameInput = findViewById(R.id.lastGameInput)
        allowDuplicateSwitch = findViewById(R.id.allowDuplicateSwitch)
        mirrorBadge = findViewById(R.id.mirrorBadge)
        resultCard = findViewById(R.id.resultCard)
        seedText = findViewById(R.id.seedText)
        playersAText = findViewById(R.id.playersAText)
        playersBText = findViewById(R.id.playersBText)
        rolesAText = findViewById(R.id.rolesAText)
        rolesBText = findViewById(R.id.rolesBText)
        copyButton = findViewById(R.id.copyButton)
    }

    private fun configureRolePool() {
        val savedPool = preferences.getString(KEY_ROLE_POOL, null)
        rolePoolInput.setText(savedPool?.takeIf { it.isNotEmpty() } ?: GroupingEngine.DEFAULT_POOL_TEXT)
        rolePoolInput.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(value: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(value: CharSequence?, start: Int, before: Int, count: Int) = Unit

            override fun afterTextChanged(value: Editable?) {
                preferences.edit { putString(KEY_ROLE_POOL, value?.toString().orEmpty()) }
            }
        })
    }

    private fun configureActions() {
        allowDuplicateSwitch.setOnCheckedChangeListener { _, checked ->
            mirrorBadge.visibility = if (checked) View.VISIBLE else View.GONE
        }

        findViewById<MaterialButton>(R.id.generateButton).setOnClickListener {
            generateGroups(scrollToResult = true)
        }

        findViewById<MaterialButton>(R.id.resetButton).setOnClickListener {
            MaterialAlertDialogBuilder(this)
                .setTitle(R.string.reset_title)
                .setMessage(R.string.reset_message)
                .setNegativeButton(R.string.cancel, null)
                .setPositiveButton(R.string.reset_default) { _, _ ->
                    rolePoolInput.setText(GroupingEngine.DEFAULT_POOL_TEXT)
                    generateGroups(scrollToResult = true)
                }
                .show()
        }

        copyButton.setOnClickListener { copyResult() }
    }

    private fun generateGroups(scrollToResult: Boolean) {
        try {
            val result = GroupingEngine.generate(
                poolText = rolePoolInput.text?.toString().orEmpty(),
                lastGameText = lastGameInput.text?.toString().orEmpty(),
                allowDuplicate = allowDuplicateSwitch.isChecked,
            )
            currentResult = result
            renderResult(result)
            findViewById<View>(R.id.generateButton)
                .performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)

            if (scrollToResult) {
                resultCard.post {
                    scrollView.smoothScrollTo(0, resultCard.bottom)
                }
            }
        } catch (error: GroupingException) {
            MaterialAlertDialogBuilder(this)
                .setTitle(R.string.error_title)
                .setMessage(error.message)
                .setPositiveButton(R.string.confirm, null)
                .show()
        }
    }

    private fun renderResult(result: GroupingResult) {
        seedText.text = getString(R.string.seed_format, result.seed)
        playersAText.text = getString(R.string.players_format, result.playersA.joinToString("，"))
        playersBText.text = getString(R.string.players_format, result.playersB.joinToString("，"))
        rolesAText.text = getString(R.string.roles_format, result.rolesA.joinToString("，"))
        rolesBText.text = getString(R.string.roles_format, result.rolesB.joinToString("，"))
        resultCard.visibility = View.VISIBLE
    }

    private fun copyResult() {
        val result = currentResult ?: return
        val clipboard = getSystemService(ClipboardManager::class.java)
        clipboard.setPrimaryClip(ClipData.newPlainText(getString(R.string.result_title), result.formattedText))
        copyButton.text = getString(R.string.copied)
        copyButton.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
        Snackbar.make(copyButton, R.string.copied, Snackbar.LENGTH_SHORT).show()
        copyButton.postDelayed({ copyButton.setText(R.string.copy_result) }, 2_000)
    }

    private companion object {
        const val PREFERENCES_NAME = "moba_random_preferences"
        const val KEY_ROLE_POOL = "moba_role_pool"
    }
}
