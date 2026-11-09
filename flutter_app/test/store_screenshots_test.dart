import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quran_reader_hd/app_model.dart';
import 'package:quran_reader_hd/audio/reciters.dart';
import 'package:quran_reader_hd/core/l10n.dart';
import 'package:quran_reader_hd/core/quran.dart';
import 'package:quran_reader_hd/core/storage.dart';
import 'package:quran_reader_hd/data/meta.dart';
import 'package:quran_reader_hd/data/page_words.dart';
import 'package:quran_reader_hd/main.dart';
import 'package:quran_reader_hd/ui/dock.dart';
import 'package:quran_reader_hd/ui/home.dart';
import 'package:quran_reader_hd/ui/page_widget.dart';
import 'package:quran_reader_hd/ui/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screenshot_surahs.dart';

/// Phone screenshots for the website and the store listings, from the real widgets with the repository's
/// pages and ayah database, offline. Skipped unless run with
/// `flutter test test/store_screenshots_test.dart --dart-define=OUT=<folder> --dart-define=LANG=en|ar|fr`
/// (one language per run: fonts loaded for one stay loaded), and optionally SIZE and DPR (below).
const out = String.fromEnvironment('OUT');
const language = String.fromEnvironment('LANG', defaultValue: 'en');
const _phoneFonts = String.fromEnvironment('PHONE_FONTS');
/// Screen size in logical pixels, e.g. `--dart-define=SIZE=1280x800` for a 12" tablet in landscape; by default a
/// phone (1082 × 2163 at 2.625×, within Google Play's 2:1 limit).
const _sizeDefine = String.fromEnvironment('SIZE', defaultValue: '412x824');
final _size = Size(double.parse(_sizeDefine.split('x')[0]), double.parse(_sizeDefine.split('x')[1]));
final _pixelRatio = double.parse(const String.fromEnvironment('DPR', defaultValue: '2.625'));
final _screen = GlobalKey();

