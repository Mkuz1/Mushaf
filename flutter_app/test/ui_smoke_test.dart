import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quran_reader_hd/app_model.dart';
import 'package:quran_reader_hd/update/update_checker.dart';
import 'package:quran_reader_hd/core/l10n.dart';
import 'package:quran_reader_hd/core/quran.dart';
import 'package:quran_reader_hd/core/storage.dart';
import 'package:quran_reader_hd/data/meta.dart';
import 'package:quran_reader_hd/data/page_words.dart';
import 'package:quran_reader_hd/data/text_library.dart';
import 'package:quran_reader_hd/main.dart';
import 'package:quran_reader_hd/ui/dedication.dart';
import 'package:quran_reader_hd/ui/dock.dart';
import 'package:quran_reader_hd/ui/home.dart';
import 'package:quran_reader_hd/ui/inspector.dart';
import 'package:quran_reader_hd/ui/page_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screenshots go here when run with `--dart-define=OUT=<folder>`.
const out = String.fromEnvironment('OUT');
final _screen = GlobalKey();

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(rootBundle.load(f));
  }
  await loader.load();
}

/// Roboto and the icon font from the Flutter SDK, so screenshots show real text instead of test boxes.
Future<void> _sdkFonts({bool roboto = true}) async {
  final dir = Directory('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  Future<void> load(String family, bool Function(String) match) async {
    final loader = FontLoader(family);
    for (final f in dir.listSync().whereType<File>().where((f) => match(p.basename(f.path)))) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }

  if (roboto) await load('Roboto', (n) => n.startsWith('Roboto-'));
  await load('MaterialIcons', (n) => n.startsWith('MaterialIcons'));
}

