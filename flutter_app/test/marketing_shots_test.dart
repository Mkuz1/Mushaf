import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quran_reader_hd/app_model.dart';
import 'package:quran_reader_hd/core/l10n.dart';
import 'package:quran_reader_hd/core/quran.dart';
import 'package:quran_reader_hd/core/storage.dart';
import 'package:quran_reader_hd/data/meta.dart';
import 'package:quran_reader_hd/data/page_words.dart';
import 'package:quran_reader_hd/main.dart';
import 'package:quran_reader_hd/ui/dock.dart';
import 'package:quran_reader_hd/ui/home.dart';
import 'package:quran_reader_hd/ui/page_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screenshot_surahs.dart';

/// Google Play images with captions, from the real app on a phone, an unfolded foldable and a TV:
/// `flutter test test/marketing_shots_test.dart --dart-define=OUT=folder --dart-define=LANG=en|ar|fr
/// --dart-define=PHONE_FONTS=folder` (one language per run). Writes, under OUT/LANG:
///   phone/  1080 × 1920, the phone screenshots
///   tablet/ 2560 × 1440, the 7- and 10-inch tablet screenshots (foldable, TV, all devices)
///   tv/     1920 × 1080, the Android TV screenshots: the app alone, as Play asks for TV
const out = String.fromEnvironment('OUT');
const language = String.fromEnvironment('LANG', defaultValue: 'en');
const _phoneFonts = String.fromEnvironment('PHONE_FONTS');
final _screen = GlobalKey();
final _arabic = language == 'ar';

const _green = Color(0xFF0B3A2C);
const _greenDeep = Color(0xFF05201A);
const _gold = Color(0xFFE2BE6A);

const _juzStarts = [
  (1, 1), (2, 142), (2, 253), (3, 93), (4, 24), (4, 148), (5, 82), (6, 111), (7, 88), (8, 41), //
  (9, 93), (11, 6), (12, 53), (15, 1), (17, 1), (18, 75), (21, 1), (23, 1), (25, 21), (27, 56), //
  (29, 46), (33, 31), (36, 28), (39, 32), (41, 47), (46, 1), (51, 31), (58, 1), (67, 1), (78, 1),
];

/// Al-Fatiha in the translation view: Saheeh International and Hamidullah, the app's defaults.
const _fatiha = {
  'en': [
    'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
    '[All] praise is [due] to Allah, Lord of the worlds -',
    'The Entirely Merciful, the Especially Merciful,',
    'Sovereign of the Day of Recompense.',
    'It is You we worship and You we ask for help.',
    'Guide us to the straight path -',
    'The path of those upon whom You have bestowed favor, not of those who have earned [Your] anger or of those who are astray.',
  ],
  'fr': [
    "Au nom d'Allah, le Tout Miséricordieux, le Très Miséricordieux.",
    "Louange à Allah, Seigneur de l'univers.",
    'Le Tout Miséricordieux, le Très Miséricordieux,',
    'Maître du Jour de la rétribution.',
    "C'est Toi [Seul] que nous adorons, et c'est Toi [Seul] dont nous implorons secours.",
    'Guide-nous dans le droit chemin,',
    'le chemin de ceux que Tu as comblés de faveurs, non pas de ceux qui ont encouru Ta colère, ni des égarés.',
  ],
};

