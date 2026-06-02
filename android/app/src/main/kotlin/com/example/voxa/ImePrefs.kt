package com.example.voxa

import android.content.Context
import android.graphics.Color

class ImePrefs(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun save(values: Map<*, *>) {
        prefs.edit().apply {
            putString(KEY_LANGUAGE_CODE, values[KEY_LANGUAGE_CODE] as? String ?: DEFAULT_LANGUAGE)
            putBoolean(
                KEY_SMART_PUNCTUATION,
                values[KEY_SMART_PUNCTUATION] as? Boolean ?: true,
            )
            putString(KEY_SKIN_NAME, values[KEY_SKIN_NAME] as? String ?: DEFAULT_SKIN_NAME)
            putInt(KEY_PRIMARY_COLOR, readColor(values[KEY_PRIMARY_COLOR], DEFAULT_PRIMARY))
            putInt(KEY_SECONDARY_COLOR, readColor(values[KEY_SECONDARY_COLOR], DEFAULT_SECONDARY))
            apply()
        }
    }

    fun snapshot(): Snapshot {
        return Snapshot(
            languageCode = prefs.getString(KEY_LANGUAGE_CODE, DEFAULT_LANGUAGE) ?: DEFAULT_LANGUAGE,
            smartPunctuation = prefs.getBoolean(KEY_SMART_PUNCTUATION, true),
            skinName = prefs.getString(KEY_SKIN_NAME, DEFAULT_SKIN_NAME) ?: DEFAULT_SKIN_NAME,
            primaryColor = prefs.getInt(KEY_PRIMARY_COLOR, DEFAULT_PRIMARY),
            secondaryColor = prefs.getInt(KEY_SECONDARY_COLOR, DEFAULT_SECONDARY),
        )
    }

    fun cycleLanguage(current: String): String {
        val currentIndex = SUPPORTED_LANGUAGES.indexOf(current).takeIf { it >= 0 } ?: 0
        val nextLanguage = SUPPORTED_LANGUAGES[(currentIndex + 1) % SUPPORTED_LANGUAGES.size]
        prefs.edit().putString(KEY_LANGUAGE_CODE, nextLanguage).apply()
        return nextLanguage
    }

    fun languageLabel(languageCode: String): String {
        return LANGUAGE_LABELS[languageCode] ?: languageCode
    }

    fun recognitionLanguage(languageCode: String): String {
        return when (languageCode) {
            "ja-JP" -> "ja-JP"
            "fr-FR" -> "fr-FR"
            "es-ES" -> "es-ES"
            "de-DE" -> "de-DE"
            "en-US" -> "en-US"
            else -> "zh-CN"
        }
    }

    private fun readColor(raw: Any?, fallback: Int): Int {
        return when (raw) {
            is Int -> raw
            is Long -> raw.toInt()
            is String -> runCatching { Color.parseColor(raw) }.getOrDefault(fallback)
            else -> fallback
        }
    }

    data class Snapshot(
        val languageCode: String,
        val smartPunctuation: Boolean,
        val skinName: String,
        val primaryColor: Int,
        val secondaryColor: Int,
    )

    companion object {
        private const val PREFS_NAME = "chivoice_ime"
        private const val KEY_LANGUAGE_CODE = "languageCode"
        private const val KEY_SMART_PUNCTUATION = "smartPunctuation"
        private const val KEY_SKIN_NAME = "skinName"
        private const val KEY_PRIMARY_COLOR = "primaryColor"
        private const val KEY_SECONDARY_COLOR = "secondaryColor"

        private const val DEFAULT_LANGUAGE = "zh-CN"
        private const val DEFAULT_SKIN_NAME = "bamboo"
        private const val DEFAULT_PRIMARY = 0xFF48624B.toInt()
        private const val DEFAULT_SECONDARY = 0xFF9EB38B.toInt()

        private val SUPPORTED_LANGUAGES = listOf(
            "zh-CN",
            "en-US",
            "ja-JP",
            "fr-FR",
            "es-ES",
            "de-DE",
        )

        private val LANGUAGE_LABELS = mapOf(
            "zh-CN" to "普通话",
            "en-US" to "英语",
            "ja-JP" to "日语",
            "fr-FR" to "法语",
            "es-ES" to "西班牙语",
            "de-DE" to "德语",
        )
    }
}
