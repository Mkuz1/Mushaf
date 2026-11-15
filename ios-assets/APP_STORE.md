# Publishing Mus'haf to the App Store — complete kit (version 1.10.12)

Everything to publish the iPhone and iPad app: what is already in the project, the one-time setup in your Apple
Developer account, the upload (done by GitHub Actions, no Mac needed), and every text and image for the listing.

---

## 0. Already prepared

| Item | Where |
|---|---|
| App | `flutter_app/` — the same Flutter app as on every other platform, iPhone, iPad and iPhone Duo (iOS 15+) |
| iPhone Duo | Built with **Xcode 27.1 (iOS 27.1 SDK)** on GitHub's `xcode-27` runner, so the app fills both of iPhone Duo's displays: one page folded, the two-page spread unfolded, the same place when folding, clear of the side status bar. A test checks this at Apple's sizes. |
| Bundle ID | `com.kousa.mushaf` |
| Version | `version:` in `flutter_app/pubspec.yaml` (1.10.12, build 31) |
| App icon | `flutter_app/ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-1024.png` |
| Privacy manifest | `flutter_app/ios/Runner/PrivacyInfo.xcprivacy` — no tracking, no data collected |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` in Info.plist, so no question at upload |
| Background audio | `UIBackgroundModes: audio` — recitation keeps playing with the screen locked |
| App Store build | `--dart-define=APPSTORE=true` hides the other platforms' downloads and the GitHub update checks (the App Store updates the app) |
| Upload | `.github/workflows/appstore.yml` — builds, signs and uploads to App Store Connect |
| Screenshots | `appstore-assets/iphone-6.9/`, `iphone-duo-outer/`, `iphone-duo-inner/` and `ipad-13/`, in `ar`, `en`, `fr` |
| Privacy policy | https://www.mushafapp.com/privacy.html |

---

## 1. One-time setup in your Apple Developer account

### 1.1 Register the bundle ID
https://developer.apple.com/account/resources/identifiers ▸ **+** ▸ **App IDs** ▸ **App** ▸
- Description: `Mushaf`
- Bundle ID: **Explicit**, `com.kousa.mushaf`
- Capabilities: none to tick (background audio and local notifications need no capability) ▸ **Register**

### 1.2 Create the app record
https://appstoreconnect.apple.com ▸ **Apps** ▸ **+** ▸ **New App**
- Platforms: **iOS**
- Name: `Mus'haf — Madinah Quran` (must be unique on the store; alternatives in §3)
- Primary language: **Arabic** (or English)
- Bundle ID: `com.kousa.mushaf`
- SKU: `mushaf-ios`
- User access: Full access

### 1.3 Create an App Store Connect API key (lets GitHub sign and upload — no Apple ID password)
App Store Connect ▸ **Users and Access** ▸ **Integrations** ▸ **App Store Connect API** ▸ **Team Keys** ▸ **+**
- Name: `GitHub upload`
- Access: **Admin** (needed so the build can create the distribution certificate and profile itself)
- **Generate**, then **Download API Key** — a file `AuthKey_XXXXXXXXXX.p8`. It can be downloaded **only once**:
  keep it somewhere safe.
- Note the **Key ID** (in the table) and the **Issuer ID** (shown above the table).

Your **Team ID**: https://developer.apple.com/account ▸ **Membership details** ▸ Team ID (10 characters).

### 1.4 Add 4 secrets to the GitHub repository
github.com/Mkuz1/Mushaf ▸ **Settings** ▸ **Secrets and variables** ▸ **Actions** ▸ **New repository secret**:

| Secret | Value |
|---|---|
| `APPSTORE_KEY_ID` | the Key ID |
| `APPSTORE_ISSUER_ID` | the Issuer ID |
| `APPSTORE_KEY` | the whole contents of the `.p8` file (open it in TextEdit; from `-----BEGIN PRIVATE KEY-----` to `-----END PRIVATE KEY-----`) |
| `APPLE_TEAM_ID` | the Team ID |

Never paste these anywhere else (chats, issues, commits).

---

## 2. Upload a build

github.com/Mkuz1/Mushaf ▸ **Actions** ▸ **App Store** ▸ **Run workflow** ▸ branch `main` ▸ **Run workflow**.

