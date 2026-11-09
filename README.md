# Mus'haf

صدقة جارية — a Madinah Mus'haf reader (King Fahd, Hafs, 604 pages) for Android, iPhone and iPad, Windows, macOS and the web.

| Folder | What |
|---|---|
| `flutter_app/` | **Android, iPhone/iPad and Windows app** — a clone of [Quran Reader HD](https://github.com/Mkuz1/Quran-Reader-HD) 1.3 (Flutter) under Mushaf's package `com.mushaf.myapp` (iOS: `com.kousa.mushaf`) and signing key |
| `MushafMac/` | macOS app (SwiftUI, Quran Reader HD's Mac app) |
| `ios-assets/` | Sideloading guide and App Store kit for the iPhone app |
| `website/` | Web reader (mushafapp.com) |
| `design/` | Design mockups |

The native Compose Android app this replaced is in git history at tag `v1.8.0`; the SwiftUI iPhone app (1.7.0)
that the Flutter app replaced in 1.10.2 is in git history before that release.

## Android

Differences from Quran Reader HD: the app is named Mus'haf with Mushaf's icon, keeps the Android TV
launcher entry, migrates the old app's bookmarks, notes, last page, language and reciter on first
launch, and updates from `Mkuz1/Mushaf-releases` (or through Google Play when installed from Play).

- **Build locally:** `cd flutter_app && flutter pub get && flutter build apk --release`
  (Flutter 3.47.7). Put signing details in `flutter_app/android/key.properties`
  (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) or release builds use the debug key.
- **Release:** bump `version:` in `flutter_app/pubspec.yaml` (`name+code`, the code above the last
  Play upload) and push to `main`, or run *Actions ▸ Release*. The workflow tests, signs and publishes
  the APK and AAB.

## Notes

- **Page source.** `https://files.quran.app/hafs/madani/width_{1024|1920}/page{NNN}.png`
  (verified, all 604 pages). The images are monochrome black-on-transparent, so the
  app tints them: deep sepia in light, soft gold (`#E7DCBE`) on OLED `#0E0E0E` in
  dark. The blue two-tone of some printed editions isn't distributed openly; the
  border geometry here is the authentic King Fahd page.
- **Theming knobs.** All colors live in `MushafTheme.kt` (`MushafPalette.light()` /
  `dark()`). Change `inkColor` to retint every page.
- **Calligraphy font** (dedication): drop e.g. Amiri Quran / Aref Ruqaa into
  `res/font/` and pass it as `calligraphyFamily` in `DedicationScreen`.
- **Page-number tables** in `QuranIndex` use the standard Madani layout; adjust if
  your edition differs.

## License

Page images are the King Fahd Complex Madinah Mus'haf. This app scaffold is yours
to use freely; verify image redistribution terms for any public release.
# Mushaf
# Mushaf