/// Headline and line under it, per language (en, ar, fr).
const _captions = <String, List<(String, String)>>{
  'mushaf': [
    ('The Madinah Mushaf', 'Every page as printed, in a gold-and-green frame'),
    ('مصحف المدينة', 'صفحات المصحف كما طُبعت، بإطار ذهبي وأخضر'),
    ('Le Mushaf de Médine', "Chaque page comme à l'impression, dans un cadre or et vert"),
  ],
  'recitation': [
    ('26 reciters, verse by verse', 'The ayah being recited is highlighted and the page follows'),
    ('٢٦ قارئًا، آية بآية', 'الآية المتلوّة مظلّلة والصفحة تتبعها'),
    ('26 récitateurs, verset par verset', 'Le verset récité est surligné et la page suit'),
  ],
  'repeat': [
    ('Repeat to memorise', 'An ayah or a whole range, up to ∞ — Salah Bukhatir ★ by default'),
    ('كرّر للحفظ', 'آية أو نطاقًا كاملًا حتى ∞ — صلاح بو خاطر ★ افتراضيًا'),
    ('Répétez pour mémoriser', "Un verset ou tout un passage, jusqu'à ∞ — Salah Bukhatir ★ par défaut"),
  ],
  'translation': [
    ('Translation & tafsir', 'Every ayah with its meaning, in English, French and Arabic'),
    ('الترجمة والتفسير', 'كل آية بمعناها، بالعربية والإنجليزية والفرنسية'),
    ('Traduction et tafsir', 'Chaque verset avec son sens, en français, anglais et arabe'),
  ],
  'index': [
    ('Everything at hand', "Surahs, juz' and hizb quarters, search, bookmarks and notes"),
    ('كل شيء في متناولك', 'السور والأجزاء وأرباع الأحزاب والبحث والعلامات والملاحظات'),
    ('Tout à portée de main', "Sourates, juz' et quarts de hizb, recherche, signets et notes"),
  ],
  'fullscreen': [
    ('Full-screen reading', 'Just the page — tap it for the controls'),
    ('القراءة بملء الشاشة', 'الصفحة وحدها — اضغطها لإظهار الأزرار'),
    ('Lecture plein écran', 'Rien que la page — touchez-la pour les commandes'),
  ],
  'night': [
    ('Night mode', 'Gentle on the eyes after dark'),
    ('الوضع الليلي', 'مريح للعين في الظلام'),
    ('Mode nuit', 'Doux pour les yeux le soir'),
  ],
  'devices': [
    ('Phone, foldable and TV', 'Two pages side by side on foldables and tablets, Android TV with the remote'),
    ('على الهاتف والقابل للطي والتلفاز', 'صفحتان متقابلتان على الأجهزة القابلة للطي واللوحية، والتلفاز بجهاز التحكم'),
    ('Téléphone, pliable et TV', 'Double page sur pliables et tablettes, Android TV à la télécommande'),
  ],
  'foldable': [
    ('Made for foldables', 'Two pages side by side, one on each half of the screen'),
    ('مصمَّم للأجهزة القابلة للطي', 'صفحتان متقابلتان، كل صفحة على نصف الشاشة'),
    ('Conçu pour les pliables', "Deux pages côte à côte, une sur chaque moitié de l'écran"),
  ],
  'tv': [
    ('Android TV', 'Read and listen with the remote, big and clear across the room'),
    ('Android TV', 'اقرأ واستمع بجهاز التحكم، بوضوح من أي مكان في الغرفة'),
    ('Android TV', 'Lisez et écoutez à la télécommande, grand et net de loin'),
  ],
};

(String, String) _caption(String key) => _captions[key]![['en', 'ar', 'fr'].indexOf(language)];

Future<void> _font(String family, List<Future<ByteData>> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(f);
  }
  await loader.load();
}

