# Build brief: "Mushaf — Madinah Quran" for Android phones and tablets

You are building a native Android app for **phones, tablets and foldables** that reproduces the **Mushaf — Madinah
Quran** app (version 1.10.13) with all of its current features. A complete, working reference implementation exists
in Flutter in the public repository **https://github.com/Mkuz1/Mushaf** (folder `flutter_app/`). Read it whenever
this brief and your judgement disagree: **the reference app's behaviour wins**. File paths below are in that
repository.

Out of scope: Android TV, iOS, desktop, web, the GitHub self-update and "download for other platforms" links.

---

## 1. Ground rules

- **Language and stack:** Kotlin, Jetpack Compose (Material 3), single activity, `minSdk 26`, `targetSdk` and
  `compileSdk` = the newest stable API. Coroutines + Flow, Media3 (ExoPlayer + MediaSessionService) for audio,
  WorkManager or AlarmManager for the Friday reminder, DataStore for settings, a plain SQLite reader (Android's
  `SQLiteDatabase`, read-only) for the verse positions, OkHttp for downloads, `kotlinx.serialization` for JSON.
  No analytics, no ads, no login, no tracking SDKs, no Firebase.
- **Package name:** ask the owner. Do **not** reuse `com.mushaf.myapp` (the published app) unless the owner says
  this build replaces it; then it must be signed with the same upload key and use a `versionCode` above 32.
- **Nothing large is bundled.** Pages, verse positions, texts and audio download on demand and are cached. Only
  fonts and small tables (surah metadata fallback, subject sections) ship in the APK.
- **The interface is dark green on every device**, whatever the system light/dark setting (only the mushaf page
  itself follows the setting in the *Classic* style; see 5.2).
- **Three interface languages: Arabic, English, French.** Arabic lays the whole interface out right-to-left. The
  mushaf pages always keep book order (page 1 on the right of a spread).
- **Free, a Sadaqa Jariyah** (ongoing charity). Every screen must work offline once its content was downloaded.

---

## 2. Data sources (exact)

All are public, read-only, no API key.

| What | URL | Notes |
|---|---|---|
| Page image *n* (1–604) | `https://raw.githubusercontent.com/Mkuz1/Quran-Reader-HD/main/pages/pageNNN.png` (`NNN` = 3 digits) | 1024 × 1656 px, **black ink on a transparent background**: draw it tinted over a paper colour |
| All 604 pages in one archive | `https://github.com/Mkuz1/Quran-Reader-HD/releases/download/pages-v1/QuranReaderHD-Pages.zip` | about 57 MB; for "Download all pages" |
| Verse positions (SQLite) | `https://raw.githubusercontent.com/Mkuz1/Quran-Reader-HD/main/data/ayahinfo_1024.db` | see 2.1 |
| Surah names, juz' and hizb-quarter starts | `https://api.alquran.cloud/v1/meta` | `data.surahs.references[]` (number, name, englishName, englishNameTranslation, numberOfAyahs, revelationType), `data.juzs.references[]`, `data.hizbQuarters.references[]` (240) — each `{surah, ayah}` |
| Whole-Quran text editions | `https://api.alquran.cloud/v1/quran/{id}` | `data.surahs[].ayahs[].text` |
| Words of a page (for the name of Allah in red) | `https://api.quran.com/api/v4/verses/by_page/{page}?words=true&word_fields=text_uthmani&per_page=50` | see 5.3 |
| quran.com translation *id* | `https://api.quran.com/api/v4/quran/translations/{id}?fields=verse_key` | whole Quran in one request; strip HTML (5.8) |
| quran.com tafsir *id* (per surah) | `https://api.quran.com/api/v4/tafsirs/{id}/by_chapter/{sura}?per_page=50&page={n}` | paginate; empty entries belong to the nearest earlier ayah with text (grouped commentary) |
| quranenc.com translation *key* (per surah) | `https://quranenc.com/api/v1/translation/sura/{key}/{sura}` | `result[]` with `aya` (number **or string**) and `translation` |
| Recitation, one MP3 per ayah | `https://everyayah.com/data/{reciterFolder}/{SSS}{AAA}.mp3` | e.g. `001002.mp3` |

Reference: `flutter_app/lib/core/storage.dart`, `lib/data/*.dart`.

### 2.1 `ayahinfo_1024.db`

