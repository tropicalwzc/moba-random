package com.example.mobarandom

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.button.MaterialButton
import com.google.android.material.card.MaterialCardView
import com.google.android.material.chip.Chip
import com.google.android.material.chip.ChipGroup
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.snackbar.Snackbar
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout
import kotlin.math.min

class Bo3BoardView(
    context: Context,
    private val store: Bo3SeriesStore,
    private val onOpenSettings: () -> Unit,
) : LinearLayout(context) {
    private val preferences = context.getSharedPreferences(
        RoleWeightStorage.PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )
    private val avatarRepository = Bo3AvatarRepository(context)
    private val density = resources.displayMetrics.density
    private val layoutMode = Bo3LayoutMode.fromConfiguration(resources.configuration)
    private val isCompact = layoutMode == Bo3LayoutMode.COMPACT

    private var pool = loadPool()
    private var selectedRole = "all"
    private var searchText = ""
    private var onlyAvailable = false
    private var showsSearch = false

    private lateinit var content: LinearLayout
    private lateinit var headerHost: LinearLayout
    private var timelineHost: LinearLayout? = null
    private lateinit var lineupHost: LinearLayout
    private lateinit var poolBarHost: LinearLayout
    private lateinit var gridContainer: FrameLayout
    private lateinit var grid: RecyclerView
    private lateinit var emptyView: TextView
    private lateinit var statsView: TextView
    private lateinit var searchHost: LinearLayout
    private lateinit var searchField: TextInputEditText
    private lateinit var availabilityButton: MaterialButton
    private var teamAHost: LinearLayout? = null
    private var teamBHost: LinearLayout? = null
    private lateinit var adapter: Bo3HeroAdapter

    init {
        orientation = VERTICAL
        setBackgroundColor(ContextCompat.getColor(context, R.color.surface))
        addView(buildToolbar(), LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)))
        content = LinearLayout(context).apply {
            orientation = VERTICAL
            layoutParams = LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
        }
        addView(content)
        render()
    }

    fun refreshPool() {
        store.reload()
        pool = loadPool()
        if (selectedRole != "all" && pool.categories.none { it.name == selectedRole }) {
            selectedRole = "all"
        }
        render()
    }

    private fun loadPool(): Bo3Pool =
        Bo3Pool(
            preferences.getString(RoleWeightStorage.KEY_ROLE_POOL, GroupingEngine.DEFAULT_POOL_TEXT)
                .orEmpty(),
        )

    private fun buildToolbar(): MaterialToolbar = MaterialToolbar(context).apply {
        title = context.getString(R.string.bo3_title)
        setTitleTextColor(themeColor(com.google.android.material.R.attr.colorOnSurface))
        inflateMenu(R.menu.menu_bo3)
        setOnMenuItemClickListener { item ->
            when (item.itemId) {
                R.id.action_rules -> {
                    context.startActivity(Intent(context, Bo3RulesActivity::class.java))
                    true
                }
                R.id.action_undo -> {
                    if (store.undo()) render() else snackbar(context.getString(R.string.bo3_waiting))
                    true
                }
                R.id.action_reset -> {
                    confirmReset()
                    true
                }
                R.id.action_history -> {
                    showHistory()
                    true
                }
                R.id.action_settings -> {
                    onOpenSettings()
                    true
                }
                else -> false
            }
        }
    }

    private fun render() {
        val scrollState = if (::grid.isInitialized) grid.layoutManager?.onSaveInstanceState() else null
        val searchHadFocus = if (::searchField.isInitialized) searchField.hasFocus() else false
        content.removeAllViews()
        headerHost = LinearLayout(context).apply { orientation = VERTICAL }
        lineupHost = LinearLayout(context).apply { orientation = VERTICAL }
        poolBarHost = LinearLayout(context).apply { orientation = VERTICAL }
        timelineHost = null
        teamAHost = null
        teamBHost = null

        when (layoutMode) {
            Bo3LayoutMode.COMPACT -> content.addView(
                buildCompact(),
                LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
            )
            Bo3LayoutMode.TWO_COLUMN -> content.addView(
                buildTwoColumn(),
                LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
            )
            Bo3LayoutMode.THREE_COLUMN -> content.addView(
                buildThreeColumn(),
                LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
            )
        }
        updateToolbar()
        buildHeader()
        updateGrid()
        if (scrollState != null) grid.layoutManager?.onRestoreInstanceState(scrollState)
        if (searchHadFocus) searchField.requestFocus()
    }

    private fun buildCompact(): View {
        val root = LinearLayout(context).apply {
            orientation = VERTICAL
            setPadding(dp(14), dp(8), dp(14), 0)
        }
        root.addView(
            headerHost,
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT),
        )
        root.addView(
            lineupHost,
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8) },
        )
        root.addView(
            poolBarHost,
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8) },
        )
        val gridLayout = buildGridContainer()
        root.addView(gridLayout, LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f).apply {
            topMargin = dp(8)
        })
        return root
    }

    private fun buildTwoColumn(): View {
        val root = LinearLayout(context).apply {
            orientation = HORIZONTAL
            setPadding(dp(10), dp(8), dp(10), 8)
        }
        val leftWidth = min(dp(360), (resources.configuration.screenWidthDp * density * 0.44f).toInt())
        val left = LinearLayout(context).apply {
            orientation = VERTICAL
            setPadding(0, 0, dp(8), 0)
        }
        left.addView(
            headerHost,
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT),
        )
        timelineHost = LinearLayout(context).apply { orientation = VERTICAL }
        left.addView(
            timelineHost,
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8) },
        )
        left.addView(
            lineupHost,
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8) },
        )
        left.addView(
            poolBarHost,
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8) },
        )
        val scroll = ScrollView(context).apply {
            isFillViewport = true
            addView(left)
            layoutParams = LayoutParams(leftWidth, ViewGroup.LayoutParams.MATCH_PARENT)
        }
        root.addView(scroll)
        root.addView(
            buildGridContainer(),
            LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f).apply { marginStart = dp(4) },
        )
        return root
    }

    private fun buildThreeColumn(): View {
        val root = LinearLayout(context).apply {
            orientation = HORIZONTAL
            setPadding(dp(10), dp(8), dp(10), 8)
        }
        teamAHost = LinearLayout(context).apply { orientation = VERTICAL }
        teamBHost = LinearLayout(context).apply { orientation = VERTICAL }
        root.addView(scrollHost(teamAHost!!, dp(220)))
        val center = LinearLayout(context).apply {
            orientation = VERTICAL
            setPadding(dp(8), 0, dp(8), 0)
        }
        center.addView(
            headerHost,
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT),
        )
        timelineHost = LinearLayout(context).apply { orientation = VERTICAL }
        center.addView(
            timelineHost,
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8) },
        )
        center.addView(
            poolBarHost,
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8) },
        )
        center.addView(
            buildGridContainer(),
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f).apply { topMargin = dp(8) },
        )
        root.addView(center, LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f))
        root.addView(scrollHost(teamBHost!!, dp(220)))
        return root
    }

    private fun scrollHost(host: LinearLayout, width: Int): ScrollView = ScrollView(context).apply {
        layoutParams = LayoutParams(width, ViewGroup.LayoutParams.MATCH_PARENT)
        addView(host)
    }

    private fun updateToolbar() {
        val toolbar = getChildAt(0) as? MaterialToolbar ?: return
        toolbar.menu.findItem(R.id.action_undo)?.isEnabled = store.canUndo
        toolbar.menu.findItem(R.id.action_reset)?.isEnabled = store.hasProgress
        toolbar.menu.findItem(R.id.action_history)?.isVisible = store.series.currentGame > 0
    }

    private fun buildGridContainer(): FrameLayout {
        gridContainer = FrameLayout(context)
        grid = RecyclerView(context).apply {
            layoutManager = GridLayoutManager(context, gridSpanCount())
            setHasFixedSize(false)
            clipToPadding = false
            setPadding(0, 0, 0, dp(84))
        }
        adapter = Bo3HeroAdapter(
            context = context,
            repository = avatarRepository,
            avatarSizePx = dp(if (isCompact) 56 else 60),
            onClick = ::handleHeroTap,
        )
        grid.adapter = adapter
        gridContainer.addView(grid, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        ))
        emptyView = TextView(context).apply {
            text = "没有符合条件的角色"
            gravity = Gravity.CENTER
            setTextColor(themeColor(com.google.android.material.R.attr.colorOnSurfaceVariant))
            visibility = View.GONE
        }
        gridContainer.addView(emptyView, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER,
        ))
        return gridContainer
    }

    private fun gridSpanCount(): Int = when (layoutMode) {
        Bo3LayoutMode.COMPACT -> if (resources.configuration.screenWidthDp < 380) 4 else 5
        Bo3LayoutMode.TWO_COLUMN -> 6
        Bo3LayoutMode.THREE_COLUMN -> 5
    }

    private fun updateGrid() {
        val heroes = pool.allHeroes.filter { hero ->
            (selectedRole == "all" || pool.role(hero) == selectedRole) &&
                (searchText.isBlank() || hero.contains(searchText, ignoreCase = true)) &&
                (!onlyAvailable || Bo3DraftEngine.availability(hero, store.series).isAvailable)
        }
        adapter.submit(
            heroes.map { hero ->
                val availability = Bo3DraftEngine.availability(hero, store.series)
                Bo3HeroAdapter.Item(
                    name = hero,
                    role = pool.role(hero).orEmpty(),
                    lockLabel = when (availability) {
                        is Bo3Availability.CurrentGame -> context.getString(R.string.bo3_used_current)
                        is Bo3Availability.GlobalPick -> context.getString(
                            R.string.bo3_used_game,
                            availability.game,
                        )
                        else -> null
                    },
                    available = availability.isAvailable,
                )
            },
        )
        emptyView.visibility = if (heroes.isEmpty()) View.VISIBLE else View.GONE
        statsView.text = context.getString(
            R.string.bo3_used_stats,
            Bo3DraftEngine.currentGameHeroes(store.series).size,
            Bo3DraftEngine.pickedHeroes(store.series, maxOf(0, store.series.currentGame - 1)).size,
            pool.allHeroes.count { Bo3DraftEngine.availability(it, store.series).isAvailable },
        )
    }

    private fun handleHeroTap(item: Bo3HeroAdapter.Item) {
        if (Bo3DraftEngine.currentStep(store.series) == null) {
            snackbar(context.getString(R.string.bo3_waiting))
            return
        }
        val availability = Bo3DraftEngine.availability(item.name, store.series)
        if (!availability.isAvailable) {
            snackbar(Bo3DraftEngine.lockMessage(availability, store.series))
            return
        }
        runCatching {
            store.choose(item.name, pool.role(item.name).orEmpty())
        }.onSuccess {
            performHapticFeedback(android.view.HapticFeedbackConstants.CONTEXT_CLICK)
            render()
        }.onFailure { snackbar(it.message ?: context.getString(R.string.bo3_locked)) }
    }

    private fun confirmReset() {
        MaterialAlertDialogBuilder(context)
            .setTitle(R.string.bo3_reset_title)
            .setMessage(R.string.bo3_reset_message)
            .setNegativeButton(R.string.bo3_cancel, null)
            .setPositiveButton(R.string.bo3_reset_confirm) { _, _ ->
                store.reset()
                render()
                snackbar(context.getString(R.string.bo3_reset_toast))
            }
            .show()
    }

    private fun showHistory() {
        val series = store.series
        val body = LinearLayout(context).apply {
            orientation = VERTICAL
            setPadding(dp(20), dp(8), dp(20), 0)
        }
        val completed = series.games.take(maxOf(0, series.currentGame - 1))
        if (completed.isEmpty()) {
            body.addView(textView(context.getString(R.string.bo3_empty_history), 16f, bold = true))
            body.addView(textView(context.getString(R.string.bo3_history_empty_hint), 13f, secondary = true))
        } else {
            completed.forEachIndexed { index, game ->
                val header = context.getString(
                    R.string.bo3_history_game,
                    index + 1,
                    when (game.winner) {
                        Bo3Team.A -> series.teamNames.name(Bo3Team.A) + " " + context.getString(R.string.bo3_history_win)
                        Bo3Team.B -> series.teamNames.name(Bo3Team.B) + " " + context.getString(R.string.bo3_history_win)
                        null -> context.getString(R.string.bo3_history_pending)
                    },
                )
                body.addView(textView(header, 15f, bold = true).apply { setPadding(0, dp(10), 0, dp(4)) })
                body.addView(textView(historyActions(game, series), 13f, secondary = true))
            }
        }
        MaterialAlertDialogBuilder(context)
            .setTitle(R.string.bo3_history_title)
            .setView(body)
            .setPositiveButton(R.string.bo3_history_close, null)
            .show()
    }

    private fun historyActions(game: Bo3Game, series: Bo3Series): String = buildString {
        Bo3Team.entries.forEach { team ->
            val actions = game.actions.filter { it.team == team }
            if (actions.isNotEmpty()) {
                append(series.teamNames.name(team))
                append("：")
                append(actions.joinToString("、") { "${it.type.shortLabel} ${it.hero}" })
                append("\n")
            }
        }
    }.trim()

    private fun snackbar(message: String) {
        Snackbar.make(this, message, Snackbar.LENGTH_LONG).show()
    }

    private fun textView(
        value: String,
        size: Float,
        bold: Boolean = false,
        secondary: Boolean = false,
        color: Int? = null,
    ): TextView = TextView(context).apply {
        text = value
        textSize = size
        if (bold) setTypeface(typeface, Typeface.BOLD)
        setTextColor(
            color ?: themeColor(
                if (secondary) com.google.android.material.R.attr.colorOnSurfaceVariant
                else com.google.android.material.R.attr.colorOnSurface,
            ),
        )
    }

    private fun themeColor(attr: Int): Int {
        val value = TypedValue()
        context.theme.resolveAttribute(attr, value, true)
        return value.data
    }

    private fun card(): MaterialCardView = MaterialCardView(context).apply {
        radius = dp(18).toFloat()
        cardElevation = 0f
        strokeWidth = 0
        setCardBackgroundColor(themeColor(com.google.android.material.R.attr.colorSurfaceContainer))
    }

    private fun marginTop(value: Int): LayoutParams =
        LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(value)
        }

    private fun dp(value: Int): Int = (value * density).toInt()

    private fun headerCard(): View {
        val card = card()
        val body = LinearLayout(context).apply {
            orientation = VERTICAL
            setPadding(dp(if (isCompact) 10 else 16), dp(if (isCompact) 10 else 16), dp(if (isCompact) 10 else 16), dp(if (isCompact) 10 else 16))
        }
        body.addView(
            scoreRow(),
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT),
        )
        if (!isCompact) {
            body.addView(View(context).apply {
                setBackgroundColor(themeColor(com.google.android.material.R.attr.colorOutlineVariant))
            }, LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(1)).apply {
                topMargin = dp(12)
                bottomMargin = dp(12)
            })
        }
        body.addView(statusSection(), LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(if (isCompact) 6 else 12) })
        if (isCompact) {
            buildTimeline(true)?.let { body.addView(it, marginTop(6)) }
        }
        card.addView(body, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        if (!isCompact) return card

        val frame = FrameLayout(context)
        frame.addView(card, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { topMargin = dp(8) })
        frame.addView(gameBadge(), FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.END,
        ).apply { topMargin = 0; marginEnd = dp(8) })
        return frame
    }

    private fun gameBadge(): TextView = TextView(context).apply {
        text = if (store.series.currentGame > 0) {
            context.getString(R.string.bo3_current_game, store.series.currentGame)
        } else {
            "BO3"
        }
        textSize = 9f
        setTypeface(typeface, Typeface.BOLD)
        setTextColor(Bo3Palette.GOLD)
        setPadding(dp(8), dp(3), dp(8), dp(3))
        background = GradientDrawable().apply {
            cornerRadius = dp(20).toFloat()
            setColor(0xFFF9F2DE.toInt())
            setStroke(dp(1), 0x55C9A24A)
        }
    }

    private fun scoreRow(): View {
        val row = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(if (isCompact) 2 else 4), 0, 0)
        }
        row.addView(teamSide(Bo3Team.A), LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val center = LinearLayout(context).apply {
            orientation = VERTICAL
            gravity = Gravity.CENTER
        }
        center.addView(seatRow(), LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        val score = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER
        }
        score.addView(textView("${store.series.winsA}", if (isCompact) 24f else 28f, bold = true, color = Bo3Palette.TEAM_A))
        score.addView(textView(" : ", if (isCompact) 20f else 24f, bold = true, secondary = true))
        score.addView(textView("${store.series.winsB}", if (isCompact) 24f else 28f, bold = true, color = Bo3Palette.TEAM_B))
        center.addView(score, LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        if (!isCompact) {
            center.addView(
                textView(
                    if (store.series.currentGame == 0) "BO3 · 全局 BP" else context.getString(R.string.bo3_current_game, store.series.currentGame),
                    10f,
                    secondary = true,
                ),
            )
        }
        row.addView(center, LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        row.addView(teamSide(Bo3Team.B), LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        return row
    }

    private fun teamSide(team: Bo3Team): View {
        val box = LinearLayout(context).apply {
            orientation = VERTICAL
            gravity = if (team == Bo3Team.A) Gravity.START else Gravity.END
        }
        box.addView(textView(team.sideLabel, 8f, bold = true, color = Bo3Palette.team(team)), LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        val nameRow = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        if (team == Bo3Team.A) nameRow.addView(winPips(team))
        nameRow.addView(textView(store.series.teamNames.name(team), if (isCompact) 14f else 16f, bold = true))
        if (team == Bo3Team.B) nameRow.addView(winPips(team))
        box.addView(nameRow, LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        return box
    }

    private fun winPips(team: Bo3Team): View {
        val wins = if (team == Bo3Team.A) store.series.winsA else store.series.winsB
        val row = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        repeat(2) { index ->
            row.addView(View(context).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(if (index < wins) Bo3Palette.team(team) else 0x44222222)
                }
            }, LayoutParams(dp(7), dp(7)).apply { marginEnd = dp(4) })
        }
        return row.apply { setPadding(0, 0, dp(6), 0) }
    }

    private fun seatRow(): View {
        val row = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(2))
        }
        row.addView(seatPills(store.series.seats?.a), LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        row.addView(
            View(context),
            LayoutParams(dp(12), dp(1)),
        )
        row.addView(seatPills(store.series.seats?.b), LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        return row
    }

    private fun seatPills(seats: List<Int>?): View {
        val row = LinearLayout(context).apply { orientation = HORIZONTAL }
        if (seats == null || seats.size != 4) {
            row.addView(textView(context.getString(R.string.bo3_seats_waiting), 10f, secondary = true))
            return row
        }
        seats.forEach { seat ->
            row.addView(textView("$seat", 11f, bold = true, color = Bo3Palette.GOLD).apply {
                gravity = Gravity.CENTER
                background = GradientDrawable().apply {
                    cornerRadius = dp(5).toFloat()
                    setColor(0x22C9A24A)
                    setStroke(dp(1), 0x33C9A24A)
                }
            }, LayoutParams(dp(22), dp(22)).apply { marginEnd = dp(2) })
        }
        return row
    }

    private fun statusSection(): View {
        val series = store.series
        val game = series.activeGame
        val sequence = if (series.currentGame == 0) {
            Bo3DraftEngine.stepSequence
        } else {
            Bo3DraftEngine.activeSequence(series)
        }
        val draftComplete = game != null && game.started && game.actions.size >= sequence.size
        return when {
            series.isSeriesOver && series.champion != null -> championState(series.champion!!)
            draftComplete && game?.winner == null -> winnerPrompt()
            draftComplete && game?.winner != null -> gameCompleteState(game.winner!!)
            Bo3DraftEngine.currentStep(series) != null -> currentTurnState(Bo3DraftEngine.currentStep(series)!!)
            else -> startState()
        }
    }

    private fun startState(): View {
        val box = LinearLayout(context).apply { orientation = VERTICAL }
        if (!isCompact) {
            box.addView(textView("BO3 · 全局 BP", 17f, bold = true).apply { setPadding(0, 0, 0, dp(4)) })
            box.addView(
                textView(
                    context.getString(if (store.series.noBanGame3) R.string.bo3_start_hint_no_ban else R.string.bo3_start_hint),
                    12f,
                    secondary = true,
                ),
            )
        }
        if (pool.total < Bo3DraftEngine.MINIMUM_POOL_FOR_GAME) {
            box.addView(
                textView(
                    context.getString(R.string.bo3_pool_too_small, pool.total, Bo3DraftEngine.MINIMUM_POOL_FOR_GAME),
                    12f,
                    color = 0xFFB3261E.toInt(),
                ).apply { setPadding(0, dp(6), 0, dp(4)) },
            )
            box.addView(button(context.getString(R.string.bo3_edit_pool), primary = false) { onOpenSettings() }, marginTop(6))
        } else {
            box.addView(button(context.getString(R.string.bo3_start_game), primary = true) { performStart() }, marginTop(if (isCompact) 6 else 10))
        }
        return box
    }

    private fun currentTurnState(stepPair: Pair<Bo3Step, Int>): View {
        val (step, index) = stepPair
        val game = store.series.activeGame ?: return startState()
        val sequence = Bo3DraftEngine.activeSequence(store.series)
        val done = game.actions.count { it.team == step.team && it.type == step.type }
        val cap = if (step.type == Bo3ActionType.BAN) 2 else 4
        val box = LinearLayout(context).apply { orientation = VERTICAL }
        val row = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.TOP
        }
        row.addView(teamBadge(step.team, if (isCompact) 30 else 38), LayoutParams(dp(if (isCompact) 30 else 38), dp(if (isCompact) 30 else 38)).apply {
            marginEnd = dp(if (isCompact) 8 else 11)
        })
        val info = LinearLayout(context).apply {
            orientation = VERTICAL
            layoutParams = LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        info.addView(textView(
            if (isCompact) context.getString(R.string.bo3_step_progress_compact, index + 1, sequence.size)
            else context.getString(R.string.bo3_step_progress, store.series.currentGame, index + 1, sequence.size),
            9f,
            bold = true,
            secondary = true,
        ))
        info.addView(textView(
            context.getString(R.string.bo3_current_turn, store.series.teamNames.name(step.team), step.type.label),
            if (isCompact) 15f else 19f,
            bold = true,
        ))
        if (!isCompact) {
            info.addView(textView("点击下方角色完成 ${step.type.shortLabel} · 分类仅为推荐位置", 12f, secondary = true))
        }
        row.addView(info)
        val progress = LinearLayout(context).apply {
            orientation = VERTICAL
            gravity = Gravity.END
        }
        progress.addView(textView(if (step.type == Bo3ActionType.BAN) "BAN" else "PICK", 8f, bold = true, color = Bo3Palette.team(step.team)))
        progress.addView(textView("${done + 1} / $cap", if (isCompact) 12f else 14f, bold = true))
        row.addView(progress)
        box.addView(row)
        return box
    }

    private fun winnerPrompt(): View {
        val box = LinearLayout(context).apply { orientation = VERTICAL }
        if (!isCompact) {
            box.addView(textView("第 ${store.series.currentGame} 局 · 征召完成", 10f, bold = true, color = Bo3Palette.GOLD))
        }
        box.addView(textView(context.getString(R.string.bo3_pending_winner), 16f, bold = true))
        if (!isCompact) box.addView(textView("比分自动累计，先胜 2 局者赢得 BO3", 12f, secondary = true))
        val row = LinearLayout(context).apply { orientation = HORIZONTAL }
        row.addView(
            button(store.series.teamNames.name(Bo3Team.A) + " 获胜", primary = false, color = Bo3Palette.TEAM_A) {
                performWinner(Bo3Team.A)
            },
            LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )
        row.addView(
            button(store.series.teamNames.name(Bo3Team.B) + " 获胜", primary = false, color = Bo3Palette.TEAM_B) {
                performWinner(Bo3Team.B)
            },
            LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { marginStart = dp(8) },
        )
        box.addView(row, marginTop(6))
        return box
    }

    private fun gameCompleteState(winner: Bo3Team): View {
        val box = LinearLayout(context).apply { orientation = VERTICAL }
        box.addView(textView(context.getString(R.string.bo3_game_over, store.series.teamNames.name(winner)), 16f, bold = true, color = Bo3Palette.team(winner)))
        if (!isCompact) {
            box.addView(textView(
                "当前比分 ${store.series.winsA} : ${store.series.winsB} · " +
                    context.getString(if (store.series.currentGame == 2 && store.series.noBanGame3) R.string.bo3_next_no_ban else R.string.bo3_next_full),
                12f,
                secondary = true,
            ))
        }
        if (Bo3DraftEngine.canStartNextGame(store.series, pool)) {
            box.addView(button(context.getString(R.string.bo3_next_game), primary = true) { performStart() }, marginTop(6))
        } else if (store.series.currentGame < 3) {
            val remaining = Bo3DraftEngine.remainingPicksAvailable(store.series, pool)
            box.addView(
                textView(
                    context.getString(R.string.bo3_remaining_short, remaining, Bo3DraftEngine.nextGameRequirement(store.series)),
                    12f,
                    color = 0xFFB3261E.toInt(),
                ).apply { setPadding(0, dp(6), 0, 0) },
            )
        }
        return box
    }

    private fun championState(champion: Bo3Team): View {
        val box = LinearLayout(context).apply { orientation = VERTICAL }
        if (!isCompact) box.addView(textView(context.getString(R.string.bo3_series_over), 10f, bold = true, color = Bo3Palette.GOLD))
        box.addView(textView(context.getString(R.string.bo3_champion, store.series.teamNames.name(champion)), 16f, bold = true))
        box.addView(textView(context.getString(R.string.bo3_final_score, store.series.winsA, store.series.winsB), 12f, secondary = true))
        val row = LinearLayout(context).apply { orientation = HORIZONTAL }
        row.addView(
            button(context.getString(R.string.bo3_reopen_winner), primary = false) {
                if (store.reopenWinner()) render()
            },
            LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )
        row.addView(
            button(context.getString(R.string.bo3_new_series), primary = false) { confirmReset() },
            LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { marginStart = dp(8) },
        )
        box.addView(row, marginTop(6))
        return box
    }

    private fun teamBadge(team: Bo3Team, size: Int): View = TextView(context).apply {
        text = team.shortLabel
        gravity = Gravity.CENTER
        setTypeface(typeface, Typeface.BOLD)
        setTextColor(Color.WHITE)
        textSize = if (size < 34) 13f else 16f
        background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Bo3Palette.team(team))
        }
    }

    private fun button(
        label: String,
        primary: Boolean,
        color: Int? = null,
        onClick: () -> Unit,
    ): MaterialButton = MaterialButton(context).apply {
        text = label
        textSize = 13f
        isAllCaps = false
        minHeight = dp(40)
        insetTop = 0
        insetBottom = 0
        setOnClickListener { onClick() }
        if (primary) {
            backgroundTintList = android.content.res.ColorStateList.valueOf(
                color ?: ContextCompat.getColor(context, R.color.primary),
            )
            setTextColor(Color.WHITE)
        } else {
            backgroundTintList = android.content.res.ColorStateList.valueOf(0x00000000)
            strokeWidth = dp(1)
            strokeColor = android.content.res.ColorStateList.valueOf(color ?: 0x55303030)
            setTextColor(color ?: themeColor(com.google.android.material.R.attr.colorOnSurface))
        }
    }

    private fun performStart() {
        runCatching { store.startGame(pool) }
            .onSuccess { render() }
            .onFailure { snackbar(it.message ?: "无法开始下一局") }
    }

    private fun performWinner(team: Bo3Team) {
        runCatching { store.setWinner(team) }
            .onSuccess { render() }
            .onFailure { snackbar(it.message ?: "无法判定胜者") }
    }

    private fun buildTimeline(compact: Boolean): View? {
        val series = store.series
        val sequence = if (series.currentGame == 0) null else Bo3DraftEngine.activeSequence(series)
        if (sequence == null && !compact) return null
        val steps = sequence ?: Bo3DraftEngine.stepSequence
        val actions = series.activeGame?.actions.orEmpty()
        val currentIndex = Bo3DraftEngine.currentStep(series)?.second

        val scroll = HorizontalScrollView(context).apply {
            isHorizontalScrollBarEnabled = false
            setPadding(0, dp(2), 0, dp(2))
        }
        val row = LinearLayout(context).apply {
            orientation = HORIZONTAL
            setPadding(0, 0, dp(2), 0)
        }
        steps.forEachIndexed { index, step ->
            val action = actions.getOrNull(index)
            val current = index == currentIndex
            val chip = LinearLayout(context).apply {
                orientation = VERTICAL
                gravity = Gravity.CENTER
                setPadding(dp(4), dp(3), dp(4), dp(3))
                background = GradientDrawable().apply {
                    cornerRadius = dp(7).toFloat()
                    setColor(
                        when {
                            current -> 0x22C9A24A
                            action != null -> withAlpha(Bo3Palette.team(step.team), 0.10f)
                            else -> 0x11000000
                        },
                    )
                    setStroke(
                        if (current) dp(1) else dp(1),
                        if (current) Bo3Palette.GOLD else withAlpha(Bo3Palette.team(step.team), if (action != null) 0.28f else 0.10f),
                    )
                }
            }
            val label = LinearLayout(context).apply { orientation = HORIZONTAL; gravity = Gravity.CENTER }
            label.addView(textView(if (index < 9) "0${index + 1}" else "${index + 1}", 8f, bold = true, secondary = true))
            label.addView(textView("${step.team.shortLabel}${step.type.shortLabel}", 8f, bold = true, color = Bo3Palette.team(step.team)))
            chip.addView(label)
            chip.addView(
                textView(
                    action?.hero ?: if (current) "选择中" else "—",
                    9f,
                    bold = current,
                    secondary = action == null && !current,
                ),
            )
            row.addView(chip, LayoutParams(if (compact) dp(52) else dp(58), dp(38)).apply {
                marginEnd = dp(4)
            })
        }
        scroll.addView(row)
        if (compact) return scroll

        val card = card()
        val body = LinearLayout(context).apply {
            orientation = VERTICAL
            setPadding(dp(12), dp(10), dp(12), dp(10))
        }
        val header = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        header.addView(textView("征召顺序", 11f, bold = true, secondary = true), LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        header.addView(
            textView(
                when {
                    currentIndex != null -> context.getString(R.string.bo3_step_progress, series.currentGame, currentIndex + 1, steps.size)
                    series.currentGame > 0 -> context.getString(R.string.bo3_current_game, series.currentGame) + " · ${steps.size} 手"
                    else -> "第 1 局 A 先手 · 第 2 局 B 先手"
                },
                10f,
                secondary = true,
            ),
        )
        body.addView(header)
        body.addView(scroll, marginTop(6))
        card.addView(body, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        return card
    }

    private fun renderLineup() {
        lineupHost.removeAllViews()
        val card = card()
        val body = LinearLayout(context).apply {
            orientation = VERTICAL
            setPadding(dp(12), dp(8), dp(12), dp(8))
        }
        body.addView(lineupRow(Bo3Team.A))
        body.addView(lineupRow(Bo3Team.B), marginTop(6))
        card.addView(body, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        lineupHost.addView(card)
    }

    private fun lineupRow(team: Bo3Team): View {
        val game = store.series.activeGame
        val actions = game?.actions?.filter { it.team == team }.orEmpty()
        val bans = actions.filter { it.type == Bo3ActionType.BAN }
        val picks = actions.filter { it.type == Bo3ActionType.PICK }
        val row = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        row.addView(teamBadge(team, 22), LayoutParams(dp(22), dp(22)).apply { marginEnd = dp(6) })
        row.addView(textView(store.series.teamNames.name(team), 12f, bold = true), LayoutParams(dp(56), ViewGroup.LayoutParams.WRAP_CONTENT))
        repeat(2) { index ->
            row.addView(lineupSlot(bans.getOrNull(index), Bo3ActionType.BAN, team), LayoutParams(dp(if (isCompact) 26 else 30), dp(30)).apply { marginEnd = dp(4) })
        }
        row.addView(View(context).apply { setBackgroundColor(themeColor(com.google.android.material.R.attr.colorOutlineVariant)) }, LayoutParams(dp(1), dp(22)).apply {
            marginStart = dp(2); marginEnd = dp(6)
        })
        repeat(4) { index ->
            row.addView(lineupSlot(picks.getOrNull(index), Bo3ActionType.PICK, team), LayoutParams(dp(if (isCompact) 28 else 30), dp(30)).apply { marginEnd = dp(4) })
        }
        row.addView(View(context), LayoutParams(0, 1, 1f))
        return row
    }

    private fun lineupSlot(action: Bo3Action?, type: Bo3ActionType, team: Bo3Team): View {
        val host = FrameLayout(context)
        if (action == null) {
            host.addView(TextView(context).apply {
                text = type.shortLabel
                gravity = Gravity.CENTER
                textSize = 8f
                setTextColor(themeColor(com.google.android.material.R.attr.colorOnSurfaceVariant))
                background = GradientDrawable().apply {
                    cornerRadius = dp(8).toFloat()
                    setColor(Color.TRANSPARENT)
                    setStroke(dp(1), 0x55303030, dp(3).toFloat(), dp(3).toFloat())
                }
            }, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        } else {
            host.addView(Bo3AvatarView(context, repository = avatarRepository).apply {
                setCharacter(action.hero, dp(if (isCompact) 26 else 30), used = false)
            }, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            if (type == Bo3ActionType.BAN) {
                host.addView(TextView(context).apply {
                    text = "禁"
                    textSize = 7f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(Color.WHITE)
                    setPadding(dp(3), 0, dp(3), 0)
                    background = GradientDrawable().apply {
                        cornerRadius = dp(4).toFloat()
                        setColor(0xAA111318.toInt())
                    }
                }, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM or Gravity.END))
            }
        }
        return host
    }

    private fun buildPoolBar() {
        poolBarHost.removeAllViews()
        val card = card()
        val body = LinearLayout(context).apply {
            orientation = VERTICAL
            setPadding(dp(10), dp(8), dp(10), dp(8))
        }
        val filters = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val chipScroll = HorizontalScrollView(context).apply {
            isHorizontalScrollBarEnabled = false
            layoutParams = LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        val chipGroup = ChipGroup(context).apply {
            isSingleSelection = true
            isSelectionRequired = false
        }
        chipGroup.addView(roleChip("全部", pool.total, selectedRole == "all") {
            selectedRole = "all"
            render()
        })
        pool.categories.forEach { category ->
            chipGroup.addView(roleChip(category.name, category.heroes.size, selectedRole == category.name) {
                selectedRole = category.name
                render()
            })
        }
        chipScroll.addView(chipGroup)
        filters.addView(chipScroll)
        body.addView(filters)
        val actions = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        availabilityButton = smallTextButton(
            context.getString(R.string.bo3_only_available) + if (onlyAvailable) " ✓" else "",
        ) {
            onlyAvailable = !onlyAvailable
            render()
        }
        actions.addView(availabilityButton)
        actions.addView(smallTextButton("搜索") {
            showsSearch = !showsSearch
            render()
        })
        body.addView(actions)
        searchHost = LinearLayout(context).apply {
            orientation = VERTICAL
            visibility = if (showsSearch) View.VISIBLE else View.GONE
        }
        val inputLayout = TextInputLayout(context).apply {
            hint = context.getString(R.string.bo3_search)
            boxBackgroundMode = TextInputLayout.BOX_BACKGROUND_OUTLINE
        }
        searchField = TextInputEditText(context).apply {
            setText(searchText)
            inputType = InputType.TYPE_CLASS_TEXT
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
                override fun afterTextChanged(s: Editable?) {
                    searchText = s?.toString().orEmpty()
                    updateGrid()
                }
            })
        }
        inputLayout.addView(searchField)
        searchHost.addView(inputLayout, marginTop(6))
        body.addView(searchHost)
        statsView = textView(
            context.getString(
                R.string.bo3_used_stats,
                Bo3DraftEngine.currentGameHeroes(store.series).size,
                Bo3DraftEngine.pickedHeroes(store.series, maxOf(0, store.series.currentGame - 1)).size,
                pool.allHeroes.count { Bo3DraftEngine.availability(it, store.series).isAvailable },
            ),
            11f,
            secondary = true,
        )
        body.addView(statsView, marginTop(4))
        if (selectedRole != "all" || onlyAvailable || searchText.isNotBlank()) {
            body.addView(smallTextButton(context.getString(R.string.bo3_clear)) {
                selectedRole = "all"
                onlyAvailable = false
                searchText = ""
                render()
            })
        }
        card.addView(body, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        poolBarHost.addView(card)
    }

    private fun smallTextButton(label: String, onClick: () -> Unit): MaterialButton =
        MaterialButton(context).apply {
            text = label
            textSize = 11f
            isAllCaps = false
            minWidth = 0
            minimumWidth = 0
            minHeight = dp(34)
            insetTop = 0
            insetBottom = 0
            setPadding(dp(6), 0, dp(6), 0)
            backgroundTintList = android.content.res.ColorStateList.valueOf(Color.TRANSPARENT)
            setTextColor(ContextCompat.getColor(context, R.color.primary))
            setOnClickListener { onClick() }
        }

    private fun roleChip(name: String, count: Int, selected: Boolean, onClick: () -> Unit): Chip =
        Chip(context).apply {
            text = "$name $count"
            isCheckable = true
            isChecked = selected
            textSize = 11f
            minHeight = dp(32)
            setOnClickListener { onClick() }
        }

    private fun renderTeamPanel(host: LinearLayout, team: Bo3Team) {
        host.removeAllViews()
        val card = card()
        val isActive = Bo3DraftEngine.currentStep(store.series)?.first?.team == team
        card.strokeWidth = if (isActive) dp(2) else dp(1)
        card.strokeColor = if (isActive) Bo3Palette.team(team) else 0x22303030
        val body = LinearLayout(context).apply {
            orientation = VERTICAL
            setPadding(dp(12), dp(12), dp(12), dp(12))
        }
        body.addView(textView("${team.sideLabel} · ${if (team == Bo3Team.A) "RED" else "PURPLE"}", 11f, bold = true, color = Bo3Palette.team(team)))
        body.addView(textView(store.series.teamNames.name(team), 20f, bold = true))
        body.addView(seatRowForTeam(team), marginTop(4))
        val game = store.series.activeGame
        body.addView(textView("第 ${maxOf(1, store.series.currentGame)} 局", 12f, bold = true, secondary = true).apply {
            setPadding(0, dp(12), 0, dp(4))
        })
        if (game == null || game.actions.isEmpty()) {
            body.addView(textView("开始一局比赛后显示本局阵容。", 12f, secondary = true))
        } else {
            val noBan = game.noBan
            if (noBan) {
                body.addView(textView(context.getString(R.string.bo3_no_ban_hint), 11f, secondary = true))
            }
            game.actions.filter { it.team == team }.forEach { action ->
                val row = LinearLayout(context).apply {
                    orientation = HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                }
                row.addView(Bo3AvatarView(context, repository = avatarRepository).apply {
                    setCharacter(action.hero, dp(24))
                }, LayoutParams(dp(24), dp(24)).apply { marginEnd = dp(6) })
                row.addView(textView("${action.type.shortLabel} ${action.hero}", 12f, bold = action.type == Bo3ActionType.PICK))
                body.addView(row, marginTop(4))
            }
        }
        val prior = store.series.games.take(maxOf(0, store.series.currentGame - 1)).filter { it.winner != null }
        if (prior.isNotEmpty()) {
            body.addView(textView("前序对局", 12f, bold = true, secondary = true).apply { setPadding(0, dp(12), 0, dp(4)) })
            prior.forEachIndexed { index, priorGame ->
                val result = if (priorGame.winner == team) "胜" else "负"
                body.addView(textView("第 ${index + 1} 局 · $result", 11f, bold = true))
                body.addView(textView(historyActions(priorGame, store.series), 10f, secondary = true))
            }
        }
        card.addView(body, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        host.addView(card)
    }

    private fun seatRowForTeam(team: Bo3Team): View {
        val seats = store.series.seats?.forTeam(team)
        val row = LinearLayout(context).apply { orientation = HORIZONTAL }
        if (seats == null || seats.size != 4) {
            row.addView(textView(context.getString(R.string.bo3_seats_waiting), 11f, secondary = true))
        } else {
            seats.forEach {
                row.addView(textView("$it", 11f, bold = true, secondary = true).apply {
                    gravity = Gravity.CENTER
                    background = GradientDrawable().apply {
                        cornerRadius = dp(5).toFloat()
                        setColor(0x11303030)
                    }
                }, LayoutParams(dp(22), dp(22)).apply { marginEnd = dp(3) })
            }
        }
        return row
    }

    private fun withAlpha(color: Int, alpha: Float): Int =
        Color.argb((alpha * 255).toInt(), Color.red(color), Color.green(color), Color.blue(color))

    internal fun buildHeader() {
        headerHost.removeAllViews()
        headerHost.addView(
            headerCard(),
            LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT),
        )
        renderLineup()
        buildPoolBar()
        if (layoutMode == Bo3LayoutMode.THREE_COLUMN) {
            teamAHost?.let { renderTeamPanel(it, Bo3Team.A) }
            teamBHost?.let { renderTeamPanel(it, Bo3Team.B) }
        } else {
            buildTimeline(false)?.let { timelineHost?.addView(it) }
        }
    }
}