- About 10 minutes on GitHub, then 10–20 minutes of processing at Apple. The build then shows in App Store
  Connect ▸ your app ▸ **TestFlight** (and an email arrives).
- Each upload needs a **new build number**. It is taken from `pubspec.yaml` (31 for 1.10.12); to upload again
  without a new version, type a higher number (e.g. 32) in the workflow's **Build number** box.
- Optional but recommended: in **TestFlight ▸ Internal Testing**, add yourself and install the build with the
  TestFlight app to try it on your iPhone before submitting.

---

## 3. Store listing — copy-paste

Set up three localizations in **App Information** (Arabic, English (U.S.), French) and paste each language's
texts there and in the version page.

### Name (30 characters max)
| | |
|---|---|
| Arabic | `المصحف — مصحف المدينة` |
| English | `Mus'haf — Madinah Quran` |
| French | `Mus'haf — Coran de Médine` |

If a name is taken: `Mushaf App — Madinah Quran`, `مصحف المدينة — Mus'haf`.

### Subtitle (30 max)
| | |
|---|---|
| Arabic | `مصحف المدينة مع ٢٦ قارئًا` |
| English | `Madinah Mushaf · 26 reciters` |
| French | `Coran de Médine · 26 récitants` |

### Promotional text (170 max — can change any time without review)
- **AR:** `صدقة جارية: مصحف المدينة بصفحاته الأصلية، مع تلاوة آيةً بآية، وترجمة وتفسير، وتذكير الجمعة بسورة الكهف. بدون إعلانات ولا حسابات.`
- **EN:** `A Sadaqa Jariyah: the authentic Madinah Mushaf with verse-by-verse recitation, translation, tafsir and a Friday reminder for Surat Al-Kahf. No ads, no accounts.`
- **FR:** `Une Sadaqa Jariyah : le Mushaf de Médine authentique, récitation verset par verset, traduction, tafsir et rappel du vendredi pour Al-Kahf. Sans pub ni compte.`

### Keywords (100 max per language, comma-separated, no spaces needed)
- **AR:** `قرآن,مصحف,القرآن الكريم,تلاوة,تفسير,حفظ,ختمة,سورة الكهف,قارئ,المدينة,حفص,اذكار`
- **EN:** `quran,mushaf,koran,madinah,recitation,tafsir,hafs,quran offline,memorize,kahf,islam,muslim`
- **FR:** `coran,mushaf,quran,médine,récitation,tafsir,hafs,hors ligne,mémoriser,kahf,islam,musulman`

### Description — English
```
The authentic Madinah Mushaf (King Fahd Complex printing, Hafs narration, 604 pages), offered as an ongoing
charity (Sadaqa Jariyah). No ads, no accounts, no tracking.

READ IT AS IT WAS PRINTED
• The real printed pages, in a gold-and-green frame, every name of Allah in red
• Classic, Coloured and Night page styles, with brightness control
• Full-screen reading: just the page; tap it for the controls
• Two pages side by side on iPad, like an open mushaf
• Colours by subject: each passage of the mushaf in its own colour

LISTEN, VERSE BY VERSE
• 26 reciters, Salah Bukhatir by default: Abdul Basit, Al-Husary, Al-Minshawi, Alafasy, As-Sudais,
  Ash-Shuraim, Al-Muaiqly, Al-Ghamdi and more
• The ayah being recited is highlighted and the page follows
• Repeat each ayah or a whole range, up to ∞, to memorise
• Recitation continues with the screen locked

UNDERSTAND
• The Translation & Tafsir view: the surah ayah by ayah, Arabic, translation or both, with tafsir
• Translations (Saheeh International, Hamidullah) and tafsir (Ibn Kathir, Al-Muyassar, Al-Mukhtasar)
• Notes on any ayah; share an ayah as a beautiful image

FIND YOUR WAY
• Surahs, juz' and all 240 hizb quarters, search, ribbon bookmarks and notes, in one side menu
• Continue reading or listening exactly where you stopped
• A Friday reminder to read Surat Al-Kahf

YOURS, OFFLINE
• Download all 604 pages once and read without a connection
• Arabic, English and French

Also in your browser at www.mushafapp.com
```