Table `glyphs`: `glyph_id, page_number, line_number, sura_number, ayah_number, position, min_x, max_x, min_y, max_y`.
Coordinates are pixels of the 1024 × 1656 page image (origin top-left). `position` is the glyph's index in its
ayah, 1-based; the ayah's last glyph is its end marker. Use it for:

- the ayahs on a page, in reading order (`ORDER BY glyph_id`);
- the first page of an ayah (`MIN(page_number)`), the number of ayahs per surah (`MAX(ayah_number)`);
- hit-testing a tap on the page (the glyph rectangle containing the point, widened −4/−10 px; otherwise the nearest
  glyph on that line);
- highlight rectangles: merge the glyphs of an ayah **per line** into one rectangle each.

Reference: `lib/data/glyph_db.dart`.

### 2.2 Editions

Arabic: `quran-uthmani` (display; strip the 4-word basmala that prefixes ayah 1 of every surah except 1 and 9) and
`quran-simple-clean` (search index only). Translations: `en.sahih`, `en.pickthall`, `fr.hamidullah` (alquran.cloud),
quran.com 136 and 779 (French). Tafsir: `ar.muyassar`, `ar.jalalayn` (alquran.cloud), quranenc `french_mokhtasar`,
quran.com 169 (Ibn Kathir abridged), 168 (Ma'arif al-Qur'an), 817 (Tazkirul Quran). Defaults by interface language:
English → `en.sahih` + Ibn Kathir; French → Hamidullah + Mukhtasar; Arabic → `en.sahih` + Al-Muyassar. Changing
the interface language switches the defaults. Full list with titles: `lib/data/text_library.dart`.

### 2.3 Reciters (26, EveryAyah folders)

Salah Bukhatir ★ is the default (`Salaah_AbdulRahman_Bukhatir_128kbps`). The others, in this order:
Abdul Basit Murattal / Mujawwad, Al-Husary (Murattal, Mujawwad, Muallim), Al-Minshawi Murattal / Mujawwad, Mishary
Alafasy, As-Sudais, Ash-Shuraim, Al-Muaiqly, Al-Ghamdi, Ash-Shatri, Al-Hudhaify, Muhammad Ayyub, Muhammad Jibreel,
Al-Qatami, Ad-Dossari, Ar-Rifai, Al-Ajmi, Basfar, At-Tablawi, Fares Abbad, Al-Juhany, Ali Jaber. Exact folder ids and
English/Arabic names: `lib/audio/reciters.dart`. Show the star on Bukhatir.

### 2.4 Bundled tables

- **Subjects:** the Quran's 556 classical ruku' sections (start and end ayah each) and the colour palette:
  copy `lib/data/subjects.dart` as is.
- **Fonts:** Amiri, Amiri Bold, Amiri Quran (SIL OFL) from `flutter_app/assets/fonts/`.
- **Interface strings** in English/French/Arabic: `lib/core/strings_table.dart` (keys are the English text).

---

## 3. Architecture

```
app/
  data/       Remote (URLs), Downloader (retry ×3 on transport errors, write to .part then rename),
              Paths (files/: pages, data, text, words, audio/<reciter>; cache/: online pages),
              GlyphDb, QuranMeta, TextLibrary, PageWords, Subjects, UserLibrary (bookmarks + notes), PageStore
  audio/      RecitationService (Media3), RecitationController (state machine, 5.5)
  reminder/   FridayReminder
  ui/         theme, dedication, reader (pager, page, spread), sidebar, dock, inspector, textmode,
              ayah menu, settings, share card, help, download pages sheet
  AppState    single source of truth (a ViewModel exposing StateFlow), persisted with DataStore
```

Startup: download `ayahinfo_1024.db` once (show "Downloading ayah coordinates…"), open it, load meta (cache the JSON
in `files/data/meta.json`), then show the reader. A failure shows the message and **Try Again**.

---

## 4. Layout by width (dp) — the tablet look

| Width | Layout |
|---|---|
| < 600 (phones) | Title bar with compact actions (overflow menu); single page; side menu in a drawer; the player floats over the foot of the page |
| 600–759 | Full title bar; single page (or the spread if two-page is on and the page fits) |
| ≥ 760 | Player on **one row**; spread when two-page is on |
| ≥ 1100 (large tablets, landscape) | **Side menu always visible (300 dp) on the left**, the player at its foot; the pages use the full height |
| Unfolded foldable (vertical hinge) | One page each side of the hinge; with the verse panel open: the page on one half, the panel on the other |
| Tabletop posture (horizontal hinge) | The page above the fold; player and panel below |

