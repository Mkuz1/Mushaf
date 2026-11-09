# Google Play store images — Mus'haf 1.10.10

Captioned images in Arabic (`ar`), English (`en`) and French (`fr`), made from the real app (the released
1.10.10) on a phone, an unfolded foldable and an Android TV.

| Folder | Size | Play Console slot |
|---|---|---|
| `<lang>/phone/` | 1080 × 1920 (9:16) | **Phone screenshots** (2–8; en/fr have 8, ar has 7) |
| `<lang>/tablet/` | 2560 × 1440 (16:9) | **7-inch tablet screenshots** and **10-inch tablet screenshots** (the same 3 in both) |
| `<lang>/tv/` | 1920 × 1080 (16:9) | **Android TV screenshots** (the app alone, without captions, as Play asks for TV) |

The Arabic set has no translation-view image: it would show Quranic Arabic text, which these images take only
from the mushaf's own page images.

## Publishing them

1. **Play Console ▸ Mus'haf ▸ Grow users ▸ Store presence ▸ Main store listing** (default language).
2. **Graphics ▸ Phone screenshots:** remove the old ones, then drag in `phone/1-…` to `phone/8-…` *in order*
   (the first three are what most people see in search results).
3. **7-inch tablet screenshots** and **10-inch tablet screenshots:** add `tablet/1-foldable`, `2-tv`,
   `3-devices` to each.
4. **Android TV:** the TV screenshots and banner live under the same page's **Android TV** section (shown once
   the app has the TV form factor: **Test and release ▸ Advanced settings ▸ Form factors**). Add `tv/1-…`,
   `tv/2-…`, `tv/3-…`; the banner stays `play-assets/tv/tv-banner-1280x720.png`.
5. **Save.** Then for each translation of the listing (**Manage translations** at the top of the page, e.g.
   Arabic and French): open it, and upload that language's folder the same way. A translation without its own
   screenshots shows the default language's.
6. Listing changes go through review (usually within a day) and don't need a new app release.

Which language is the default listing decides which set most people see: use the language the listing's text is
in (Arabic → `ar`, English → `en`).

## Making them again

From `flutter_app` (Flutter on the PATH, and the phone fonts folder — Roboto with Arabic merged in, see
`store_screenshots_test.dart`):

```
flutter test test/marketing_shots_test.dart --dart-define=OUT=<folder> --dart-define=LANG=en --dart-define=PHONE_FONTS=<fonts>
```

and again with `LANG=ar` and `LANG=fr`. Captions are in `_captions` in that file.