/// The home screen at phone, unfolded-foldable and desktop sizes, with the repository's own page images
/// and ayah database, offline.
void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('qr');
    Paths.useDirectory(dir);
    File('../data/ayahinfo_1024.db').copySync(p.join(Paths.data.path, 'ayahinfo_1024.db'));
    for (final n in ['page001.png', 'page002.png', 'page042.png', 'page043.png']) {
      File('../pages/$n').copySync(p.join(Paths.pages.path, n));
    }
  });

  Future<void> pumpHome(WidgetTester tester, Size size,
      {List<ui.DisplayFeature> features = const [],
      String language = 'en',
      bool dark = false,
      bool meta = false,
      bool dedication = false,
      Map<String, Object> saved = const {}}) async {
    SharedPreferences.setMockInitialValues({'pagesChoiceMade': true, 'lastPage': 1, ...saved});
    final prefs = await SharedPreferences.getInstance();
    Localizer.init(prefs, Locale(language));
    tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    model = AppModel(prefs)..showDedication = dedication;
    // Words to colour red, as downloaded from quran.com on a device: the name of Allah in 1:1.
    model.words.allahWords[1] = {const WordRef(AyahKey(1, 1), 2)};
    // Offline there is no surah list; a short one with real names where the layout depends on them.
    if (meta) {
      model.meta = QuranMeta([
        Surah.fromJson({
          'number': 1, 'name': 'سُورَةُ ٱلْفَاتِحَةِ', 'englishName': 'Al-Faatiha', 'englishNameTranslation': 'The Opening',
          'numberOfAyahs': 7, 'revelationType': 'Meccan',
        }),
        Surah.fromJson({
          'number': 2, 'name': 'سُورَةُ البَقَرَةِ', 'englishName': 'Al-Baqara', 'englishNameTranslation': 'The Cow',
          'numberOfAyahs': 286, 'revelationType': 'Medinan',
        }),
      ], const [], const []);
    }
    clearPageCache();
    // A page image an earlier test left loading would never finish here, and precacheImage below would wait for it.
    imageCache
      ..clear()
      ..clearLiveImages();
    await tester.runAsync(() async {
      await _font('Amiri Quran', ['assets/fonts/AmiriQuran-Regular.ttf']);
      await _font('Amiri', ['assets/fonts/Amiri-Regular.ttf', 'assets/fonts/Amiri-Bold.ttf']);
      if (out.isNotEmpty) await _sdkFonts(roboto: language != 'ar');
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.displayFeatures = features;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(key: _screen, child: const QuranReaderApp()));
    // Let bootstrap open the database (and fail the network fetches quickly) and the pages decode.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Decode the page images for real before taking screenshots.
    await tester.runAsync(() async {
      for (final e in tester.elementList(find.byType(Image))) {
        final image = (e.widget as Image).image;
        await precacheImage(image, e);
      }
    });
    await tester.pump();
    expect(model.status, LoadStatus.ready);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (out.isEmpty) return;
    await tester.runAsync(() async {
      final boundary = _screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Future<void> finish(WidgetTester tester) async {
    // The delayed update check runs (and fails offline) before the test ends.
    await tester.pump(const Duration(seconds: 4));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('phone', (tester) async {
    await pumpHome(tester, const Size(412, 892));
    expect(model.effectiveDual, isFalse);
    await shot(tester, 'phone');
    model.showText(InspectorTab.translation, const AyahKey(1, 5));
    await tester.pump();
    await shot(tester, 'phone-inspector');
    await finish(tester);
  });


  testWidgets('full screen: the page alone, controls over it on a tap', (tester) async {
    await pumpHome(tester, const Size(412, 892), saved: {'fullScreen': true});
    expect(find.byType(AppBar), findsNothing);
    expect(model.controlsVisible, isFalse);
    // The page fills the screen's width, and nothing is kept free for the player.
    final pageHeight = tester.getSize(find.byType(MushafPage).first).height;
    expect(tester.getSize(find.byType(MushafPage).first).width, greaterThan(412 - 12));
    // A single tap waits out the double-tap window (double-tap recites); then the controls slide in.
    await tester.tapAt(const Offset(206, 446));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(model.controlsVisible, isTrue);
    expect(tester.getSize(find.byType(MushafPage).first).height, pageHeight);
    await shot(tester, 'fullscreen-controls');
    // They hide again by themselves.
    await tester.pump(const Duration(seconds: 6));
    expect(model.controlsVisible, isFalse);
    await tester.tap(find.byType(MushafPage).first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(model.controlsVisible, isTrue);
    await tester.tap(find.byIcon(Icons.fullscreen_exit));
    await tester.pump();
    expect(model.fullScreen, isFalse);
    expect(find.byType(AppBar), findsOneWidget);
    await finish(tester);
  });

  testWidgets('continue reading where it stopped', (tester) async {
    await pumpHome(tester, const Size(412, 892),
        dedication: true, saved: {'lastPage': 2, 'lastAyah': '2:3', 'lastListening': true});
    expect(find.text('Continue Reading'), findsOneWidget);
    expect(find.text('Continue Listening'), findsOneWidget);
    expect(find.text('Start from the Beginning'), findsOneWidget);
    expect(find.textContaining('Page 2 · Ayah 3'), findsOneWidget);
    await shot(tester, 'continue');
    await tester.ensureVisible(find.text('Continue Reading'));
    await tester.tap(find.text('Continue Reading'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(model.showDedication, isFalse);
    expect(model.selected, const AyahKey(2, 3));
    expect(model.visiblePages(), contains(2));
    await finish(tester);
  });

  testWidgets('first launch just begins', (tester) async {
    await pumpHome(tester, const Size(412, 892), dedication: true);
    expect(find.text('Begin Reading'), findsOneWidget);
    expect(find.text('Continue Reading'), findsNothing);
    await finish(tester);
  });

  testWidgets('opening page on a small phone', (tester) async {
    await pumpHome(tester, const Size(320, 640));
    model.showDedication = true;
    model.update(() {});
    await tester.pump();
    expect(find.byType(DedicationView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('unfolded foldable with a hinge', (tester) async {
    await pumpHome(tester, const Size(1080, 960), features: const [
      ui.DisplayFeature(
          bounds: Rect.fromLTWH(530, 0, 20, 960), type: ui.DisplayFeatureType.hinge, state: ui.DisplayFeatureState.postureFlat),
    ]);
    expect(model.effectiveDual, isTrue);
    await shot(tester, 'foldable');
    model.showText(InspectorTab.tafsir, const AyahKey(1, 5));
    await tester.pump();
    await shot(tester, 'foldable-inspector');
    await finish(tester);
  });

  testWidgets('desktop window', (tester) async {
    await pumpHome(tester, const Size(1440, 900));
    expect(model.effectiveDual, isTrue);
    model.select(const AyahKey(2, 3));
    await tester.pump();
    await shot(tester, 'desktop');
    await finish(tester);
  });

  // Android TV: a remote control has the arrows, OK and Back, and nothing to touch the screen with.
  FocusNode readerFocusForTest(WidgetTester tester) {
    FocusNode? reader;
    void visit(FocusNode n) {
      if (n.debugLabel == 'reader') reader = n;
      n.children.forEach(visit);
    }

    visit(FocusManager.instance.rootScope);
    return reader!;
  }

  String? focused() => FocusManager.instance.primaryFocus?.debugLabel;
  bool focusIn(String label) {
    for (FocusNode? n = FocusManager.instance.primaryFocus; n != null; n = n.parent) {
      if (n.debugLabel == label) return true;
    }
    return false;
  }

  /// The texts shown in the focused widget, to find where the remote is.
  List<String> focusedTexts() {
    final texts = <String>[];
    void visit(Element e) {
      final w = e.widget;
      if (w is Text && w.data != null) texts.add(w.data!);
      if (w is Tooltip && w.message != null) texts.add(w.message!);
      e.visitChildElements(visit);
    }

    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx is Element) {
      visit(ctx);
      // An icon button's tooltip wraps it.
      var depth = 0;
      ctx.visitAncestorElements((e) {
        final w = e.widget;
        if (w is Tooltip && w.message != null) texts.add(w.message!);
        return ++depth < 40 && w is! Tooltip;
      });
    }
    return texts;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    if (const bool.fromEnvironment('TVDEBUG')) {
      final chain = <String>[];
      FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
        chain.add(e.widget.runtimeType.toString());
        return chain.length < 14;
      });
      debugPrint('PRESS ${key.keyLabel} -> ${FocusManager.instance.primaryFocus} ${focusedTexts()} $chain');
    }
  }

  /// Presses down until [ayah] is selected (past the rest of long ayahs on the way).
  Future<void> pressUntilSelected(WidgetTester tester, AyahKey ayah) async {
    for (var i = 0; i < 20 && model.selected != ayah; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(model.selected, ayah);
  }

  testWidgets('TV remote: pages, title bar, player and side menu', (tester) async {
    await pumpHome(tester, const Size(960, 540), meta: true);
    expect(focused(), 'reader');
    // Left and right turn the spread (book order: left is the next one).
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(model.page, 3);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(model.page, 1);
    // Up reaches the title bar, where left and right move between its buttons instead of turning pages.
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusIn('title bar'), isTrue);
    final first = FocusManager.instance.primaryFocus;
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focusIn('title bar'), isTrue);
    expect(FocusManager.instance.primaryFocus, isNot(first));
    expect(model.page, 1);
    await shot(tester, 'tv-title-bar');
    // Down goes back to the page, and down again to the play button; up returns.
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'reader');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'play');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focusIn('player'), isTrue);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focused(), 'reader');
    // The title bar's first button opens the side menu, and the arrows reach into it.
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen, isTrue);
    await press(tester, LogicalKeyboardKey.arrowDown);
    final inDrawer = FocusManager.instance.primaryFocus?.context;
    expect(inDrawer?.findAncestorWidgetOfExactType<Drawer>(), isNotNull);
    await finish(tester);
  });

  testWidgets('TV remote: selecting ayahs and their menu', (tester) async {
    await pumpHome(tester, const Size(960, 540));
    // OK selects the first ayah; down and up step through the ayahs, on to the next page.
    await press(tester, LogicalKeyboardKey.select);
    expect(model.selected, const AyahKey(1, 1));
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(model.selected, const AyahKey(1, 2));
    await shot(tester, 'tv-ayah');
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(model.selected, const AyahKey(1, 1));
    for (var i = 0; i < 7; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(model.selected, const AyahKey(2, 1));
    expect(model.visiblePages(), contains(2));
    // OK on a selected ayah opens its menu; Back closes it, then leaves the ayah.
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text(tr('Play From Here')), findsOneWidget);
    await shot(tester, 'tv-ayah-menu');
    // Down reaches the menu's first item, and OK chooses it.
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<PopupMenuItem<VoidCallback>>(),
        isNotNull);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text(tr('Play From Here')), findsNothing);
    expect(focused(), 'reader');
    await press(tester, LogicalKeyboardKey.escape);
    expect(model.selected, isNull);
    await finish(tester);
  });

  testWidgets('TV remote in full screen', (tester) async {
    await pumpHome(tester, const Size(960, 540), saved: {'fullScreen': true});
    expect(focused(), 'reader');
    // Up shows the controls and focuses the title bar; when they hide again, focus goes back to the page.
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(model.controlsVisible, isTrue);
    expect(focusIn('title bar'), isTrue);
    await tester.pump(const Duration(seconds: 6));
    expect(model.controlsVisible, isFalse);
    expect(focused(), 'reader');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'play');
    await tester.pump(const Duration(milliseconds: 100));
    await shot(tester, 'tv-full-screen-player');
    // Back leaves full screen.
    await press(tester, LogicalKeyboardKey.escape);
    expect(model.fullScreen, isFalse);
    await finish(tester);
  });

  /// Presses [key] until the focused widget shows [text] (at most [tries] times).
  Future<void> pressUntil(WidgetTester tester, LogicalKeyboardKey key, String text, {int tries = 20}) async {
    for (var i = 0; i < tries && !focusedTexts().contains(text); i++) {
      await press(tester, key);
    }
    expect(focusedTexts(), contains(text), reason: 'pressing ${key.keyLabel} never reached "$text"');
  }

  testWidgets('TV remote: side menu tabs, search field and bookmarks', (tester) async {
    await pumpHome(tester, const Size(960, 540), meta: true);
    model.library.toggleBookmark(2, title: 'My bookmark');
    // The menu button opens the side menu.
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen, isTrue);
    // Up to the tabs, then along them to Bookmarks.
    await pressUntil(tester, LogicalKeyboardKey.arrowUp, tr('Surahs'));
    await pressUntil(tester, LogicalKeyboardKey.arrowRight, tr('Marks'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('My bookmark'), findsOneWidget);
    // Down through the sort buttons to the bookmark (its ⋮ menu first, the bookmark beside it), and OK opens its
    // page and closes the menu.
    await pressUntil(tester, LogicalKeyboardKey.arrowDown, 'Show menu');
    await pressUntil(tester, LogicalKeyboardKey.arrowLeft, 'My bookmark');
    await shot(tester, 'tv-side-menu');
    model.goTo(43); // away from the bookmark first
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.page, 2);
    expect(tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen, isFalse);
    expect(focused(), 'reader');

    // The surah filter: the remote passes through it without the keyboard opening, and OK opens it.
    model.goTo(43);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await pressUntil(tester, LogicalKeyboardKey.arrowUp, tr('Surahs'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'text field');
    expect(tester.testTextInput.isVisible, isFalse);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), isNot('text field'));
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focused(), 'text field');
    await press(tester, LogicalKeyboardKey.select);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    tester.testTextInput.enterText('Baq');
    await tester.pump();
    // Down leaves the field for the filtered list; OK opens the surah.
    await pressUntil(tester, LogicalKeyboardKey.arrowDown, 'Al-Baqara');
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.page, 2);
    await finish(tester);
  });

  testWidgets('TV remote: tafsir from the ayah menu, scrolled and changed', (tester) async {
    await pumpHome(tester, const Size(960, 540), meta: true, saved: {'tafsir': 'qc-tafsir-169'});
    // A long commentary for every ayah of Al-Fatiha, as if downloaded.
    model.text.chapters['qc-tafsir-169'] = {
      1: [for (var a = 1; a <= 7; a++) List.filled(80, 'Commentary on ayah $a.').join(' ')],
    };
    // OK selects 1:1, OK again opens its menu; down to Tafsir and OK.
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await pressUntil(tester, LogicalKeyboardKey.arrowDown, tr('Tafsir'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.showInspector, isTrue);
    expect(model.inspectorTab, InspectorTab.tafsir);
    // Focus is in the commentary: down scrolls it.
    expect(focused(), 'inspector text');
    ScrollPosition scroll() => tester
        .state<ScrollableState>(find.descendant(of: find.byType(KeyScroll), matching: find.byType(Scrollable)).first)
        .position;
    expect(scroll().pixels, 0);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(scroll().pixels, greaterThan(0));
    await shot(tester, 'tv-tafsir');
    // Left goes on to the next ayah's commentary.
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(model.selected, const AyahKey(1, 2));
    expect(focused(), 'inspector text');
    // Up from the top reaches the source menu; OK opens it, and another tafsir can be chosen.
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusedTexts(), contains(Edition.named('qc-tafsir-169').title));
    await shot(tester, 'tv-tafsir-source');
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.tafsirID, isNot('qc-tafsir-169'));
    // Back closes the tafsir and returns to the page; Back again leaves the ayah.
    await press(tester, LogicalKeyboardKey.escape);
    expect(model.showInspector, isFalse);
    expect(focused(), 'reader');
    expect(model.selected, isNotNull);
    await press(tester, LogicalKeyboardKey.escape);
    expect(model.selected, isNull);
    await finish(tester);
  });

  testWidgets('TV remote: the translation panel from the title bar keeps the arrows', (tester) async {
    await pumpHome(tester, const Size(960, 540), meta: true, saved: {'translation': 'en.sahih'});
    model.text.texts['en.sahih'] = [
      [for (var a = 1; a <= 7; a++) List.filled(60, 'Translation of ayah $a.').join(' ')],
    ];
    // The panel button, with no ayah selected: the panel opens on the page's first ayah, and the remote is in it.
    await press(tester, LogicalKeyboardKey.arrowUp);
    await pressUntil(tester, LogicalKeyboardKey.arrowRight, tr('Translation, tafsir and notes'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.showInspector, isTrue);
    expect(model.selected, const AyahKey(1, 1));
    expect(focused(), 'inspector text');
    // Down and up read the text without changing the ayah or the page.
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(model.selected, const AyahKey(1, 1));
    expect(model.page, 1);
    // Even from the page behind, the arrows go back into the panel.
    readerFocusForTest(tester).requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'inspector text');
    expect(model.selected, const AyahKey(1, 1));
    // Up from the top of the text reaches its tabs.
    for (var i = 0; i < 6 && focused() == 'inspector text'; i++) {
      await press(tester, LogicalKeyboardKey.arrowUp);
    }
    expect(focusIn('inspector'), isTrue);
    // The tabs: left and right stay in them, and OK changes the tab.
    await pressUntil(tester, LogicalKeyboardKey.arrowUp, tr('Tafsir'));
    for (var i = 0; i < 4; i++) {
      await press(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(focusedTexts(), contains(tr('Note')));
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.inspectorTab, InspectorTab.tafsir);
    expect(focusIn('inspector'), isTrue);
    // Up again is the ayah's buttons, where left and right stay in the panel too.
    await press(tester, LogicalKeyboardKey.arrowUp);
    for (var i = 0; i < 6; i++) {
      await press(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(focusIn('inspector'), isTrue);
    expect(focusedTexts(), contains(tr('Done')));
    await press(tester, LogicalKeyboardKey.escape);
    expect(model.showInspector, isFalse);
    expect(focused(), 'reader');
    await finish(tester);
  });

  testWidgets('TV remote: reading the translation view', (tester) async {
    await pumpHome(tester, const Size(960, 540), meta: true, saved: {'translation': 'en.sahih', 'study': 'both'});
    String long(String what) => List.filled(30, what).join(' ');
    model.text.texts[Edition.arabic.id] = [
      [for (var a = 1; a <= 7; a++) long('الحمد لله')],
      [for (var a = 1; a <= 286; a++) long('ذلك الكتاب')],
    ];
    model.text.texts['en.sahih'] = [
      [for (var a = 1; a <= 7; a++) long('Fatiha ayah $a.')],
      [for (var a = 1; a <= 286; a++) long('Baqara ayah $a.')],
    ];
    await press(tester, LogicalKeyboardKey.arrowUp);
    await pressUntil(tester, LogicalKeyboardKey.arrowRight, tr('Translation & Tafsir'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'reader');
    // Down scrolls the list; the mushaf page behind doesn't turn.
    ScrollPosition list() => tester
        .state<ScrollableState>(find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first)
        .position;
    await press(tester, LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(list().pixels, greaterThan(0));
    expect(model.page, 1);
    // Left is the next surah.
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('2. Al-Baqara'), findsWidgets);
    // OK selects the ayah at the top; down steps on to the next.
    await press(tester, LogicalKeyboardKey.select);
    expect(model.selected, const AyahKey(2, 1));
    // Down reads to the end of a long ayah first, then moves on.
    final rowTop = tester.getRect(find.textContaining('Baqara ayah 1.').first).top;
    await press(tester, LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(model.selected, const AyahKey(2, 1));
    expect(tester.getRect(find.textContaining('Baqara ayah 1.').first).top, lessThan(rowTop));
    await pressUntilSelected(tester, const AyahKey(2, 3));
    await tester.pumpAndSettle();
    // Its row has been scrolled into view.
    final row = tester.getRect(find.textContaining('Baqara ayah 3.').first);
    expect(row.top, inInclusiveRange(0, 540));
    await shot(tester, 'tv-translation-view');
    // Back leaves the ayah; up from the top of the list reaches the view's options.
    await press(tester, LogicalKeyboardKey.escape);
    expect(model.selected, isNull);
    for (var i = 0; i < 40 && focused() == 'reader'; i++) {
      await press(tester, LogicalKeyboardKey.arrowUp);
    }
    expect(focused(), isNot('reader'));
    expect(focusIn('title bar'), isFalse);
    await finish(tester);
  });

  testWidgets('TV remote: settings and recitation options', (tester) async {
    await pumpHome(tester, const Size(960, 540), meta: true);
    // The settings button is the title bar's last; OK opens it and the arrows move through it.
    await press(tester, LogicalKeyboardKey.arrowUp);
    await pressUntil(tester, LogicalKeyboardKey.arrowRight, tr('Settings'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await pressUntil(tester, LogicalKeyboardKey.arrowDown, tr('Check for Updates'), tries: 40);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // The recitation options from the player: the reciter list opens with OK and another reciter can be chosen.
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'play');
    await pressUntil(tester, LogicalKeyboardKey.arrowRight, tr('Reciter, scope and repeat'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await pressUntil(tester, LogicalKeyboardKey.arrowDown, 'Salah Bukhatir ★');
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.audio.reciter, isNot('Salaah_AbdulRahman_Bukhatir_128kbps'));
    await finish(tester);
  });

  testWidgets('TV remote: opening page and the translation view', (tester) async {
    await pumpHome(tester, const Size(960, 540), meta: true, dedication: true, saved: {'lastPage': 2, 'lastAyah': '2:3'});
    // The opening page starts on Continue Reading; up reaches the languages, down comes back.
    expect(focusedTexts(), contains(tr('Continue Reading')));
    await pressUntil(tester, LogicalKeyboardKey.arrowUp, 'Français');
    await press(tester, LogicalKeyboardKey.select);
    expect(Localizer.shared.language, AppLanguage.french);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.select);
    expect(Localizer.shared.language, AppLanguage.english);
    await pressUntil(tester, LogicalKeyboardKey.arrowDown, tr('Continue Reading'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.showDedication, isFalse);
    expect(focused(), 'reader');
    // The translation view, from the title bar.
    await press(tester, LogicalKeyboardKey.arrowUp);
    await pressUntil(tester, LogicalKeyboardKey.arrowRight, tr('Translation & Tafsir'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.mode, ReadingMode.text);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'reader');
    // OK and the arrows step through the ayahs there too.
    await press(tester, LogicalKeyboardKey.select);
    final first = model.selected;
    expect(first, isNotNull);
    await pressUntilSelected(tester, model.db!.next(first!)!);
    await press(tester, LogicalKeyboardKey.escape);
    expect(model.selected, isNull);
    // Up scrolls back to the top of the list, then reaches the view's own options, then the title bar.
    for (var i = 0; i < 40 && focused() == 'reader'; i++) {
      await press(tester, LogicalKeyboardKey.arrowUp);
    }
    expect(focused(), isNot('reader'));
    expect(focusIn('title bar'), isFalse);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusIn('title bar'), isTrue);
    await pressUntil(tester, LogicalKeyboardKey.arrowRight, tr('Mushaf'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.mode, ReadingMode.mushaf);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'reader');
    await finish(tester);
  });

  testWidgets('TV remote: the translation view options, from a selected ayah', (tester) async {
    await pumpHome(tester, const Size(960, 540), meta: true, saved: {'translation': 'en.sahih', 'study': 'both'});
    await press(tester, LogicalKeyboardKey.arrowUp);
    await pressUntil(tester, LogicalKeyboardKey.arrowRight, tr('Translation & Tafsir'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    expect(model.selected, const AyahKey(1, 1));
    // Up from the surah's first ayah reaches the options, on the display in use; the ayah stays selected.
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusIn('translation view options'), isTrue);
    expect(focusedTexts(), contains(tr('Both')));
    expect(model.selected, const AyahKey(1, 1));
    await shot(tester, 'tv-translation-options');
    // Left and right go through Arabic, Translation, Both and Tafsir, and OK picks one.
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusedTexts(), contains(tr('Translation')));
    await press(tester, LogicalKeyboardKey.select);
    expect(model.studyDisplay, StudyDisplay.translation);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusedTexts(), contains(tr('Arabic')));
    await press(tester, LogicalKeyboardKey.select);
    expect(model.studyDisplay, StudyDisplay.arabic);
    await pressUntil(tester, LogicalKeyboardKey.arrowRight, tr('Tafsir'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);
    await shot(tester, 'tv-translation-tafsir-chip');
    // The row ends at Tafsir rather than jumping to the title bar.
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedTexts(), contains(tr('Tafsir')));
    // Down is the list again, still on the ayah; up twice is the options, then the title bar.
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'reader');
    expect(model.selected, const AyahKey(1, 1));
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusIn('translation view options'), isTrue);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusIn('title bar'), isTrue);
    await finish(tester);
  });

  testWidgets('TV remote: the update banner', (tester) async {
    await pumpHome(tester, const Size(960, 540), meta: true);
    model.updates.available = AppUpdate('9.9', '', Uri.parse('https://example.com'), null);
    model.updates.notifyListeners();
    await tester.pumpAndSettle();
    // Up from the page is the banner's Download; up again the title bar, and down comes back to Download.
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusIn('update banner'), isTrue);
    expect(focusedTexts(), contains(tr('Download')));
    await shot(tester, 'tv-update');
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusIn('title bar'), isTrue);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedTexts(), contains(tr('Download')));
    // Left reaches the other buttons and stops at the first; OK on Later hides the banner.
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusedTexts(), contains(tr('Later')));
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusedTexts(), contains(tr('Skip This Version')));
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'reader');
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.updates.available, isNull);
    expect(focused(), 'reader');
    await finish(tester);
  });

  testWidgets('switching the language or dark mode animates the theme without an error', (tester) async {
    await pumpHome(tester, const Size(412, 892), dedication: true);
    // Each frame of the theme's animation is built (a theme value that can't be blended failed here).
    Future<void> frames() async {
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    for (final l in ['Français', 'العربية', 'English']) {
      await tester.tap(find.text(l));
      await frames();
    }
    expect(Localizer.shared.language, AppLanguage.english);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await frames();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await frames();
    await finish(tester);
  });

  testWidgets('subject colours: the palette button, by touch and with the TV remote', (tester) async {
    await pumpHome(tester, const Size(960, 540), meta: true);
    expect(model.showSubjects, isFalse);
    // The remote reaches it in the title bar; OK turns the colours on, and the key names each section.
    await press(tester, LogicalKeyboardKey.arrowUp);
    await pressUntil(tester, LogicalKeyboardKey.arrowRight, tr('Subjects'));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pump();
    expect(model.showSubjects, isTrue);
    expect(find.text('Al-Faatiha 1–7'), findsOneWidget);
    expect(find.text('Al-Baqara 1–7'), findsOneWidget);
    await shot(tester, 'tv-subjects');
    // A touch turns them off again, and the choice is kept.
    await tester.tap(find.byTooltip(tr('Subjects')));
    await tester.pump();
    expect(model.showSubjects, isFalse);
    expect(find.text('Al-Faatiha 1–7'), findsNothing);
    expect(model.prefs.getBool('subjects'), isFalse);
    await finish(tester);
  });

  testWidgets('phone in Arabic and dark mode, with the recitation options', (tester) async {
    // Interface text in Amiri (wider than Android's own Arabic font), so the fit below is a safe check. Fonts stay
    // loaded for later tests, so this test runs last.
    await tester.runAsync(() => _font('Roboto', ['assets/fonts/Amiri-Regular.ttf', 'assets/fonts/Amiri-Bold.ttf']));
    await pumpHome(tester, const Size(343, 760), language: 'ar', dark: true, meta: true);
    // The surah's full Arabic name fits beside the bar's actions.
    final title = tester.renderObject<RenderParagraph>(find.text('سُورَةُ ٱلْفَاتِحَةِ'));
    expect(title.didExceedMaxLines, isFalse);
    await shot(tester, 'phone-ar');
    showAudioOptions(tester.element(find.byType(Home)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await shot(tester, 'phone-ar-recitation');
    await tester.tap(find.text(tr('Done')));
    await tester.pumpAndSettle();
    await finish(tester);
  });
}