Pages are always shown whole (fit to the binding dimension, never scrolled), aspect 1024:1656. Keep the reading
position across rotation, fold/unfold and single/two-page switches. Edge-to-edge with insets respected (display
cutouts, the side status bar of book-style foldables). Reference: `lib/ui/home.dart` (`build`, `_appBar`), the
screenshots in `play-assets/screenshots/tablet-en/` and `ios-assets/appstore-assets/ipad-13/en/`.

**Title bar:** "2. Al-Baqarah · Page 2" over "Juz' 1 · Hizb 1"; actions: ‹ page field › (the field accepts 1–604;
‹ goes forward, as in an Arabic book), Translation & Tafsir view toggle, Subjects (palette), Bookmark, Two-page,
Full screen, Settings.

---

## 5. Features

### 5.1 Opening page (Sadaqa Jariyah)

Shown at every launch (and from Settings ▸ About This Sadaqa Jariyah). Emerald gradient with an eight-pointed-star
pattern, a card with a fine double gold rule: basmala; «صدقة جارية» large in gold (Amiri Bold, gold gradient);
"SADAQA JARIYAH"; the dedication ("On behalf of Mohamad Koussa and Dima Ghannoum and their families", French and
Arabic versions); the du'a «اللَّهُمَّ اجْعَلْهُ فِي مِيزَانِ حَسَنَاتِهِمْ» with its translation; the hadith of the three
deeds; a language switch (English · Français · العربية); buttons **Begin Reading** (first launch) or **Continue
Reading** + "Al-Baqarah · Page 42 · Ayah 255", **Continue Listening** (if recitation was playing when the app
closed) and **Start from the Beginning**. Two columns on landscape screens; never scrolls (scale down if needed).
Texts: `lib/ui/dedication.dart`. The first time: offer to download all pages or read online (5.11).

### 5.2 The mushaf

- **Pager:** right-to-left (swipe left = next page), one page or a spread. In a spread the odd page is on the
  right. Turning a spread moves 2 pages. "Swipe to turn pages" can be turned off (then only the buttons turn).
- **Page styles:** *Coloured* (default): the page on parchment `#F5E8C9` inside a 3 dp gold rule `#B08A3D` and an
  inner 1 dp green rule `#3D6B4A` inset 6 dp, 14 dp padding, light shadow, on a desk `#CCB894` (`#403629` in system
  dark mode); every name of Allah in red (5.3). *Classic*: white paper `#FCF7E8` and black ink, or in system dark
  mode dark paper `#1C1C1A` with light ink. *Night*: background `#141417`, ink white at 90 %. Brightness slider in
  Settings (dims the page).
- **Bookmark ribbon** on each page's outer top corner: faint when not bookmarked, red silk (`#B31A1F`→`#850D14`)
  when bookmarked; tap toggles.
- **Note tabs:** a small yellow tab at the outer margin of each line that has an ayah with a note; tap opens it.
- **Highlights:** the verse being recited (green, about `#6BBD78` at 40 %), the selected verse (accent outline),
  rectangles from 2.1 inset by −2/−1 px, rounded 4.
- **Full screen:** just the pages; a tap shows the controls, which hide again after a few seconds; "Exit Full
  Screen" button. Remembered.
- **Continue where you stopped:** the last page and last ayah are saved continuously.

### 5.3 The name of Allah in red (Coloured style)

For each page, fetch the page's words from quran.com (cache in `files/words/pageNNN.json`). For each verse, walk
`words` with `char_type_name == "word"`, split each `text_uthmani` on spaces **by code point** (pause marks are
combining characters), and count glyphs: a token is 1 glyph, or 2 if it contains letters and U+06DC. When a token
is the name of Allah — normalise it (5.9) and match `^(و|ف)?(ب|ت|ل)?ا?لله(م)?$` — remember (ayah, glyph position).
Only keep an ayah's matches if its total glyph count equals the database's count for that ayah (`COUNT(*)` of its
glyphs). Draw the page image a second time tinted `#C7211A`, clipped to those glyph rectangles (−1/−2 px).
Reference: `lib/data/page_words.dart`, `lib/ui/page_widget.dart`.

