# Google Play release — Mushaf — Madinah Quran 1.10.13

| | |
|---|---|
| File | `Mushaf-1.10.13.aab`: **Actions ▸ Release ▸** the run that published `v1.10.13` **▸ Artifacts ▸ play-bundle** (kept 90 days, not in the public release) |
| Package | `com.mushaf.myapp` |
| Version name / code | `1.10.13` / `32` |
| Store title | `Mushaf — Madinah Quran` (22 of 30 characters) |
| Images | `icon-512.png` (the new icon), `feature-graphic-1024x500.png`, `tv/tv-banner-1280x720.png` |
| Signed with | the Mushaf upload key (`mushaf-release.jks`, alias `mushaf`), as before |

## Publishing automatically (Actions ▸ Google Play)

The **Google Play** workflow uploads the bundle of the latest release to production with the release notes, sets
the store title and replaces the icon, feature graphic and TV banner in every listing language
(`play-release.json`). It needs a Google service account key, set up once:

1. **Enable the API:** https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com ▸ **Enable**
   (any Google Cloud project; create one if asked).
2. **Create the service account:** https://console.cloud.google.com/iam-admin/serviceaccounts ▸ **Create service
   account** (name: `play-publisher`, no roles needed) ▸ open it ▸ **Keys ▸ Add key ▸ Create new key ▸ JSON**: a
   .json file downloads. Note its email (…@….iam.gserviceaccount.com).
3. **Give it access in Play Console:** https://play.google.com/console/developers/users-and-permissions ▸ **Invite
   new users** ▸ the service account's email ▸ **App permissions ▸ Mushaf** ▸ tick *Release to production, exclude
   devices, and use Play App Signing*, *Release apps to testing tracks* and *Manage store presence* ▸ **Invite user**.
4. **Store the key on GitHub:** https://github.com/Mkuz1/Mushaf/settings/secrets/actions/new ▸ Name
   `PLAY_SERVICE_ACCOUNT_JSON` ▸ Secret: the whole content of the .json file ▸ **Add secret**.

Then run **Actions ▸ Google Play ▸ Run workflow** (track `production`; `rollout` 0.2 for a staged release).

## By hand in Play Console

1. **Test and release ▸ Production ▸ Create new release** ▸ upload `Mushaf-1.10.13.aab` ▸ release name `1.10.13`
   ▸ paste the notes below ▸ **Next ▸ Save ▸ Send for review**.
2. **Grow users ▸ Store presence ▸ Main store listing:** App name `Mushaf — Madinah Quran`; App icon
   `icon-512.png`; Feature graphic `feature-graphic-1024x500.png`; Android TV banner `tv/tv-banner-1280x720.png`
   ▸ **Save** (each translation: the same name).

## Release notes

```
<en-US>
• A new name: Mushaf — Madinah Quran, and a new icon
• Friday reminder to read Surat Al-Kahf, even with the app closed
• Colours by subject: each passage of the mushaf in its own colour
• The same dark green menus on every device
• Android TV: the whole app with the remote
• Bigger pages on tablets; better layout on folding phones
• 26 reciters (Salah Bukhatir ★ by default) with repeat for memorisation
</en-US>
<fr-FR>
• Un nouveau nom : Mushaf — Madinah Quran, et une nouvelle icône
• Rappel du vendredi pour lire la sourate Al-Kahf, même application fermée
• Couleurs par thème : chaque passage du mushaf dans sa couleur
• Les mêmes menus vert foncé sur tous les appareils
• Android TV : toute l'application à la télécommande
• Pages plus grandes sur tablette ; meilleure mise en page sur téléphones pliables
• 26 récitateurs (Salah Bukhatir ★ par défaut) avec répétition
</fr-FR>
<ar>
• اسم جديد: Mushaf — Madinah Quran، وأيقونة جديدة
• تذكير يوم الجمعة بقراءة سورة الكهف، حتى والتطبيق مغلق
• ألوان المواضيع: كل مقطع من المصحف بلون خاص
• نفس القوائم الخضراء الداكنة على كل الأجهزة
• Android TV: التطبيق كله بجهاز التحكم
• صفحات أكبر على الأجهزة اللوحية وتخطيط أفضل على الهواتف القابلة للطي
• ٢٦ قارئًا (صلاح بو خاطر ★ افتراضيًا) مع التكرار للحفظ
</ar>
```
