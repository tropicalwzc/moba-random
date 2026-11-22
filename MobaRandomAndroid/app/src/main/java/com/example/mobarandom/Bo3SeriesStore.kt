package com.example.mobarandom

import android.content.Context
import androidx.core.content.edit

/**
 * Owns the mutable BO3 series and its local persistence. Every mutation goes
 * through the pure engine, then writes the sanitized state in one place.
 */
class Bo3SeriesStore(context: Context) {
    private val preferences = context.getSharedPreferences(
        RoleWeightStorage.PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )

    var series: Bo3Series = load()
        private set

    val canUndo: Boolean
        get() = series.activeGame?.let { it.winner != null || it.actions.isNotEmpty() } == true

    val hasProgress: Boolean
        get() = series.hasProgress

    fun reload() {
        series = load()
    }

    fun startGame(pool: Bo3Pool) {
        series = Bo3DraftEngine.startGame(series, pool)
        save()
    }

    fun choose(hero: String, role: String) {
        series = Bo3DraftEngine.choose(series, hero, role)
        save()
    }

    fun setWinner(team: Bo3Team) {
        series = Bo3DraftEngine.setWinner(series, team)
        save()
    }

    fun reopenWinner(): Boolean {
        val updated = Bo3DraftEngine.reopenWinner(series) ?: return false
        series = updated
        save()
        return true
    }

    fun undo(): Boolean {
        val updated = Bo3DraftEngine.undo(series) ?: return false
        series = updated
        save()
        return true
    }

    fun reset() {
        series = Bo3DraftEngine.reset(series)
        save()
    }

    fun updateTeamNames(names: Bo3TeamNames) {
        series = series.copy(teamNames = Bo3DraftEngine.normalizedTeamNames(names))
        save()
    }

    fun updateNoBanGame3(enabled: Boolean) {
        series = series.copy(noBanGame3 = enabled)
        save()
    }

    fun save() {
        preferences.edit { putString(KEY, Bo3SeriesCodec.encode(series)) }
    }

    private fun load(): Bo3Series {
        val raw = preferences.getString(KEY, null) ?: return Bo3Series()
        return Bo3SeriesCodec.decode(raw)?.let(Bo3DraftEngine::sanitize) ?: Bo3Series()
    }

    companion object {
        const val KEY = "moba_bo3_series_v1"
    }
}