### 5.4 Choosing a verse

A tap on the page selects the ayah under it and opens the **ayah menu**: "Al-Baqarah — Ayah 255"; Play From Here;
Play This Ayah Only; Set as Range Start; Set as Range End; Play Range; Translation; Tafsir; Share as Image…; Copy
Arabic Text; Copy with Translation; Share…; Bookmark Page N / Remove Page Bookmark. Long-press or double-tap may
open it directly. Reference: `lib/ui/ayah_menu.dart`.

### 5.5 Recitation (the player, "dock")

- **Controls:** previous ayah, play/pause (filled mint circle), next ayah, stop, the range chip "Range 2:255–2:257"
  (plays the memorisation range), and **Reciter, scope and repeat** (opens the Recitation dialog). While playing:
  "1. Al-Fatihah · Ayah 2" and the reciter. In the mushaf view the dock also has the page slider ("Page 1 ·
  Al-Fatihah"; page 1 at the right end), beside the controls on one row from 760 dp, above them otherwise.
- **Recitation dialog:** Reciter (26, 2.3); Play: *This ayah* / *To end of surah* (default) / *Continue through
  Quran*; Repeat each ayah and Repeat selection: Once, 2, 3, 5, 7, 10, ∞; "Play To — choose a stopping point":
  From (surah, ayah) – To (surah, ayah); **Done**, **Play Selection**.
- **Engine:** plays ayah by ayah. Before ayah 1 of every surah except 1 and 9, play the basmala (file `001001.mp3`).
  Repeat the ayah *n* times, then move on; at the end of the range repeat the range *m* times, then stop.
  Prefetch the next 3 ayahs. Cache files in `files/audio/<reciter>/`. Changing reciter while playing restarts the
  current ayah with the new voice.
- **Follow:** the highlighted ayah moves with the audio and the pager turns to keep it visible (in the Translation
  & Tafsir view, the list scrolls to it).
- **Background:** keep playing with the screen off or the app in the background: Media3 `MediaSessionService`
  with a media notification (title: ayah, artist: reciter), lock-screen and headset controls (play/pause,
  next/previous ayah), audio focus, pause on noisy (headphones unplugged).
- Remember "was listening" + last ayah for **Continue Listening** (5.1).

Reference: `lib/audio/audio_controller.dart`, `lib/ui/dock.dart`.

### 5.6 Verse panel (translation, tafsir, note)

Opens beside the pages on tablets (380 dp), as a bottom sheet over the lower 55 % on phones, on the other half of
an unfolded foldable. Header "Ayah N" with Recite this ayah, Copy Arabic text, Share as Image…, Share this ayah,
Done. Tabs **Translation · Tafsir · Note**: the Arabic ayah (Amiri Quran, right-aligned), then the chosen edition
with a source picker (the list in 2.2); the note tab is a text field saved automatically ("Saved 10:42"). Empty
state: "No Ayah Selected — Click an ayah on the page to see its translation, tafsir and your notes." Next/previous
ayah move through the surah. Reference: `lib/ui/inspector.dart`.

### 5.7 Translation & Tafsir view

Replaces the pages: the surah verse by verse. Header: ‹ "1. Al-Fatihah · Makki · 7 verses" ›, segmented
**Arabic · Translation · Both**, **Tafsir** toggle (shows the tafsir under each ayah). Arabic in Amiri Quran,
right-aligned, line height 1.9. Tap an ayah to select it (its menu as in 5.4). The recited ayah is highlighted and
followed. Reference: `lib/ui/text_mode.dart`, screenshot `ios-assets/appstore-assets/ipad-13/en/3-translation.png`.

### 5.8 Text handling

Strip quran.com HTML: remove `<sup…>…</sup>` (footnotes), `<br>` → newline, closing `p/h1–6/li/div` → blank line,
other tags removed, decode `&nbsp; &quot; &#39; &apos; &lt; &gt; &amp;`, collapse 3+ newlines. Cache every edition
as JSON in `files/text/`. Right-to-left editions are right-aligned in any interface language.

### 5.9 Side menu

Tabs (icon segmented button): **Surahs · Juz' · Search · Bookmarks · Notes**.

- **Surahs:** filter field "Surah name or number"; rows: number in a circle, English name, "Makki · 7 verses · Page
  1", Arabic name on the right; the current surah highlighted.
- **Juz':** a list: a header per juz' ("Juz' 1"), then its 8 hizb quarters, each with its mark (● ¼ ½ ¾ in
  gold), the first words of its opening ayah (Arabic, one line) and "Hizb 1 · Al-Baqarah 2:26 · Page 5"; the
  current quarter highlighted; a tap opens that ayah.
- **Search:** "Arabic or translation text". Arabic queries match without diacritics: normalise both sides (keep
  only letters U+0621–063A, U+0641–064A and spaces; fold آ أ إ ٱ → ا, ى → ي, ة → ه; drop harakat, Quranic marks
  and tatweel; keep Latin letters for mixed input; collapse spaces). Strip the basmala prefix of ayah 1 before
  indexing. Otherwise search the current translation, case-insensitively. Show "N results", 50 at a time with
  "Show more results…", each with the matching snippet; suggestions of Arabic words from 2 letters.
- **Bookmarks:** sorted by page or by date; each can be renamed or removed ("Tap the tassel at the top of a page
  to bookmark it" when empty).
- **Notes:** every ayah with a note, its text, swipe or menu to delete.

Reference: `lib/ui/sidebar.dart`, `lib/core/arabic.dart`.

### 5.10 Subjects (colours by subject)

The palette button shows each of the 556 ruku' sections in its own soft colour behind its ayahs (the selection
green must stay distinguishable), and a key above the page: which surah and ayahs each colour covers. Remembered.
Reference: `lib/data/subjects.dart`, `lib/ui/reader.dart` (`SubjectKey`).

### 5.11 Offline pages

Pages load one by one as you read (cache directory). Settings ▸ Pages: *Installed / Online*, **Download** (or
**Remove**). The download sheet: "Download all 604 pages (about 57 MB) from GitHub to read offline, or read
online"; **Read Online** / **Download (57 MB)**; progress "Downloading pages… 42 %" (reading continues meanwhile),
**Cancel Download**, then "Installing pages…" (unzip into `files/pages/`), then "All pages are installed. The
mushaf now works offline." Reference: `lib/data/page_store.dart`, `lib/ui/settings.dart`.

### 5.12 Notes and bookmarks: export and import

Settings ▸ Notes & Bookmarks: **Export as HTML…** (a readable page: notes with surah : ayah, date, the Arabic ayah
and the note; bookmarks with titles and dates), **Export as JSON…**, **Email…**, **Import…** (merges). JSON format,
which must stay compatible with the other Mushaf apps:

```json
{ "bookmarks": [ { "id": "…", "page": 42, "created": "2026-11-20T10:00:00Z", "title": "optional" } ],
  "notes": { "2:255": { "text": "…", "updated": "2026-11-20T10:00:00Z" } } }
```

Use the Storage Access Framework (no storage permission). Reference: `lib/data/user_library.dart`.

### 5.13 Share an ayah as an image

A card exported at 1080 px wide, style **Emerald** (deep green, white text, gold rules) or **Parchment** (cream,
dark ink `#2A2116`, gold-and-green rules): the Arabic ayah in Amiri Quran, its translation, "Surah Al-Baqarah :
Ayah 255 : Page 42", a small "Mushaf" mark. Buttons: Copy, Save, Share (Android share sheet). Reference:
`lib/ui/share_card.dart`.

### 5.14 Friday reminder: Surat Al-Kahf

On by default; the first time the reader opens, ask for notification permission (Android 13+). A notification
every **Friday at 9:00** (time adjustable), even with the app closed and after a reboot: title "Friday: Surat
Al-Kahf", text «مَن قرأ سورة الكهف في يوم الجمعة أضاء له من النور ما بين الجمعتين» (translated in English/French);
tapping opens Al-Kahf (18:1). Inexact alarm (no exact-alarm permission), rescheduled on boot and on language
change. Settings ▸ Reminders: switch + time. Reference: `lib/core/friday_reminder.dart`.

### 5.15 Settings

Page appearance (Classic / Coloured / Night), Brightness, Two-page spread ("When the window or unfolded screen is
wide enough"), Swipe to turn pages, Pages (5.11), Reminders (5.14), Language, Notes & Bookmarks (5.12), About:
version, Mushaf Help (a short guide), About This Sadaqa Jariyah (the opening page).

### 5.16 Updates

Play's in-app update API (flexible update) when installed from Google Play. Nothing else.

### 5.17 Keyboard and game controller (tablets with a keyboard)

Arrows turn pages (left = forward); Enter selects the first ayah, then up/down move ayah by ayah, Enter opens its
menu, Escape leaves; Space plays/pauses; media keys work. Focused controls show a clear 3 dp ring.

---

## 6. Visual design

- **Material 3 dark scheme seeded with `#0D785C`** (the icon's emerald). Surface ≈ `#0F1513`, containers
  ≈ `#1B211F`, primary ≈ mint `#85D6B8`, selected rows `#344B43` with mint text. Gold accents `#DBB86B`, emerald
  `#083326` / `#031C14` (opening page, share card).
- **Fonts:** Amiri Quran for Quran text, Amiri for other Arabic, the system font for Latin text.
- Icons: Material Symbols. Rounded corners 12–28 dp. Tooltips on every icon button.
- App name: **"Mushaf — Madinah Quran"** in the store, **"Mushaf"** under the icon. Launcher icon:
  `design/icon/source.jpg` (adaptive icon: the artwork as foreground over `#083326`; monochrome layer for themed
  icons). Notification icon: `flutter_app/android/app/src/main/res/drawable/ic_stat_mushaf.xml`.

---

## 7. Persistence

DataStore keys (keep these names so data can be migrated if this replaces the old app): `page`, `lastAyah`
("2:255"), `lastListening`, `theme`, `brightness`, `dualPage`, `swipe`, `subjects`, `study` (Arabic/Translation/
Both), `fullScreen`, `translation`, `tafsir`, `reciter`, `language`, `kahfReminder`, `kahfHour`, `kahfMinute`,
`cardStyle`. Bookmarks and notes: `files/library.json` in the format of 5.12.

---

## 8. Manifest and permissions

`INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` (reminder), `FOREGROUND_SERVICE` +
`FOREGROUND_SERVICE_MEDIA_PLAYBACK` (recitation), `WAKE_LOCK` if Media3 needs it. No location, contacts, storage
or ads ID. `android:resizeableActivity="true"`, support all orientations, predictive back. Play Data safety: **no
data collected or shared**.

---

## 9. Acceptance checklist

1. First launch on a phone: opening page in the device language (else English), Begin Reading, the pages offer,
   page 1 on screen within seconds on Wi-Fi.
2. Swipe left goes to page 2; on a 12" tablet in landscape the spread shows pages 1 (right) and 2 (left) with the
   side menu on the left and the player at its foot.
3. Coloured style: gold-and-green frame, every name of Allah red on pages 1, 2, 50 and 293.
4. Tap ayah 2:255 → menu → Play From Here: Bukhatir recites, the ayah is green, the next ayahs follow, the page
   turns by itself; screen off → keeps playing; lock-screen controls work.
5. Repeat each ayah 3×, range 2:255–2:257 repeated 2× plays exactly 18 ayah files plus no basmala.
6. Translation & Tafsir view in Arabic interface: right-to-left UI, Arabic right-aligned, Ibn Kathir not default
   (Al-Muyassar is).
7. Search "الرحمن" without diacritics finds 1:1, 1:3, 55:1…; "mercy" searches the English translation.
8. Bookmark page 42, add a note to 2:255, export JSON, clear data, import → both back.
9. Download all pages, airplane mode, restart: every page opens.
10. Friday reminder: set the time 2 minutes ahead (debug build can fake the day) → notification → opens 18:1.
11. Rotate, fold/unfold, switch single/two-page: the same place stays on screen.
12. TalkBack labels on every control; 200 % font size keeps the interface usable.

---

## 10. Suggested order of work

1. Data layer + downloads + the database + one page on screen with tint and frame.
2. Pager, spread, layouts by width, title bar, page field, settings basics, persistence.
3. Ayah hit-testing, highlights, ayah menu.
4. Recitation engine + Media3 service + dock + Recitation dialog.
5. Side menu (surahs, juz', search, bookmarks, notes).
6. Verse panel, text editions, Translation & Tafsir view.
7. Name of Allah in red, subjects.
8. Offline pages, export/import, share card, Friday reminder, opening page, help.
9. Localisation (en/fr/ar, RTL), accessibility, foldables, keyboard.
10. Release build (R8, signed AAB), store listing, the checklist in 9.
