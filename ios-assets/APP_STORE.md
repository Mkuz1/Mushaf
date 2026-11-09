# Publishing Mus'haf to the App Store — complete kit

Everything below is ready to copy-paste. Files referenced live in this folder.

---

## 0. What's already prepared in the project

| Item | Status |
|---|---|
| Project | `flutter_app/ios` — the Flutter app, the same as on Android (the SwiftUI app it replaced is in git history) |
| Version | `version:` in `flutter_app/pubspec.yaml` (name+build) |
| App icon | `Runner/Assets.xcassets/AppIcon` (1024 px) ✓ |
| Privacy manifest | `Runner/PrivacyInfo.xcprivacy` ✓ (no tracking, no data collected; UserDefaults CA92.1, file timestamps C617.1) |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` in Info.plist ✓ (no question at upload) |
| Launch screen, orientations, iPhone+iPad | ✓ |
| Screenshots | `appstore-assets/iphone-6.7/` (6) and `appstore-assets/ipad-13/` (3) |
| Privacy policy URL | https://www.mushafapp.com/privacy (live) |

---

## 1. One-time setup (if not done)

1. **Apple Developer Program** — enroll at https://developer.apple.com/programs/ ($99/year). Use the Apple ID you want to own the app.
2. In Xcode ▸ Settings ▸ Accounts, sign in with that Apple ID.
3. In the project's **Signing & Capabilities** tab: check **Automatically manage signing** and pick your Team. Xcode creates the certificates and provisioning profile for `com.kousa.mushaf` automatically.

## 2. Create the app record in App Store Connect

1. Go to https://appstoreconnect.apple.com ▸ **My Apps** ▸ **+** ▸ **New App**.
2. Fill:
   - **Platform**: iOS
   - **Name**: `Mus'haf — Madinah Quran` (see §4; must be unique on the store — fallbacks below)
   - **Primary language**: Arabic (or English if you prefer managing in English)
   - **Bundle ID**: `com.kousa.mushaf` (select from the menu; it appears after the first Xcode signing step, or register it at developer.apple.com ▸ Identifiers)
   - **SKU**: `mushaf-001` (internal, anything unique)

## 3. Archive & upload the build

```bash
cd ~/Documents/Mushaf/flutter_app
flutter pub get                # Flutter 3.47.7
flutter build ios --release    # once, so Xcode has the generated files
open ios/Runner.xcworkspace
```

In Xcode:
1. Select the **Runner** scheme and destination **Any iOS Device (arm64)**.
2. **Product ▸ Archive**.
3. In the Organizer window: **Distribute App ▸ App Store Connect ▸ Upload** (defaults are fine).
4. Wait ~15 min for processing; the build appears in App Store Connect ▸ TestFlight.
5. (Recommended) Install via **TestFlight** on your own device and smoke-test once.

## 4. Store listing — copy-paste content

### Name (30 chars max)
- Primary: `Mus'haf — Madinah Quran`
- If taken: `Mushaf App — Madinah Quran` · `المصحف — Madinah Mushaf`

### Subtitle (30 chars max)
- EN: `The Madinah Mushaf, page-true`
- AR: `مصحف المدينة كما طُبع`
- FR: `Le Mushaf de Médine, fidèle`

### Category
- Primary: **Reference** · Secondary: **Lifestyle** (or Education)

### Age rating
- Answer "None" to all questionnaire items → **4+**

### Price
- Free. No in-app purchases.

### App Privacy (nutrition label)
- **Data Not Collected** — select "No, we do not collect data from this app".
- Privacy Policy URL: `https://www.mushafapp.com/privacy`

### URLs
- Support URL: `https://www.mushafapp.com`
- Marketing URL: `https://www.mushafapp.com`
- Copyright: `© 2026 Mohamad Al-Kousa`

### Keywords (100 chars, EN locale)
```
quran,mushaf,madinah,hafs,quran offline,tafsir,quran reader,مصحف,القرآن,ختمة
```

### Description — English (also use for French locale with the FR text below)
```
The authentic Madinah Mushaf (King Fahd printing, Hafs narration, 604 pages) —
beautifully simple, offered as an ongoing charity (Sadaqah Jariyah). No ads,
no accounts, no tracking.

READ AS IT WAS PRINTED
• The real printed pages — the authentic border, ayah markers and calligraphy
• Fit-to-screen: a whole page is always visible, never scroll to read
• Pinch to zoom with extra-sharp HD detail
• Two-page spread on iPad and in landscape, like an open mushaf
• A warm night mode that rests the eyes

FIND YOUR WAY INSTANTLY
• Surah and Juz index, and resume exactly where you stopped
• Search the entire Quran text — no diacritics needed
• Bookmark your pages and follow your khatmah progress

GO DEEPER, AYAH BY AYAH
• Tap any ayah to copy it, read its translation (Saheeh International,
  Hamidullah) or its tafsir (Ibn Kathir, Al-Mukhtasar)
• Share any ayah as an elegant image card

YOURS, OFFLINE
• Download all 604 pages once (~54 MB) and read with no connection
• Interface in Arabic, English and French

Also readable in your browser at www.mushafapp.com
```