const _juzStarts = [
  (1, 1), (2, 142), (2, 253), (3, 93), (4, 24), (4, 148), (5, 82), (6, 111), (7, 88), (8, 41), //
  (9, 93), (11, 6), (12, 53), (15, 1), (17, 1), (18, 75), (21, 1), (23, 1), (25, 21), (27, 56), //
  (29, 46), (33, 31), (36, 28), (39, 32), (41, 47), (46, 1), (51, 31), (58, 1), (67, 1), (78, 1),
];

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
    final dir = Directory.systemTemp.createTempSync('shots');
    Paths.useDirectory(dir);
    File('../data/ayahinfo_1024.db').copySync(p.join(Paths.data.path, 'ayahinfo_1024.db'));
    for (final n in ['page001.png', 'page002.png', 'page042.png', 'page043.png']) {
      File('../pages/$n').copySync(p.join(Paths.pages.path, n));
    }
  });

  Future<void> pumpApp(WidgetTester tester,
      {Map<String, Object> saved = const {}, bool dark = false, bool dedication = false}) async {
    SharedPreferences.setMockInitialValues(
        {'pagesChoiceMade': true, 'lastPage': 1, 'language': language, 'theme': 'coloured', ...saved});
    final prefs = await SharedPreferences.getInstance();
    Localizer.init(prefs, const Locale(language));
    tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    model = AppModel(prefs)..showDedication = dedication;
    model.words.allahWords[1] = {const WordRef(AyahKey(1, 1), 2)};
    model.meta = QuranMeta([
      for (final s in screenshotSurahs)
        Surah.fromJson({
          'number': s[0], 'name': s[1], 'englishName': s[2], 'englishNameTranslation': '',
          'numberOfAyahs': s[3], 'revelationType': s[4],
        }),
    ], [for (final (s, a) in _juzStarts) AyahKey(s, a)], const []);
    clearPageCache();
    await tester.runAsync(() async {
      await _font('Amiri Quran', [rootBundle.load('assets/fonts/AmiriQuran-Regular.ttf')]);
      final amiri = [rootBundle.load('assets/fonts/Amiri-Regular.ttf'), rootBundle.load('assets/fonts/Amiri-Bold.ttf')];
      await _font('Amiri', amiri);
      final sdk = Directory('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts');
      final files = sdk.listSync().whereType<File>().map((f) => p.basename(f.path)).toList();
      await _font('MaterialIcons', [for (final n in files.where((n) => n.startsWith('MaterialIcons'))) _file('${sdk.path}/$n')]);
      // The phone's system font. PHONE_FONTS stands in for Android's fallback fonts: Phone-*.ttf is Roboto with
      // Arabic and symbols merged in, PhoneAr-*.ttf is Amiri (as close to a phone's Arabic font as the
      // repository has) with symbols.
      final arabic = language == 'ar';
      final phone = _phoneFonts.isEmpty
          ? <File>[]
          : Directory(_phoneFonts).listSync().whereType<File>().where((f) => p.basename(f.path).startsWith(arabic ? 'PhoneAr-' : 'Phone-')).toList();
      await _font('Roboto', [
        if (phone.isNotEmpty) ...phone.map((f) => _file(f.path))
        else if (arabic) ...[rootBundle.load('assets/fonts/Amiri-Regular.ttf'), rootBundle.load('assets/fonts/Amiri-Bold.ttf')]
        else ...[for (final n in files.where((n) => n.startsWith('Roboto-'))) _file('${sdk.path}/$n')],
      ]);
    });
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(key: _screen, child: const QuranReaderApp()));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settle(tester);
    expect(model.status, LoadStatus.ready);
  }

  testWidgets('store screenshots', skip: out.isEmpty, (tester) async {
    Future<void> shot(String name) async {
      await settle(tester);
      await tester.runAsync(() async {
        final boundary = _screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: _pixelRatio);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(out).createSync(recursive: true);
        File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    // 1. The opening page, offering to continue.
    await pumpApp(tester, dedication: true, saved: {'lastPage': 2, 'lastAyah': '2:3', 'lastListening': true});
    await shot('1-opening');
    await finish(tester);

    // 2. The Coloured mushaf with the ribbon on a bookmarked page.
    await pumpApp(tester);
    model.library.toggleBookmark(1, title: model.pageTitle(1));
    model.update(() {});
    await shot('2-coloured');

    // 3. Recitation by Salah Bukhatir, verse by verse.
    expect(model.audio.reciter, defaultReciterId);
    model.select(const AyahKey(1, 2));
    model.audio
      ..current = const AyahKey(1, 2)
      ..isPlaying = true
      ..changed();
    await shot('3-recitation');

    // 4. The reciters and repeat options.
    showAudioOptions(tester.element(find.byType(Home)));
    await shot('4-reciters');
    Navigator.of(tester.element(find.text(tr('Done')))).pop();
    model.audio.stop();
    model.select(null);
    await settle(tester);

    // 5. The side menu.
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await shot('5-index');
    tester.state<ScaffoldState>(find.byType(Scaffold).first).closeDrawer();
    await settle(tester);

    // 6. Settings, at Download Mus'haf.
    showSettings(tester.element(find.byType(Home)));
    await settle(tester);
    await tester.scrollUntilVisible(find.text(tr('All releases on GitHub')), 200,
        scrollable: find.descendant(of: find.byType(Dialog), matching: find.byType(Scrollable)).first);
    await shot('6-downloads');
    Navigator.of(tester.element(find.byType(Dialog))).pop();
    await finish(tester);

    // 7. Full screen, with the controls shown by a tap.
    await pumpApp(tester, saved: {'fullScreen': true, 'lastPage': 2});
    await tester.tapAt(Offset(_size.width / 2, _size.height / 2));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    await shot('7-fullscreen');
    await finish(tester);

    // 8. Night.
    await pumpApp(tester, dark: true, saved: {'theme': 'night', 'lastPage': 2});
    await shot('8-night');
    await finish(tester);
  });
}

/// Runs animations to their end and decodes images for real.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() async {
      for (final e in tester.elementList(find.byType(Image))) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pumpWidget(const SizedBox());
}