### Description — Arabic
```
مصحف المدينة المنورة الأصلي (طبعة مجمع الملك فهد، برواية حفص، ٦٠٤ صفحات)، صدقةً جارية.
بدون إعلانات ولا حسابات ولا تتبّع.

اقرأه كما طُبع
• الصفحات المطبوعة الأصلية بإطار ذهبي وأخضر، ولفظ الجلالة بالأحمر
• المصحف الكلاسيكي والملوّن والليلي، مع ضبط السطوع
• القراءة بملء الشاشة: الصفحة وحدها، اضغطها لإظهار الأزرار
• صفحتان متقابلتان على الآيباد كمصحف مفتوح
• ألوان المواضيع: كل مقطع من المصحف بلون خاص

استمع آيةً بآية
• ٢٦ قارئًا، وصلاح بو خاطر افتراضيًا: عبد الباسط، الحصري، المنشاوي، العفاسي، السديس، الشريم،
  المعيقلي، الغامدي وغيرهم
• الآية المتلوّة مظلّلة والصفحة تتبعها
• كرّر الآية أو نطاقًا كاملًا حتى ∞ للحفظ
• تستمر التلاوة والشاشة مقفلة

افهم
• عرض الترجمة والتفسير: السورة آيةً بآية، بالعربية أو الترجمة أو كليهما، مع التفسير
• ترجمات (صحيح إنترناشونال، حميد الله) وتفاسير (ابن كثير، الميسّر، المختصر)
• ملاحظات على أي آية، ومشاركة الآية كصورة جميلة

انتقل أينما شئت
• السور والأجزاء وأرباع الأحزاب الـ٢٤٠ والبحث والعلامات والملاحظات في قائمة جانبية واحدة
• تابع القراءة أو الاستماع من حيث توقفت
• تذكير يوم الجمعة بقراءة سورة الكهف

مصحفك دون إنترنت
• حمّل الصفحات الـ٦٠٤ مرة واحدة واقرأ دون اتصال
• الواجهة بالعربية والإنجليزية والفرنسية

ويمكنك القراءة في المتصفح: www.mushafapp.com
```

### Description — French
```
Le Mushaf authentique de Médine (impression du Complexe du Roi Fahd, lecture Hafs, 604 pages), offert en
aumône continue (Sadaqa Jariyah). Sans publicité, sans compte, sans suivi.

LISEZ-LE TEL QU'IMPRIMÉ
• Les vraies pages imprimées, dans un cadre or et vert, le nom d'Allah en rouge
• Styles Classique, Coloré et Nuit, avec réglage de la luminosité
• Lecture plein écran : rien que la page ; touchez-la pour les commandes
• Double page sur iPad, comme un mushaf ouvert
• Couleurs par thème : chaque passage du mushaf dans sa couleur

ÉCOUTEZ, VERSET PAR VERSET
• 26 récitateurs, Salah Bukhatir par défaut : Abdul Basit, Al-Husary, Al-Minshawi, Alafasy, As-Sudais,
  Ash-Shuraim, Al-Muaiqly, Al-Ghamdi et d'autres
• Le verset récité est surligné et la page suit
• Répétez un verset ou tout un passage, jusqu'à ∞, pour mémoriser
• La récitation continue écran verrouillé

COMPRENEZ
• La vue Traduction et tafsir : la sourate verset par verset, arabe, traduction ou les deux, avec le tafsir
• Traductions (Saheeh International, Hamidullah) et tafsirs (Ibn Kathir, Al-Muyassar, Al-Mukhtasar)
• Notes sur chaque verset ; partagez un verset en belle image

TROUVEZ VOTRE CHEMIN
• Sourates, juz' et les 240 quarts de hizb, recherche, signets et notes, dans un menu latéral
• Reprenez la lecture ou l'écoute là où vous vous êtes arrêté
• Un rappel du vendredi pour lire la sourate Al-Kahf

À VOUS, HORS LIGNE
• Téléchargez les 604 pages une fois et lisez sans connexion
• Arabe, anglais et français

Aussi dans votre navigateur : www.mushafapp.com
```

### What's New in this version
- **AR:** `أيقونة جديدة، وتذكير يوم الجمعة بسورة الكهف، وألوان المواضيع، وتحسينات في التصميم.`
- **EN:** `A new icon, a Friday reminder for Surat Al-Kahf, colours by subject, and design refinements.`
- **FR:** `Une nouvelle icône, un rappel du vendredi pour Al-Kahf, les couleurs par thème et des finitions.`