### Description — French
```
Le Mushaf authentique de Médine (impression du Roi Fahd, lecture Hafs, 604
pages) — d'une élégante simplicité, offert en aumône continue (Sadaqah
Jariyah). Sans publicité, sans compte, sans suivi.

LISEZ-LE TEL QU'IMPRIMÉ
• Les vraies pages imprimées — bordures, marqueurs de versets et calligraphie
• Page entière toujours visible, sans défilement
• Zoom par pincement avec détail HD
• Double page sur iPad et en paysage, comme un mushaf ouvert
• Un mode nuit chaleureux qui repose les yeux

TROUVEZ TOUT, INSTANTANÉMENT
• Index des sourates et des juz, reprise là où vous vous êtes arrêté
• Recherche dans tout le texte du Coran — sans diacritiques
• Signets et progression de votre khatmah

VERSET PAR VERSET
• Touchez un verset : copie, traduction (Saheeh International, Hamidullah)
  ou tafsir (Ibn Kathir, Al-Mukhtasar)
• Partagez un verset en carte-image élégante

À VOUS, HORS LIGNE
• Téléchargez les 604 pages (~54 Mo) et lisez sans connexion
• Interface en arabe, anglais et français

Lisible aussi dans votre navigateur : www.mushafapp.com
```

### Description — Arabic
```
مصحف المدينة المنورة الأصلي (طباعة مجمع الملك فهد، برواية حفص، ٦٠٤ صفحات) —
بتصميم أنيق وبسيط، صدقةً جارية. بدون إعلانات ولا حسابات ولا تتبّع.

اقرأه كما طُبع
• الصفحات المطبوعة الأصلية — الإطار وعلامات الآيات والخط كما هي
• الصفحة كاملة أمامك دائمًا، دون تمرير
• تكبير باللمس بدقة عالية
• صفحتان متقابلتان على الآيباد وفي الوضع الأفقي، كمصحف مفتوح
• وضع ليلي دافئ يريح العين

انتقل أينما شئت
• فهرس السور والأجزاء، ومتابعة القراءة من حيث توقفت
• البحث في نص القرآن كاملًا — دون الحاجة للتشكيل
• علامات لصفحاتك المفضلة ومتابعة تقدم ختمتك

آيةً آية
• اضغط على أي آية لنسخها أو قراءة ترجمتها أو تفسيرها (ابن كثير، المختصر)
• شارك أي آية كبطاقة صورة أنيقة

مصحفك، دون إنترنت
• حمّل الصفحات كلها مرة واحدة (~٥٤ م.ب) واقرأ دون اتصال
• الواجهة بالعربية والإنجليزية والفرنسية

ويمكنك القراءة في المتصفح: www.mushafapp.com
```

### What's New (release notes for 1.4.0)
Use the same text as the Play Store notes (EN/FR/AR variants above, trimmed to taste).

## 5. Screenshots

Upload from `appstore-assets/`:
- **iPhone 6.7"** (1290×2796) → the 6 files in `iphone-6.7/` (Apple reuses them for smaller sizes)
- **iPad 13"** (2048×2732) → the 3 files in `ipad-13/` (required because the app supports iPad)

Replace any of them with real device captures later if you prefer (Simulator: `Cmd+S` saves a correctly-sized PNG).

## 6. Submit

1. In the app's **App Store** tab: attach the build from TestFlight, paste the texts above, add screenshots, set privacy answers.
2. **App Review notes** (paste this):
   ```
   A free Quran reader (Madinah Mushaf). Content is the standard King Fahd
   Complex page images, streamed from our CDN and cached for offline use.
   Translations/tafsir come from the public quran.com and quranenc.com APIs.
   No account is needed; no data is collected. The dedication on the opening
   page is a charitable dedication (Sadaqah Jariyah), customary in Islamic
   publications.
   ```
3. **Add to Review** ▸ **Submit**. Review typically takes 1–3 days.

### Common rejection risks (already mitigated)
- Religious-content apps must be respectful/accurate → authentic KFGQPC pages, standard sources. ✓
- 4.2 Minimum functionality → rich native features (offline, search, bookmarks, tafsir, share). ✓
- 5.1.1 Privacy → policy URL live, manifest included, no data collected. ✓
