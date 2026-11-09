# Google Play release — Mus'haf 1.10.12

| | |
|---|---|
| File to upload | `Mushaf-1.10.12.aab`: in Mkuz1/Mushaf, **Actions ▸ Release ▸** the run that published `v1.10.12` **▸ Artifacts ▸ play-bundle** (a zip with the .aab; kept 90 days, not attached to the public release) |
| Package | `com.mushaf.myapp` |
| Version name / code | `1.10.12` / `31` (must be higher than the last upload) |
| Signed with | the Mushaf upload key (`mushaf-release.jks`, alias `mushaf`), the same key as earlier uploads |
| Form factors | Phones, tablets, foldables and Android TV, in one bundle (the TV launcher entry and banner are kept) |
| Permissions | Internet; notifications and "run at startup" for the Friday Al-Kahf reminder (POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED) |

## Steps in Play Console

1. **Play Console ▸ Mus'haf ▸ Test and release ▸ Production** (or **Internal testing** first) ▸ **Create new release**.
2. Under **App bundles**, upload `Mushaf-1.10.12.aab`. Play checks the signature against your upload key and the
   version code (31).
3. **Release name:** `1.10.12`.
4. **Release notes:** paste the three blocks below (each is under Play's 500-character limit).
5. **Next ▸ Save ▸ Send for review** (or **Start rollout**). A staged rollout (e.g. 20 %) is a good idea for this
   release, since the app was rebuilt.
6. **Android TV:** if the app has a TV release track (**Test and release ▸ Advanced settings ▸ Form factors**),
   promote the same release there as well; the bundle already supports TV.

Installs from Play get later updates through Play's own in-app update prompt (built into the app).

## Release notes

```
<en-US>
• A new app icon
• Friday reminder to read Surat Al-Kahf, even with the app closed
• Colours by subject: each passage of the mushaf in its own colour
• Same dark green menus and bars on every device
• Android TV: the whole app with the remote
• Bigger pages on tablets and large screens
• Salah Bukhatir is the default reciter (★)
• Full-screen reading, continue where you stopped, 26 reciters with repeat for memorisation
</en-US>
<ar>
• أيقونة جديدة للتطبيق
• تذكير يوم الجمعة بقراءة سورة الكهف، حتى والتطبيق مغلق
• ألوان المواضيع: كل مقطع من المصحف بلون خاص
• نفس القوائم والأشرطة الخضراء الداكنة على كل الأجهزة
• Android TV: التطبيق كله بجهاز التحكم
• صفحات أكبر على الأجهزة اللوحية والشاشات الكبيرة
• صلاح بو خاطر هو القارئ الافتراضي (★)
• القراءة بملء الشاشة، وتابع من حيث توقفت، و٢٦ قارئًا مع التكرار للحفظ
</ar>
<fr-FR>
• Une nouvelle icône
• Rappel du vendredi pour lire la sourate Al-Kahf, même application fermée
• Couleurs par thème : chaque passage du mushaf dans sa couleur
• Les mêmes menus et barres vert foncé sur tous les appareils
• Android TV : toute l'application à la télécommande
• Pages plus grandes sur tablettes et grands écrans
• Salah Bukhatir est le récitateur par défaut (★)
• Lecture plein écran, reprise où vous vous êtes arrêté, 26 récitateurs avec répétition
</fr-FR>
```

## Store listing updates (optional but recommended)

**New icon and feature graphic (1.10.12):** upload `play-assets/icon-512.png` as the **App icon** and
`play-assets/feature-graphic-1024x500.png` as the **Feature graphic**, and on Android TV the banner
`play-assets/tv/tv-banner-1280x720.png` (**Grow users ▸ Store presence ▸ Main store listing ▸ Graphics**).

**Short description (max 80):**
`Madinah Mushaf · 26 reciters · full screen · tafsir · notes · offline`

**Full description — add near the top:**

```
• Full-screen reading: the page alone; tap it for the controls.
• Verse-by-verse recitation by 26 reciters (Abdul Basit, Al-Husary, Al-Minshawi,
  Alafasy, As-Sudais, Ash-Shuraim, Al-Muaiqly, Al-Ghamdi, Bukhatir and more),
  with repeat each ayah or a range up to ∞ for memorisation.
• Continue Reading / Continue Listening from where you stopped.
• Coloured mushaf: parchment in a gold-and-green frame, every name of Allah in red.
• Silk ribbon bookmarks, notes on any ayah, export by HTML, JSON or email.
• Side menu: surahs, juz' with all 240 hizb quarters, search, bookmarks, notes.
• Also on Windows, macOS and the web: mushafapp.com
```

**Screenshots:** new phone screenshots (dark green menus, as in 1.10.12) are in `play-assets/screenshots/en`, `ar` and `fr`
(1082 × 2163 PNG, within Play's 2:1 limit). Upload each language's set to its listing
(**Grow ▸ Store presence ▸ Main store listing ▸ Phone screenshots**, then the same under each translation):

1. Opening page: continue where you stopped
2. Coloured mushaf with the ribbon bookmark
3. Verse-by-verse recitation
4. Reciters (Salah Bukhatir ★) and repeat options
5. Side menu index
6. Settings ▸ Download Mus'haf
7. Full screen with the controls
8. Night

**Tablet screenshots** (2560 × 1600, landscape) are in `play-assets/screenshots/tablet-en`, `tablet-ar` and
`tablet-fr`: upload them under **10-inch tablet screenshots** (and **7-inch** too, if you like) in each listing.

The previous design's screenshots are kept in `play-assets/screenshots/previous`. To make new ones after a design
change: `flutter test test/store_screenshots_test.dart --dart-define=OUT=<folder> --dart-define=LANG=en` (and `ar`,
`fr`) in `flutter_app`; add `--dart-define=SIZE=1280x800 --dart-define=DPR=2` for the tablet ones.

## Policy forms to re-check

- **Data safety:** unchanged (the Friday reminder is scheduled on the device; nothing is sent anywhere) — no data collected or shared; the app downloads pages, text and audio
  (raw.githubusercontent.com, api.alquran.cloud, api.quran.com, quranenc.com, everyayah.com) and checks for
  updates. Notes and bookmarks stay on the device.
- **Privacy policy URL:** https://www.mushafapp.com/privacy.html (mentions these hosts).
- **Target API level:** the bundle targets Flutter 3.47's default (Android 16), which meets Play's current requirement.