Future<ByteData> _file(String path) async => ByteData.sublistView(File(path).readAsBytesSync());

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('marketing');
    Paths.useDirectory(dir);
    File('../data/ayahinfo_1024.db').copySync(p.join(Paths.data.path, 'ayahinfo_1024.db'));
    for (final n in ['page001.png', 'page002.png', 'page042.png', 'page043.png']) {
      File('../pages/$n').copySync(p.join(Paths.pages.path, n));
    }
  });

  var fontsLoaded = false;

  /// The app at [size] (logical pixels), as on a device.
  Future<void> pumpApp(WidgetTester tester, Size size,
      {Map<String, Object> saved = const {}, bool dark = false, List<ui.DisplayFeature> features = const []}) async {
    SharedPreferences.setMockInitialValues(
        {'pagesChoiceMade': true, 'lastPage': 1, 'language': language, 'theme': 'coloured', ...saved});
    final prefs = await SharedPreferences.getInstance();
    Localizer.init(prefs, const Locale(language));
    tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
    model = AppModel(prefs)..showDedication = false;
    model.words.allahWords[1] = {const WordRef(AyahKey(1, 1), 2)};
    model.meta = QuranMeta([
      for (final s in screenshotSurahs)
        Surah.fromJson({
          'number': s[0], 'name': s[1], 'englishName': s[2], 'englishNameTranslation': '',
          'numberOfAyahs': s[3], 'revelationType': s[4],
        }),
    ], [for (final (s, a) in _juzStarts) AyahKey(s, a)], const []);
    clearPageCache();
    // A page image the last screen left loading would never finish here, and settle() would wait for it.
    imageCache
      ..clear()
      ..clearLiveImages();
    if (!fontsLoaded) {
      fontsLoaded = true;
      await tester.runAsync(() async {
        await _font('Amiri Quran', [rootBundle.load('assets/fonts/AmiriQuran-Regular.ttf')]);
        await _font('Amiri', [rootBundle.load('assets/fonts/Amiri-Regular.ttf'), rootBundle.load('assets/fonts/Amiri-Bold.ttf')]);
        final sdk = Directory('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts');
        final files = sdk.listSync().whereType<File>().map((f) => p.basename(f.path)).toList();
        await _font('MaterialIcons', [for (final n in files.where((n) => n.startsWith('MaterialIcons'))) _file('${sdk.path}/$n')]);
        // Android's own fonts: Roboto with Arabic and symbols merged in (see store_screenshots_test.dart).
        final phone = Directory(_phoneFonts).listSync().whereType<File>().where((f) => p.basename(f.path).startsWith('Phone-'));
        await _font('Roboto', [for (final f in phone) _file(f.path)]);
      });
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.displayFeatures = features;
    await tester.pumpWidget(RepaintBoundary(key: _screen, child: const QuranReaderApp()));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settle(tester);
    expect(model.status, LoadStatus.ready);
  }

  testWidgets('marketing images', skip: out.isEmpty, (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final shots = <String, ui.Image>{};

    /// The screen as the device would show it, at its pixel ratio.
    Future<void> capture(String name, double ratio) async {
      debugPrint('settling for $name');
      await settle(tester);
      debugPrint('settled $name');
      await tester.runAsync(() async {
        final boundary = _screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        shots[name] = await boundary.toImage(pixelRatio: ratio);
      });
      debugPrint('captured $name');
    }

    Future<void> done() async {
      await tester.pump(const Duration(seconds: 4));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpWidget(const SizedBox());
    }

    const phone = Size(412, 892), phoneRatio = 2.625;
    // Phone: the Coloured mushaf with Al-Fatiha bookmarked.
    await pumpApp(tester, phone);
    model.library.toggleBookmark(1, title: model.pageTitle(1));
    model.update(() {});
    await capture('mushaf', phoneRatio);
    await done();
    // Recitation on Al-Baqara's first page (opened there, so the page has loaded).
    await pumpApp(tester, phone, saved: {'lastPage': 2});
    model.select(const AyahKey(2, 3));
    model.audio
      ..current = const AyahKey(2, 3)
      ..isPlaying = true
      ..changed();
    await capture('recitation', phoneRatio);
    // The reciters and repeat options.
    showAudioOptions(tester.element(find.byType(Home)));
    debugPrint('sheet opened');
    await capture('repeat', phoneRatio);
    Navigator.of(tester.element(find.text(tr('Done')))).pop();
    model.audio.stop();
    model.select(null);
    await settle(tester);
    // The side menu.
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await capture('index', phoneRatio);
    tester.state<ScaffoldState>(find.byType(Scaffold).first).closeDrawer();
    await settle(tester);
    // The translation view (English and French: their translations of Al-Fatiha are given above).
    if (_fatiha.containsKey(language)) {
      model.goTo(1);
      model.text.texts[model.translationID] = [_fatiha[language]!];
      model.update(() {
        model.studyDisplay = StudyDisplay.translation;
        model.mode = ReadingMode.text;
      });
      model.select(const AyahKey(1, 5));
      await capture('translation', phoneRatio);
      model.update(() => model.mode = ReadingMode.mushaf);
    }
    await done();

    // Full screen, with the controls shown by a tap.
    await pumpApp(tester, phone, saved: {'fullScreen': true, 'lastPage': 1});
    await tester.tapAt(Offset(phone.width / 2, phone.height / 2));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    await capture('fullscreen', phoneRatio);
    await done();

    // Night.
    await pumpApp(tester, phone, dark: true, saved: {'theme': 'night', 'lastPage': 2});
    await capture('night', phoneRatio);
    await done();

    // An unfolded foldable (as a Pixel Fold's inner screen): a page on each half of the fold.
    const fold = Size(800, 840);
    await pumpApp(tester, fold, features: const [
      ui.DisplayFeature(
          bounds: Rect.fromLTWH(400, 0, 0, 840), type: ui.DisplayFeatureType.fold, state: ui.DisplayFeatureState.postureFlat),
    ]);
    model.select(const AyahKey(1, 2));
    model.audio
      ..current = const AyahKey(1, 2)
      ..isPlaying = true
      ..changed();
    await capture('foldable', 2.625);
    model.audio.stop();
    await done();

    // Android TV: 1920 × 1080, the side menu beside the spread, an ayah being recited.
    const tv = Size(1280, 720), tvRatio = 1.5;
    await pumpApp(tester, tv);
    model.select(const AyahKey(1, 5));
    model.audio
      ..current = const AyahKey(1, 5)
      ..isPlaying = true
      ..changed();
    await capture('tv-spread', tvRatio);
    model.audio.stop();
    model.select(null);
    if (_fatiha.containsKey(language)) {
      model.text.texts[model.translationID] = [_fatiha[language]!];
      model.update(() {
        model.studyDisplay = StudyDisplay.translation;
        model.mode = ReadingMode.text;
      });
      model.select(const AyahKey(1, 2));
      await capture('tv-translation', tvRatio);
    }
    await done();
    await pumpApp(tester, tv, dark: true, saved: {'theme': 'night', 'lastPage': 1});
    await capture('tv-night', tvRatio);
    await done();

    // Composed images.
    Future<void> compose(String folder, String name, Size size, Widget child) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.displayFeatures = const [];
      await tester.pumpWidget(RepaintBoundary(
        key: _screen,
        child: Directionality(
          textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
          child: MediaQuery(data: MediaQueryData(size: size), child: child),
        ),
      ));
      await tester.pump();
      await tester.runAsync(() async {
        final boundary = _screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('$out/$language/$folder')..createSync(recursive: true);
        File('${dir.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    const portrait = Size(1080, 1920);
    var n = 0;
    for (final key in ['mushaf', 'recitation', 'repeat', 'translation', 'index', 'fullscreen', 'night']) {
      if (!shots.containsKey(key)) continue;
      await compose('phone', '${++n}-$key', portrait,
          _Poster(caption: _caption(key), child: _Phone(shots[key]!, width: 760)));
    }
    final allDevices = _Devices(tv: shots['tv-spread']!, foldable: shots['foldable']!, phone: shots['recitation']!);
    await compose('phone', '${++n}-devices', portrait, _Poster(caption: _caption('devices'), child: allDevices));

    const landscape = Size(2560, 1440);
    await compose('tablet', '1-foldable', landscape,
        _Poster(caption: _caption('foldable'), wide: true, child: _Foldable(shots['foldable']!, width: 1180)));
    await compose('tablet', '2-tv', landscape,
        _Poster(caption: _caption('tv'), wide: true, child: _Tv(shots['tv-spread']!, width: 1560)));
    await compose('tablet', '3-devices', landscape,
        _Poster(caption: _caption('devices'), wide: true, child: allDevices));

    // TV: the screens alone, as Play's Android TV listing asks.
    var t = 0;
    for (final key in ['tv-spread', 'tv-translation', 'tv-night']) {
      if (!shots.containsKey(key)) continue;
      await compose('tv', '${++t}-${key.substring(3)}', const Size(1920, 1080),
          RawImage(image: shots[key], fit: BoxFit.fill, width: 1920, height: 1080));
    }
  });
}

/// The caption over a device on Mus'haf's dark green, in portrait (phone) or landscape (tablet).
class _Poster extends StatelessWidget {
  final (String, String) caption;
  final Widget child;
  final bool wide;
  const _Poster({required this.caption, required this.child, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final family = _arabic ? 'Amiri' : 'Roboto';
    final title = Text(caption.$1,
        textAlign: wide ? TextAlign.start : TextAlign.center,
        style: TextStyle(
            fontFamily: family, fontFamilyFallback: const ['Roboto'], fontSize: wide ? 104 : 76, fontWeight: FontWeight.bold, color: _gold, height: 1.15));
    final line = Text(caption.$2,
        textAlign: wide ? TextAlign.start : TextAlign.center,
        style: TextStyle(fontFamily: family, fontFamilyFallback: const ['Roboto'], fontSize: wide ? 50 : 40, color: Colors.white.withValues(alpha: 0.86), height: 1.35));
    final mark = Text(_arabic ? 'مصحف · صدقة جارية' : "Mus'haf · مصحف",
        style: TextStyle(fontFamily: 'Amiri', fontSize: wide ? 40 : 34, color: _gold.withValues(alpha: 0.75)));
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(center: Alignment(0, -0.6), radius: 1.3, colors: [Color(0xFF145440), _green, _greenDeep]),
      ),
      child: SizedBox.fromSize(
        size: size,
        child: wide
            ? Row(children: [
                SizedBox(
                  width: 860,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(130, 0, 40, 0),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      mark,
                      const SizedBox(height: 28),
                      title,
                      const SizedBox(height: 28),
                      line,
                    ]),
                  ),
                ),
                Expanded(child: Center(child: child)),
              ])
            : Column(children: [
                const SizedBox(height: 96),
                mark,
                const SizedBox(height: 20),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 70), child: title),
                const SizedBox(height: 22),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 90), child: line),
                const SizedBox(height: 60),
                // The device runs off the foot of the image.
                Expanded(child: OverflowBox(alignment: Alignment.topCenter, maxHeight: double.infinity, child: child)),
              ]),
      ),
    );
  }
}

