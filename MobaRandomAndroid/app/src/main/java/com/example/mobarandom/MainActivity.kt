package com.example.mobarandom

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.res.ColorStateList
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.text.TextUtils
import android.view.HapticFeedbackConstants
import android.view.Gravity
import android.view.View
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.content.edit
import androidx.core.widget.NestedScrollView
import com.google.android.material.button.MaterialButton
import com.google.android.material.card.MaterialCardView
import com.google.android.material.chip.Chip
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.materialswitch.MaterialSwitch
import com.google.android.material.snackbar.Snackbar
import com.google.android.material.textfield.TextInputEditText
import org.json.JSONArray
import org.json.JSONObject
import java.text.DateFormat
import java.util.Date
import java.util.UUID

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
    private lateinit var rolesAContainer: GridLayout
    private lateinit var rolesBContainer: GridLayout
    private lateinit var copyButton: MaterialButton
    private lateinit var generateButton: MaterialButton
    private lateinit var setupGenerateButton: MaterialButton
    private lateinit var historyCard: MaterialCardView
    private lateinit var historyHeading: TextView
    private lateinit var historyContainer: LinearLayout

    private var currentResult: GroupingResult? = null
    private var swappedSlots = mutableSetOf<RoleSlot>()
    private var history = mutableListOf<GameHistoryEntry>()
    private var currentHistoryId: String? = null
    private val preferences by lazy {
        getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        bindViews()
        configureRolePool()
        history = loadHistory().take(GroupingEngine.HISTORY_LIMIT).toMutableList()
        configureActions()
        renderHistory()
        generateGroups(scrollToResult = false, recordInHistory = false)
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
        rolesAContainer = findViewById(R.id.rolesAContainer)
        rolesBContainer = findViewById(R.id.rolesBContainer)
        copyButton = findViewById(R.id.copyButton)
        generateButton = findViewById(R.id.generateButton)
        setupGenerateButton = findViewById(R.id.setupGenerateButton)
        historyCard = findViewById(R.id.historyCard)
        historyHeading = findViewById(R.id.historyHeading)
        historyContainer = findViewById(R.id.historyContainer)
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

        setupGenerateButton.setOnClickListener {
            generateGroups(scrollToResult = true, recordInHistory = true)
        }
        generateButton.setOnClickListener {
            generateGroups(scrollToResult = true, recordInHistory = true)
        }

        findViewById<MaterialButton>(R.id.resetButton).setOnClickListener {
            MaterialAlertDialogBuilder(this)
                .setTitle(R.string.reset_title)
                .setMessage(R.string.reset_message)
                .setNegativeButton(R.string.cancel, null)
                .setPositiveButton(R.string.reset_default) { _, _ ->
                    rolePoolInput.setText(GroupingEngine.DEFAULT_POOL_TEXT)
                    generateGroups(scrollToResult = true, recordInHistory = true)
                }
                .show()
        }

        copyButton.setOnClickListener { copyResult() }
        findViewById<MaterialButton>(R.id.clearHistoryButton).setOnClickListener {
            MaterialAlertDialogBuilder(this)
                .setTitle(R.string.clear_history_title)
                .setMessage(R.string.clear_history_message)
                .setNegativeButton(R.string.cancel, null)
                .setPositiveButton(R.string.clear_history_confirm) { _, _ ->
                    history.clear()
                    currentHistoryId = null
                    saveHistory()
                    renderHistory()
                }
                .show()
        }
    }

    private fun generateGroups(scrollToResult: Boolean, recordInHistory: Boolean) {
        try {
            val result = GroupingEngine.generate(
                poolText = rolePoolInput.text?.toString().orEmpty(),
                lastGameText = lastGameInput.text?.toString().orEmpty(),
                allowDuplicate = allowDuplicateSwitch.isChecked,
            )
            currentResult = result
            swappedSlots.clear()
            currentHistoryId = null
            if (recordInHistory) record(result, swappedSlots)
            renderResult(result)
            generateButton.performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)

            if (scrollToResult) {
                resultCard.post {
                    scrollView.smoothScrollTo(0, resultCard.bottom)
                }
            }
        } catch (error: GroupingException) {
            if (currentResult == null) setupGenerateButton.visibility = View.VISIBLE
            MaterialAlertDialogBuilder(this)
                .setTitle(R.string.error_title)
                .setMessage(error.message)
                .setPositiveButton(R.string.confirm, null)
                .show()
        }
    }

    private fun renderResult(result: GroupingResult) {
        seedText.text = getString(R.string.seed_format, result.seed)
        playersAText.text = result.playersA.joinToString("，")
        playersBText.text = result.playersB.joinToString("，")
        renderRoleChips(rolesAContainer, result.rolesA, ResultTeam.A, R.color.team_a, R.color.team_a_container)
        renderRoleChips(rolesBContainer, result.rolesB, ResultTeam.B, R.color.team_b, R.color.team_b_container)
        setupGenerateButton.visibility = View.GONE
        resultCard.visibility = View.VISIBLE
    }

    private fun renderRoleChips(
        container: GridLayout,
        roles: List<String>,
        team: ResultTeam,
        teamColor: Int,
        containerColor: Int,
    ) {
        container.removeAllViews()
        roles.forEachIndexed { index, role ->
            val slot = RoleSlot(team, index)
            val wasSwapped = slot in swappedSlots
            val chip = Chip(this).apply {
                text = if (wasSwapped) "↻ $role" else role
                isCheckable = false
                isClickable = true
                gravity = Gravity.CENTER
                textAlignment = View.TEXT_ALIGNMENT_CENTER
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
                minHeight = dp(48)
                chipBackgroundColor = ColorStateList.valueOf(
                    ContextCompat.getColor(
                        this@MainActivity,
                        if (wasSwapped) R.color.swapped else containerColor,
                    )
                )
                setTextColor(
                    ContextCompat.getColor(
                        this@MainActivity,
                        if (wasSwapped) android.R.color.white else teamColor,
                    )
                )
                contentDescription = "$role，点按随机更换同一分路角色"
                setOnClickListener { swapRole(team, index) }
            }
            chip.layoutParams = GridLayout.LayoutParams().apply {
                width = 0
                height = GridLayout.LayoutParams.WRAP_CONTENT
                columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                setMargins(dp(4), dp(4), dp(4), dp(4))
            }
            container.addView(chip)
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun swapRole(team: ResultTeam, index: Int) {
        val result = currentResult ?: return
        val candidates = GroupingEngine.replacementCandidates(
            result = result,
            team = team,
            index = index,
            poolText = rolePoolInput.text?.toString().orEmpty(),
            allowDuplicate = allowDuplicateSwitch.isChecked,
        )
        val replacement = candidates.randomOrNull()
        val updated = replacement?.let { result.replacingRole(team, index, it) }

        if (updated == null) {
            Snackbar.make(resultCard, R.string.swap_unavailable, Snackbar.LENGTH_LONG).show()
            return
        }

        currentResult = updated
        swappedSlots += RoleSlot(team, index)
        updateHistory(updated, swappedSlots)
        renderResult(updated)
        resultCard.performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)
    }

    private fun record(result: GroupingResult, swapped: Set<RoleSlot>) {
        val entry = GameHistoryEntry(
            id = UUID.randomUUID().toString(),
            createdAt = System.currentTimeMillis(),
            result = result,
            swappedSlots = swapped.toSet(),
        )
        history.add(0, entry)
        if (history.size > GroupingEngine.HISTORY_LIMIT) {
            history = history.take(GroupingEngine.HISTORY_LIMIT).toMutableList()
        }
        currentHistoryId = entry.id
        saveHistory()
        renderHistory()
    }

    private fun updateHistory(result: GroupingResult, swapped: Set<RoleSlot>) {
        val index = currentHistoryId?.let { id -> history.indexOfFirst { it.id == id } } ?: -1
        if (index < 0) {
            record(result, swapped)
            return
        }
        history[index] = history[index].copy(result = result, swappedSlots = swapped.toSet())
        saveHistory()
        renderHistory()
    }

    private fun renderHistory() {
        historyHeading.text = getString(R.string.history_heading, history.size)
        historyContainer.removeAllViews()
        historyCard.visibility = if (history.isEmpty()) View.GONE else View.VISIBLE

        val formatter = DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT)
        history.forEachIndexed { index, entry ->
            val textView = TextView(this).apply {
                val rolesA = markedRoles(entry, ResultTeam.A, entry.result.rolesA)
                val rolesB = markedRoles(entry, ResultTeam.B, entry.result.rolesB)
                text = buildString {
                    append(formatter.format(Date(entry.createdAt)))
                    append("  ·  ")
                    append(getString(R.string.seed_format, entry.result.seed))
                    append("\nA  ")
                    append(entry.result.playersA.joinToString("，"))
                    append("  |  ")
                    append(rolesA)
                    append("\nB  ")
                    append(entry.result.playersB.joinToString("，"))
                    append("  |  ")
                    append(rolesB)
                }
                textSize = 13f
                setPadding(0, 12, 0, 12)
            }
            historyContainer.addView(textView)
            if (index != history.lastIndex) {
                historyContainer.addView(View(this).apply {
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1)
                    setBackgroundColor(ContextCompat.getColor(this@MainActivity, android.R.color.darker_gray))
                })
            }
        }
    }

    private fun markedRoles(entry: GameHistoryEntry, team: ResultTeam, roles: List<String>): String =
        roles.mapIndexed { index, role ->
            if (RoleSlot(team, index) in entry.swappedSlots) "↻$role" else role
        }.joinToString("，")

    private fun saveHistory() {
        val array = JSONArray()
        history.forEach { entry ->
            array.put(JSONObject().apply {
                put("id", entry.id)
                put("createdAt", entry.createdAt)
                put("seed", entry.result.seed)
                put("playersA", JSONArray(entry.result.playersA))
                put("playersB", JSONArray(entry.result.playersB))
                put("rolesA", JSONArray(entry.result.rolesA))
                put("rolesB", JSONArray(entry.result.rolesB))
                put("swappedSlots", JSONArray(entry.swappedSlots.map { "${it.team.name}:${it.index}" }))
            })
        }
        preferences.edit { putString(KEY_GAME_HISTORY, array.toString()) }
    }

    private fun loadHistory(): List<GameHistoryEntry> {
        val encoded = preferences.getString(KEY_GAME_HISTORY, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(encoded)
            buildList {
                for (index in 0 until array.length()) {
                    val value = array.getJSONObject(index)
                    val result = GroupingResult(
                        seed = value.getLong("seed"),
                        playersA = value.getJSONArray("playersA").intList(),
                        playersB = value.getJSONArray("playersB").intList(),
                        rolesA = value.getJSONArray("rolesA").stringList(),
                        rolesB = value.getJSONArray("rolesB").stringList(),
                    )
                    val slots = value.optJSONArray("swappedSlots")?.stringList().orEmpty().mapNotNull { raw ->
                        val parts = raw.split(':')
                        val team = parts.getOrNull(0)?.let { runCatching { ResultTeam.valueOf(it) }.getOrNull() }
                        val slotIndex = parts.getOrNull(1)?.toIntOrNull()
                        if (team != null && slotIndex != null) RoleSlot(team, slotIndex) else null
                    }.toSet()
                    add(
                        GameHistoryEntry(
                            id = value.getString("id"),
                            createdAt = value.getLong("createdAt"),
                            result = result,
                            swappedSlots = slots,
                        )
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    private fun copyResult() {
        val result = currentResult ?: return
        val clipboard = getSystemService(ClipboardManager::class.java)
        clipboard.setPrimaryClip(ClipData.newPlainText(getString(R.string.result_title), result.formattedText))
        copyButton.text = getString(R.string.copied_short)
        copyButton.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
        Snackbar.make(copyButton, R.string.copied, Snackbar.LENGTH_SHORT).show()
        copyButton.postDelayed({ copyButton.setText(R.string.copy_short) }, 2_000)
    }

    private companion object {
        const val PREFERENCES_NAME = "moba_random_preferences"
        const val KEY_ROLE_POOL = "moba_role_pool"
        const val KEY_GAME_HISTORY = "moba_game_history_v1"
    }
}

private data class GameHistoryEntry(
    val id: String,
    val createdAt: Long,
    val result: GroupingResult,
    val swappedSlots: Set<RoleSlot>,
)

private fun JSONArray.intList(): List<Int> = buildList {
    for (index in 0 until length()) add(getInt(index))
}

private fun JSONArray.stringList(): List<String> = buildList {
    for (index in 0 until length()) add(getString(index))
}