(For the very first App Store version, Apple doesn't show "What's New"; keep the text for the next update.)

### URLs and other fields
| Field | Value |
|---|---|
| Support URL | `https://www.mushafapp.com` |
| Marketing URL | `https://www.mushafapp.com` |
| Privacy Policy URL | `https://www.mushafapp.com/privacy.html` |
| Copyright | `2026` followed by your name or company, as on your developer account |
| Category | Primary **Reference**, secondary **Education** |
| Price | Free (no in-app purchases) |
| Availability | All countries |

### Age rating (App Information ▸ Age Rating ▸ Edit)
Answer **None / No** to every question (no violence, no mature content, no user-generated content, no
unrestricted web access, no gambling, no contests). Result: **4+**.

### App Privacy (App Privacy ▸ Get Started)
- "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this
  app.** → Publish. The label shows **Data Not Collected**.
  (Notes, bookmarks and settings stay on the device; pages, text and audio are downloaded without any account
  or identifier.)

---

## 4. Screenshots

Upload in App Store Connect ▸ the version page ▸ **Previews and Screenshots**, for each language:

| Device size in App Store Connect | Folder | Files |
|---|---|---|
| **iPhone 6.9" Display** (1320 × 2868) | `appstore-assets/iphone-6.9/<lang>/` | 7 (Arabic: 6), in order |
| **iPhone Duo — outer display** (1398 × 2034) | `appstore-assets/iphone-duo-outer/<lang>/` | 5 (Arabic: 4), in order |
| **iPhone Duo — inner display** (2853 × 2007) | `appstore-assets/iphone-duo-inner/<lang>/` | 5 (Arabic: 4), in order |
| **iPad 13" Display** (2064 × 2752) | `appstore-assets/ipad-13/<lang>/` | 5 (Arabic: 4), in order |

Apple scales these down for the smaller iPhone and iPad sizes. The first three are what people see in search.

**iPhone Duo:** App Store Connect has no checkbox for it: support comes from building with the iOS 27.1 SDK
(done by the workflow). Adding the two iPhone Duo screenshot sets shows a **"made for iPhone Duo" badge** on
the product page; Apple makes them required for apps built with the iOS 27.1 SDK from April 2027.
To make them again: `flutter test test/marketing_shots_test.dart --dart-define=STORE=apple
--dart-define=OUT=<folder> --dart-define=LANG=en --dart-define=PHONE_FONTS=<fonts>` (and `ar`, `fr`).

---

## 5. Submit for review

1. Version page ▸ **Build** ▸ **+** ▸ choose the uploaded build.
2. Paste the texts, add the screenshots, fill App Privacy and Age Rating (§3–4).
3. **App Review Information**: your name, phone and email; **Sign-in required: No**. Notes:
   ```
   Mus'haf is a free Quran reader: the authentic Madinah Mushaf (King Fahd Complex page images), offered as a
   charitable work (Sadaqa Jariyah). No account, no ads, no data collected.

   - Pages, translations, tafsir and recitation audio are downloaded on demand from public sources
     (raw.githubusercontent.com, api.alquran.cloud, api.quran.com, quranenc.com, everyayah.com) and cached
     for offline reading; the user can also download all pages at once.
   - Background audio is used for recitation, which continues with the screen locked.
   - A local notification (no server) reminds the user on Fridays to read Surat Al-Kahf; it can be turned off
     in Settings ▸ Reminders.
   - The opening page is a charitable dedication, customary in Islamic publications.
   ```
4. **Add for Review** ▸ **Submit to App Review**. Review usually takes 1–3 days.

### Known review points, already handled
- **2.3.10 (other platforms)**: the App Store build hides the Android, Windows and Google Play downloads, and
  the listing and screenshots mention only Apple devices.
- **4.2 (minimum functionality)**: recitation, memorisation repeat, translations, tafsir, notes, search,
  bookmarks, offline pages, reminders.
- **5.1.1 (privacy)**: privacy policy online, privacy manifest included, no data collected.
- **Accuracy of religious content**: the authentic King Fahd Complex pages and established sources.

---

## 6. Later versions

Bump `version:` in `flutter_app/pubspec.yaml` (as for every release), run **Actions ▸ App Store**, then in App
Store Connect add the new version (**+ Version or Platform** ▸ iOS), attach the build, write "What's New" and
submit.