/// A phone: the screen in a black bezel with rounded corners.
class _Phone extends StatelessWidget {
  final ui.Image screen;
  final double width;
  const _Phone(this.screen, {required this.width});

  @override
  Widget build(BuildContext context) {
    final inner = width - 28;
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(width * 0.085),
        border: Border.all(color: const Color(0xFF3B3B3B), width: 3),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 18))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.07),
        child: RawImage(image: screen, width: inner, height: inner * screen.height / screen.width, fit: BoxFit.fill),
      ),
    );
  }
}

/// An unfolded foldable: a near-square screen with the fold down its middle.
class _Foldable extends StatelessWidget {
  final ui.Image screen;
  final double width;
  const _Foldable(this.screen, {required this.width});

  @override
  Widget build(BuildContext context) {
    final inner = width - 32;
    final height = inner * screen.height / screen.width;
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(width * 0.045),
        border: Border.all(color: const Color(0xFF3B3B3B), width: 3),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 18))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.03),
        child: Stack(children: [
          RawImage(image: screen, width: inner, height: height, fit: BoxFit.fill),
          // The crease: a soft shadow down the fold.
          Positioned(
            left: inner / 2 - 14,
            top: 0,
            bottom: 0,
            width: 28,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.transparent, Color(0x33000000), Colors.transparent]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// A TV on its stand.
class _Tv extends StatelessWidget {
  final ui.Image screen;
  final double width;
  const _Tv(this.screen, {required this.width});

  @override
  Widget build(BuildContext context) {
    final inner = width - 24;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF333333), width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 18))],
        ),
        child: RawImage(image: screen, width: inner, height: inner * 9 / 16, fit: BoxFit.fill),
      ),
      Container(width: width * 0.05, height: width * 0.04, color: const Color(0xFF1C1C1C)),
      Container(
        width: width * 0.32,
        height: width * 0.012,
        decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(6)),
      ),
    ]);
  }
}

/// The TV with the foldable and the phone in front of it.
class _Devices extends StatelessWidget {
  final ui.Image tv, foldable, phone;
  const _Devices({required this.tv, required this.foldable, required this.phone});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1040,
      height: 1240,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(top: 0, left: 20, child: _Tv(tv, width: 1000)),
        // In front of the TV's stand: the foldable, and the phone beside it.
        Positioned(top: 560, left: 0, child: _Foldable(foldable, width: 640)),
        Positioned(top: 470, right: 0, child: _Phone(phone, width: 340)),
      ]),
    );
  }
}

/// Runs animations to their end and decodes images for real.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() async {
      for (final e in tester.elementList(find.byType(Image))) {
        final image = (e.widget as Image).image;
        await precacheImage(image, e).timeout(const Duration(seconds: 3), onTimeout: () => debugPrint('not loaded: $image'));
      }
    });
    await tester.pump(const Duration(milliseconds: 400));
  }
}
