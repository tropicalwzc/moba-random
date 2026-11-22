package com.example.mobarandom

import android.content.res.Configuration

enum class Bo3LayoutMode {
    COMPACT,
    TWO_COLUMN,
    THREE_COLUMN;

    companion object {
        fun forSize(widthDp: Int, heightDp: Int): Bo3LayoutMode = when {
            widthDp >= 900 && heightDp >= 600 -> THREE_COLUMN
            widthDp >= 600 -> TWO_COLUMN
            else -> COMPACT
        }

        fun fromConfiguration(configuration: Configuration): Bo3LayoutMode =
            forSize(configuration.screenWidthDp, configuration.screenHeightDp)
    }
}
