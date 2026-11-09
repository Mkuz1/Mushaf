package com.mkoussa.quran_reader_hd

import android.content.Context
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import java.io.File

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        migrateMushafData()
        // Draw behind the status and navigation bars on every Android version, as Android 15 does for apps
        // targeting SDK 35; the Flutter UI already keeps clear of them with the system insets (SafeArea).
        WindowCompat.enableEdgeToEdge(window)
        super.onCreate(savedInstanceState)
    }

    /**
     * Mushaf 1.8 and earlier (the native app this one replaced) kept the reader's state in the
     * "mushaf_reading" preferences. Carry the last page, language, reciter and the bookmarks and
     * notes over once, into the places the Flutter app reads them: its shared preferences and
     * library.json (the same JSON format).
     */
    private fun migrateMushafData() {
        val old = getSharedPreferences("mushaf_reading", Context.MODE_PRIVATE)
        if (old.getBoolean("migrated_to_flutter", false) || old.all.isEmpty()) return
        val flutter = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val edit = flutter.edit()
        if (!flutter.contains("flutter.lastPage") && old.contains("last_page")) {
            edit.putLong("flutter.lastPage", old.getInt("last_page", 1).toLong())
        }
        old.getString("ui_lang", null)?.let { code ->
            if (!flutter.contains("flutter.language") && code in listOf("ar", "en", "fr")) edit.putString("flutter.language", code)
        }
        old.getString("reciter", null)?.let { if (!flutter.contains("flutter.reciter")) edit.putString("flutter.reciter", it) }
        edit.apply()

        val library = File(filesDir, "library.json")
        if (!library.exists()) {
            val json = old.getString("library_json", null) ?: run {
                // Before 1.8, bookmarks were a plain list of page numbers.
                val pages = old.getString("bookmarks", "")!!.split(',').mapNotNull { it.toIntOrNull() }
                if (pages.isEmpty()) null
                else "{\"bookmarks\":[" + pages.joinToString(",") { "{\"page\":$it}" } + "],\"notes\":{}}"
            }
            if (json != null) runCatching { library.writeText(json) }
        }
        old.edit().putBoolean("migrated_to_flutter", true).apply()
    }
}
