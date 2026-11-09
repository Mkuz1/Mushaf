> This describes the native Compose Android app up to 1.8.0 (git tag `v1.8.0`). The Android app is now
> the Flutter app in `flutter_app/`; see its README.

# Mus'haf Reader — Architecture

Madinah Mus'haf reader (King Fahd, Hafs, 604 pages), Jetpack Compose. Renders the
authentic printed page images, downloaded + cached in-app.

## Flow

```
MainActivity ─ holds theme + dual-page overrides, builds the caching ImageLoader
   └─ MushafTheme(isDark) ─ provides MushafPalette via LocalMushaf
        └─ MushafApp ─ Dedication → Reader
             ├─ DedicationScreen ─ illuminated opening
             └─ ReaderScreen ─ RTL pager + chrome + scrubber + index
                  ├─ QuranPageView ─ page image, tint, fit-to-screen, offline retry
                  ├─ ZoomableBox ─ pinch/pan/double-tap, single-tap → toggle chrome
                  └─ IndexScreen ─ surah/juz jump + download-all
```

## Decisions

**Source = page images.** Verified host:
`https://files.quran.app/hafs/madani/width_{1024|1920}/page{NNN}.png`. No open SVG
set carries the printed border (checked: mushafdatabase + quranpedia are text-only),
so the page images are the only faithful source. They're monochrome
black-on-transparent → recolored with `ColorFilter.tint(inkColor, SrcIn)`.

**Small install + in-app download.** Nothing is bundled. Coil downloads each page on
first view into a 512 MB disk cache (`respectCacheHeaders(false)` keeps them
offline). `PageDownloader` pre-fetches all 604 on request, with progress.

**Fit-to-screen.** `QuranPageView` sizes each page to the `1024×1656` aspect via
`BoxWithConstraints` and shrinks to the binding dimension — the whole page is always
visible, never scrolled.

**RTL paging + dual pane.** The pager runs in `LayoutDirection.Rtl` (swipe left =
next, book-feel). Two-pane forces the spread's internal layout to `Ltr` so
`child[0]` = physical LEFT = next page, `child[2]` = RIGHT = current; split 50/50
with a hinge-aware gutter. Mode is auto (`WindowSizeClass.Expanded` or a vertical
`FoldingFeature`) and overridable by the dual-page button.

**Navigation.** `QuranIndex` holds surah + juz start pages (Madani layout) and
page→surah/juz lookups. The index jumps the pager; reading position is hoisted in
`ReaderScreen` and mapped between single-page and spread indices, so fold/unfold and
mode toggles keep your place.

**Theming.** `MushafPalette` (light/dark) is the single source of truth via
`LocalMushaf`. Never pure black/white: light = warm sepia ink on radial parchment;
dark = soft gold ink on flat OLED. The dark button overrides the system theme.

## Knobs

- Retint every page: `inkColor` in `MushafTheme.light()/dark()`.
- HD on tablets: pass `MushafPages.HD_WIDTH` where pages are requested.
- Calligraphy: drop a font in `res/font/`, pass as `calligraphyFamily` to
  `DedicationScreen`.
- Page tables: `QuranIndex` (swap if your edition's page breaks differ).
