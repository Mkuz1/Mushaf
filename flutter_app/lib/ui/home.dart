import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_model.dart';
import '../core/l10n.dart';
import '../core/quran.dart';
import 'ayah_menu.dart';
import 'common.dart';
import 'dedication.dart';
import 'dock.dart';
import 'inspector.dart';
import 'reader.dart';
import 'settings.dart';
import 'sidebar.dart';
import 'text_mode.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _scaffold = GlobalKey<ScaffoldState>();
  // Remote control (Android TV) and keyboard: the page, the title bar and the player each take focus; see
  // _readerKey and _barKey.
  final _readerFocus = FocusNode(debugLabel: 'reader');
  final _topBarFocus = FocusNode(debugLabel: 'title bar', skipTraversal: true);
  final _dockFocus = FocusNode(debugLabel: 'player', skipTraversal: true);
  final _playFocus = FocusNode(debugLabel: 'play');
  final _inspectorPanel = FocusNode(debugLabel: 'inspector', skipTraversal: true);
  final _inspectorText = FocusNode(debugLabel: 'inspector text');
  final _drawerFocus = FocusNode(debugLabel: 'side menu', skipTraversal: true);
  final _updateFocus = FocusNode(debugLabel: 'update banner', skipTraversal: true);
  final _textMode = GlobalKey<TextModeViewState>();
  bool _inspectorWasShown = false;

  /// The remote's ayah mode: started by OK on the page, it moves the arrows from the bars to the ayahs. A selection
  /// made otherwise (a touch, or Continue Reading) doesn't start it.
  bool _ayahMode = false;
  Timer? _hideControls;
  bool _controlsWereVisible = false;

  @override
  void initState() {
    super.initState();
    model.bootstrap();
    model.reminder.init(onOpen: model.openKahf).then((opened) {
      if (opened) model.openKahf();
    });
    model.addListener(_controlsChanged);
    Future<void>.delayed(const Duration(seconds: 3), model.updates.check);
  }

  @override
  void dispose() {
    model.removeListener(_controlsChanged);
    _hideControls?.cancel();
    for (final f in [_readerFocus, _topBarFocus, _dockFocus, _playFocus, _inspectorPanel, _inspectorText, _drawerFocus, _updateFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  /// Controls shown over a full-screen page hide again after a few seconds without a touch.
  void _controlsChanged() {
    final visible = model.fullScreen && model.controlsVisible;
    if (visible && !_controlsWereVisible) _restartHideTimer();
    if (!visible) {
      _hideControls?.cancel();
      // Focus doesn't stay on a control that has slid away.
      if (_controlsWereVisible && !_readerFocus.hasFocus) _readerFocus.requestFocus();
    }
    _controlsWereVisible = visible;
    // The translation and tafsir panel, opened from the remote or a keyboard (the ayah menu or the title bar): the
    // remote works in it, on the selected ayah (the first on the page if none was), until Back closes it.
    final opened = model.showInspector && !_inspectorWasShown;
    _inspectorWasShown = model.showInspector;
    if (opened && FocusManager.instance.highlightMode == FocusHighlightMode.traditional) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (model.selected == null) _selectFirstAyah();
        _ayahMode = true;
        _focusInspector();
      });
    }
  }

  /// Focus into the panel's text, once it has built (a frame after a selection).
  void _focusInspector() {
    if (_inspectorText.context != null) {
      _inspectorText.requestFocus();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _inspectorText.context != null) _inspectorText.requestFocus();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _restartHideTimer() {
    _hideControls?.cancel();
    _hideControls = Timer(const Duration(seconds: 5), () => model.showControls(false));
  }

  void _begin({bool resume = false, bool listen = false, bool fromStart = false}) {
    model.showDedication = false;
    model.update(() {});
    if (fromStart) model.goTo(1);
    if (resume) model.resume(listen: listen);
    // Reopened in full screen: hide the system bars again.
    if (model.fullScreen) model.applySystemBars();
    // First run: offer to install the pages (they are not shipped in the app).
    if (!model.pageStore.isInstalled && !(model.prefs.getBool('pagesChoiceMade') ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showPagesChoice(context);
      });
    }
    _readerFocus.requestFocus();
    // Once: ask to send the Friday reminder (the system's permission prompt, where there is one).
    model.reminder.offer();
  }

  /// Keys on the page. Left and right turn pages; up and down go to the title bar and the player; OK selects
  /// the first ayah. With an ayah selected, up and down move to the previous and next ayah (across pages), OK
  /// opens its menu, and Back (or Esc) leaves it.
  KeyEventResult _readerKey(FocusNode node, KeyEvent event) {
    // Controls inside the reader (the translation view's options) move between themselves.
    if (event is KeyUpEvent || !node.hasPrimaryFocus) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final arrow = key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
    if (!arrow && !_isOk(key)) return KeyEventResult.ignored;
    // While the translation and tafsir panel is open, the remote works in it, not on the page behind.
    if (model.showInspector && _inspectorText.context != null) {
      if (event is KeyDownEvent) _inspectorText.requestFocus();
      return KeyEventResult.handled;
    }
    if (model.selected == null) _ayahMode = false;
    final ayah = _ayahMode ? model.selected : null;
    // The translation view is a list: the arrows read it (up and down scroll, left and right change the surah)
    // rather than turning the mushaf's pages behind it.
    final list = model.mode == ReadingMode.text ? _textMode.currentState : null;
    if (_isOk(key)) {
      if (event is! KeyDownEvent) return KeyEventResult.handled;
      if (ayah != null) {
        _ayahMenu(ayah);
      } else {
        // Start from the ayah already highlighted here (where reading resumed), else the first in view.
        _ayahMode = true;
        final selected = model.selected;
        final shown = selected != null && model.visiblePages().contains(model.db?.page(selected));
        if (list != null) {
          final top = list.firstVisibleAyah();
          if (top != null && !(shown && selected.sura == top.sura)) model.select(top);
          if (model.selected == null) _selectFirstAyah();
        } else if (!shown) {
          _selectFirstAyah();
        }
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      // Arabic books open right-to-left: the left arrow is the next page (or surah).
      final next = key == LogicalKeyboardKey.arrowLeft;
      if (list != null) {
        final sura = list.stepSurah(next: next);
        if (ayah != null && sura != null) model.select(AyahKey(sura, 1));
      } else {
        model.turn(forward: next);
        if (ayah != null) _selectFirstAyah();
      }
      return KeyEventResult.handled;
    }
    final down = key == LogicalKeyboardKey.arrowDown;
    if (ayah != null && list != null && list.scrollWithin(ayah, down: down)) {
      // The rest of a long ayah first.
    } else if (ayah != null) {
      final db = model.db;
      final next = db == null ? null : (down ? db.next(ayah) : db.previous(ayah));
      if (list != null && !down && (next == null || next.sura != ayah.sura)) {
        // Up from a surah's first ayah: the view's options (another surah is left and right).
        if (event is KeyDownEvent) _focusBar(top: true);
      } else if (next != null) {
        model.goToAyah(next);
        list?.reveal(next);
      }
    } else if (list != null) {
      if (!list.scrollPage(down: down) && event is KeyDownEvent) _focusBar(top: !down);
    } else if (event is KeyDownEvent) {
      _focusBar(top: !down);
    }
    return KeyEventResult.handled;
  }

  static bool _isOk(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.gameButtonA;

  void _selectFirstAyah() {
    final starts = [for (final p in model.visiblePages()) ?model.firstAyah(p)]..sort();
    if (starts.isNotEmpty) model.select(starts.first);
  }

  void _ayahMenu(AyahKey key) {
    final context = _readerFocus.context;
    final box = context?.findRenderObject() as RenderBox?;
    if (context == null || box == null) return;
    showAyahMenu(context, key, box.localToGlobal(box.size.center(Offset.zero)));
  }

  /// Moves focus from the page to the title bar's first button or the player's play button, showing them
  /// first in full screen.
  void _focusBar({required bool top}) {
    void focus() {
      if (!mounted) return;
      // In the translation view, its own options at the top of the page come before the title bar.
      if (top && (_textMode.currentState?.focusOptions() ?? false)) return;
      final target = top ? _aboveReader() : (_playFocus.context != null ? _playFocus : _dockFocus.traversalDescendants.firstOrNull);
      target?.requestFocus();
    }

    if (_immersive && !model.controlsVisible) {
      model.showControls(true);
      WidgetsBinding.instance.addPostFrameCallback((_) => focus());
    } else {
      focus();
    }
  }

  /// The banner goes with its buttons: a remote that was on one goes back to the page rather than nowhere.
  void _closeUpdate(VoidCallback action) {
    final had = _updateFocus.hasFocus;
    action();
    if (had) _readerFocus.requestFocus();
  }

  /// Above the page (and the translation view's options): the update banner's Download button when it shows,
  /// else the title bar.
  FocusNode? _aboveReader() =>
      _updateFocus.traversalDescendants.lastOrNull ?? _topBarFocus.traversalDescendants.firstOrNull;

  /// Keys in the title bar and the player: left and right move between their buttons (Flutter's own
  /// directional focus); down from the title bar, or up from the player, goes back to the page.
  KeyEventResult _barKey(KeyEvent event, {required bool top}) {
    if (_immersive) _restartHideTimer();
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == (top ? LogicalKeyboardKey.arrowDown : LogicalKeyboardKey.arrowUp)) {
      final banner = top ? _updateFocus.traversalDescendants.lastOrNull : null;
      (banner ?? _readerFocus).requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // A click or touch on the page gives it the keys back (after typing in the side menu's search, say).
  Widget _remoteReader(Widget reader) => Listener(
        onPointerDown: (_) {
          if (!_readerFocus.hasPrimaryFocus) _readerFocus.requestFocus();
        },
        child: Focus(focusNode: _readerFocus, autofocus: true, onKeyEvent: _readerKey, child: reader),
      );

  Widget _inspector(VoidCallback onClose) => Focus(
        focusNode: _inspectorPanel,
        child: AyahInspector(onClose: onClose, textFocus: _inspectorText),
      );

  Widget _remoteDock(Widget dock) =>
      Focus(focusNode: _dockFocus, onKeyEvent: (_, e) => _barKey(e, top: false), child: dock);

  Widget _remoteBar(Widget bar) =>
      Focus(focusNode: _topBarFocus, onKeyEvent: (_, e) => _barKey(e, top: true), child: bar);

  @override
  Widget build(BuildContext context) {
    return ModelBuilder(
      also: [model.updates],
      builder: (context) {
        if (model.showDedication) {
          return DedicationView(
            onContinue: () => _begin(resume: true),
            onListen: () => _begin(resume: true, listen: true),
            onStartOver: () => _begin(fromStart: true),
          );
        }
        return CallbackShortcuts(
          bindings: {
            // The arrows and OK are the page's own (_readerKey), so they move between buttons elsewhere.
            const SingleActivator(LogicalKeyboardKey.space): playPause,
            const SingleActivator(LogicalKeyboardKey.mediaPlayPause): playPause,
            const SingleActivator(LogicalKeyboardKey.mediaPlay): playPause,
            const SingleActivator(LogicalKeyboardKey.mediaPause): playPause,
            const SingleActivator(LogicalKeyboardKey.mediaStop): model.audio.stop,
            const SingleActivator(LogicalKeyboardKey.mediaFastForward): () => model.audio.skip(true),
            const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () => model.audio.skip(true),
            const SingleActivator(LogicalKeyboardKey.mediaRewind): () => model.audio.skip(false),
            const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): () => model.audio.skip(false),
            const SingleActivator(LogicalKeyboardKey.channelUp): () => model.turn(forward: false),
            const SingleActivator(LogicalKeyboardKey.channelDown): () => model.turn(forward: true),
            const SingleActivator(LogicalKeyboardKey.escape): _back,
            const SingleActivator(LogicalKeyboardKey.f11): () => model.setFullScreen(!model.fullScreen),
            const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
                model.library.toggleBookmark(model.page, title: model.pageTitle(model.page)),
          },
          // Back leaves the translation or tafsir, a selected ayah, then full screen, before it leaves the app.
          child: PopScope(
            canPop: !model.fullScreen && model.selected == null && !model.showInspector,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _back();
            },
            child: _immersive ? _fullScreen(context) : _scaffoldFor(context),
          ),
        );
      },
    );
  }

  void _back() {
    if (model.showInspector) {
      model.showInspector = false;
      model.update(() {});
    } else if (model.selected != null) {
      model.select(null);
      _ayahMode = false;
    } else if (model.fullScreen) {
      model.setFullScreen(false);
    }
    _readerFocus.requestFocus();
  }

  void _enterFullScreen(BuildContext context) {
    model.setFullScreen(true);
    toast(context, tr('Tap the page to show the controls.'));
  }

  bool get _immersive => model.fullScreen && model.mode == ReadingMode.mushaf && model.status == LoadStatus.ready;

  /// Full screen: the page alone, edge to edge. A tap shows the title bar and the player over the page (it
  /// doesn't move), and they hide again after a few seconds; recitation carries on underneath.
  Widget _fullScreen(BuildContext context) {
    final mq = MediaQuery.of(context);
    final compact = mq.size.width < 600;
    final shown = model.controlsVisible;
    final page = model.page;
    final scheme = Theme.of(context).colorScheme;
    void closeInspector() {
      model.showInspector = false;
      model.update(() {});
    }

    Widget overlay(Widget child, {required bool top}) => IgnorePointer(
          ignoring: !shown,
          child: AnimatedSlide(
            offset: shown ? Offset.zero : Offset(0, top ? -1 : 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: shown ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: Listener(onPointerDown: (_) => _restartHideTimer(), child: top ? _remoteBar(child) : child),
            ),
          ),
        );

    return Scaffold(
      body: Stack(children: [
        // Taps beside the page (the desk) toggle the controls too.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => model.showControls(!shown),
            child: _remoteReader(MushafReader(fold: verticalFold(mq), edgeToEdge: true)),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: overlay(
            top: true,
            Material(
              color: scheme.surface.withValues(alpha: 0.92),
              elevation: 2,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: kToolbarHeight,
                  child: Row(children: [
                    IconButton(
                      onPressed: () => model.setFullScreen(false),
                      icon: const Icon(Icons.fullscreen_exit),
                      tooltip: tr('Exit Full Screen'),
                    ),
                    Expanded(child: _title(context, page, compact)),
                    IconButton(
                      onPressed: () => model.library.toggleBookmark(page, title: model.pageTitle(page)),
                      icon: Icon(model.library.isBookmarked(page) ? Icons.bookmark : Icons.bookmark_border),
                      tooltip: tr('Bookmark this page'),
                    ),
                    IconButton(
                      onPressed: () {
                        model.showInspector = !model.showInspector;
                        model.update(() {});
                      },
                      icon: const Icon(Icons.vertical_split_outlined),
                      tooltip: tr('Translation, tafsir and notes'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 10 + mq.padding.bottom,
          child: overlay(
            top: false,
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: _remoteDock(
                    Dock(compact: mq.size.width < 1000, oneRow: mq.size.width >= 760, playFocus: _playFocus)),
              ),
            ),
          ),
        ),
        if (model.showInspector)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: mq.size.height * 0.5,
            child: Material(
              elevation: 12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(top: false, child: _inspector(closeInspector)),
            ),
          ),
      ]),
    );
  }

  Widget _scaffoldFor(BuildContext context) {
    final mq = MediaQuery.of(context);
    final vFold = verticalFold(mq);
    final hFold = horizontalFold(mq);
    final width = mq.size.width;
    final wide = width >= 1100 && vFold == null;
    final medium = width >= 760 && vFold == null;
    final compactBar = width < 600;
    final ready = model.status == LoadStatus.ready;

    Widget body;
    if (!ready) {
      body = _status(context);
    } else {
      // With the side menu showing (wide screens), the dock sits at its foot, so the pages get the full height;
      // otherwise it floats over the foot of the reader, which keeps its height (slider and recitation row) free.
      final dockInSidebar = wide && hFold == null;
      final oneRowDock = medium;
      final dockSpace = hFold == null && !dockInSidebar ? Dock.reserved(oneRow: oneRowDock) + mq.padding.bottom : 0.0;
      final reader = _remoteReader(model.mode == ReadingMode.mushaf
          ? MushafReader(fold: vFold != null && !model.showInspector ? vFold : null, bottomInset: dockSpace)
          : TextModeView(
              key: _textMode,
              onOptionsUp: () => _aboveReader()?.requestFocus(),
              onOptionsDown: _readerFocus.requestFocus,
            ));
      final readerWithDock = Stack(children: [
        Positioned.fill(child: reader),
        if (hFold == null && !dockInSidebar)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10 + mq.padding.bottom,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: oneRowDock ? 1180 : 980),
                child: _remoteDock(Dock(
                    compact: compactBar || (oneRowDock && width < 1000), oneRow: oneRowDock, playFocus: _playFocus)),
              ),
            ),
          ),
      ]);
      void closeInspector() {
        model.showInspector = false;
        model.update(() {});
      }

      if (hFold != null) {
        // Tabletop posture: the page above the fold, controls and the inspector below it.
        final top = hFold.top - mq.padding.top - kToolbarHeight;
        body = Column(children: [
          SizedBox(height: top.clamp(100, mq.size.height), child: reader),
          SizedBox(height: hFold.height),
          Expanded(
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: _remoteDock(Dock(compact: compactBar, playFocus: _playFocus))),
              if (model.showInspector) Expanded(child: _inspector(closeInspector)),
            ]),
          ),
        ]);
      } else if (vFold != null && model.showInspector) {
        // Unfolded: the page on one half of the hinge, its translation or tafsir on the other.
        body = Row(children: [
          SizedBox(width: vFold.left, child: readerWithDock),
          SizedBox(width: vFold.width),
          Expanded(child: Material(child: SafeArea(left: false, child: _inspector(closeInspector)))),
        ]);
      } else if (medium) {
        body = Row(children: [
          if (wide)
            SizedBox(
              width: 300,
              child: Material(
                child: Column(children: [
                  const Expanded(child: Sidebar()),
                  if (dockInSidebar)
                    Padding(
                      padding: EdgeInsets.fromLTRB(8, 4, 8, 8 + mq.padding.bottom),
                      child: _remoteDock(Dock(compact: true, playFocus: _playFocus)),
                    ),
                ]),
              ),
            ),
          if (wide) const VerticalDivider(width: 1),
          Expanded(child: readerWithDock),
          if (model.showInspector) ...[
            const VerticalDivider(width: 1),
            SizedBox(width: wide ? 380 : 340, child: Material(child: _inspector(closeInspector))),
          ],
        ]);
      } else {
        // Phones: the inspector slides up over the lower part of the page.
        body = Stack(children: [
          Positioned.fill(child: readerWithDock),
          if (model.showInspector)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: mq.size.height * 0.55,
              child: Material(
                elevation: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(top: false, child: _inspector(closeInspector)),
              ),
            ),
        ]);
      }
    }

    final update = model.updates.available;
    return Scaffold(
      key: _scaffold,
      appBar: _barWithFocus(_appBar(context, compact: compactBar, sidebarInDrawer: !wide)),
      drawer: wide
          ? null
          : Drawer(
              width: 320,
              child: SafeArea(
                child: Focus(
                  focusNode: _drawerFocus,
                  child: Sidebar(onNavigate: () {
                    _scaffold.currentState?.closeDrawer();
                    _readerFocus.requestFocus();
                  }),
                ),
              ),
            ),
      // Opened from the remote or a keyboard, the side menu starts on its first tab; closed, focus is back on the
      // page.
      onDrawerChanged: (open) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!open) {
          if (!_readerFocus.hasFocus) _readerFocus.requestFocus();
        } else if (FocusManager.instance.highlightMode == FocusHighlightMode.traditional) {
          _drawerFocus.traversalDescendants.firstOrNull?.requestFocus();
        }
      }),
      body: Column(children: [
        if (update != null)
          RemoteRow(
            focusNode: _updateFocus,
            onUp: () => _topBarFocus.traversalDescendants.firstOrNull?.requestFocus(),
            onDown: _readerFocus.requestFocus,
            child: MaterialBanner(
              leading: const Icon(Icons.system_update, color: AppColors.accent),
              content: Text(tr('Mushaf %@ is available. You have %@.', [update.version, model.updates.currentVersion])),
              actions: [
                TextButton(onPressed: () => _closeUpdate(model.updates.skip), child: Text(tr('Skip This Version'))),
                TextButton(onPressed: () => _closeUpdate(model.updates.dismiss), child: Text(tr('Later'))),
                FilledButton(
                  onPressed: () => _closeUpdate(() {
                    launchUrl(update.download ?? update.page, mode: LaunchMode.externalApplication);
                    model.updates.dismiss();
                  }),
                  child: Text(tr('Download')),
                ),
              ],
            ),
          ),
        Expanded(child: body),
      ]),
    );
  }

  Widget _status(BuildContext context) {
    if (model.status == LoadStatus.failed) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off, size: 40),
          const SizedBox(height: 8),
          Text(tr("Couldn't load the mushaf"), style: Theme.of(context).textTheme.titleMedium),
          Padding(padding: const EdgeInsets.all(8), child: Text(model.statusMessage, textAlign: TextAlign.center)),
          FilledButton(onPressed: model.bootstrap, child: Text(tr('Try Again'))),
        ]),
      );
    }
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(tr(model.statusMessage)),
      ]),
    );
  }

  PreferredSizeWidget _barWithFocus(PreferredSizeWidget bar) =>
      PreferredSize(preferredSize: bar.preferredSize, child: _remoteBar(bar));

  PreferredSizeWidget _appBar(BuildContext context, {required bool compact, required bool sidebarInDrawer}) {
    final ready = model.status == LoadStatus.ready;
    final page = model.page;
    final marked = model.library.isBookmarked(page);
    return AppBar(
      titleSpacing: sidebarInDrawer ? 0 : 16,
      title: ready ? _title(context, page, compact) : Text(tr('Mushaf')),
      actions: compact ? _compactActions(context, ready: ready, marked: marked) : [
        if (ready) ...[
          // Book order whatever the UI language: "next" sits on the left.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                onPressed: page < Quran.pageCount ? () => model.turn(forward: true) : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: tr('Next page'),
              ),
              if (!compact) _PageField(page: page),
              IconButton(
                onPressed: page > 1 ? () => model.turn(forward: false) : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: tr('Previous page'),
              ),
            ]),
          ),
          IconButton(
            onPressed: () => model.update(
                () => model.mode = model.mode == ReadingMode.mushaf ? ReadingMode.text : ReadingMode.mushaf),
            icon: Icon(model.mode == ReadingMode.mushaf ? Icons.notes : Icons.menu_book),
            tooltip: tr(model.mode == ReadingMode.mushaf ? 'Translation & Tafsir' : 'Mushaf'),
          ),
          IconButton(
            onPressed: () => model.update(() => model.showSubjects = !model.showSubjects),
            icon: Icon(model.showSubjects ? Icons.palette : Icons.palette_outlined),
            tooltip: tr('Subjects'),
          ),
          IconButton(
            onPressed: () => model.library.toggleBookmark(page, title: model.pageTitle(page)),
            icon: Icon(marked ? Icons.bookmark : Icons.bookmark_border),
            tooltip: tr('Bookmark this page'),
          ),
          IconButton(
            onPressed: () {
              model.showInspector = !model.showInspector;
              model.update(() {});
            },
            icon: Icon(model.showInspector ? Icons.vertical_split : Icons.vertical_split_outlined),
            tooltip: tr('Translation, tafsir and notes'),
          ),
          if (model.mode == ReadingMode.mushaf)
            IconButton(
              onPressed: () => _enterFullScreen(context),
              icon: const Icon(Icons.fullscreen),
              tooltip: tr('Full Screen'),
            ),
        ],
        IconButton(
          onPressed: () => showSettings(context),
          icon: Badge(isLabelVisible: model.updates.available != null, child: const Icon(Icons.settings_outlined)),
          tooltip: tr('Settings'),
        ),
      ],
    );
  }

  /// "2. Al-Baqara · Page 17" over "Juz' 1 · ¼ Hizb 2"; on phones the surah alone over "Page 17 · Juz' 1 · …".
  Widget _title(BuildContext context, int page, bool compact) {
    final first = model.firstAyah(page);
    final position = "${tr("Juz' %d", [model.juzFor(page)])} · ${AppModel.quarterLabel(model.quarterIndex(page))}";
    final (title, subtitle) = compact
        ? (first == null ? tr('Page %d', [page]) : model.surahName(first.sura), '${tr('Page %d', [page])} · $position')
        : (model.pageTitle(page), position);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: compact ? const TextStyle(fontSize: 18) : null),
      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  /// Phones: the title needs the room, so only bookmark and the inspector stay in the bar (pages turn by
  /// swiping); the reading mode and settings move into a menu.
  List<Widget> _compactActions(BuildContext context, {required bool ready, required bool marked}) {
    final page = model.page;
    return [
      if (ready) ...[
        IconButton(
          onPressed: () => model.update(() => model.showSubjects = !model.showSubjects),
          icon: Icon(model.showSubjects ? Icons.palette : Icons.palette_outlined),
          tooltip: tr('Subjects'),
        ),
        IconButton(
          onPressed: () => model.library.toggleBookmark(page, title: model.pageTitle(page)),
          icon: Icon(marked ? Icons.bookmark : Icons.bookmark_border),
          tooltip: tr('Bookmark this page'),
        ),
        IconButton(
          onPressed: () {
            model.showInspector = !model.showInspector;
            model.update(() {});
          },
          icon: Icon(model.showInspector ? Icons.vertical_split : Icons.vertical_split_outlined),
          tooltip: tr('Translation, tafsir and notes'),
        ),
      ],
      PopupMenuButton<VoidCallback>(
        icon: Badge(isLabelVisible: model.updates.available != null, child: const Icon(Icons.more_vert)),
        onSelected: (action) => action(),
        itemBuilder: (context) => [
          if (ready)
            PopupMenuItem(
              value: () => model.update(
                  () => model.mode = model.mode == ReadingMode.mushaf ? ReadingMode.text : ReadingMode.mushaf),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(model.mode == ReadingMode.mushaf ? Icons.notes : Icons.menu_book),
                title: Text(tr(model.mode == ReadingMode.mushaf ? 'Translation & Tafsir' : 'Mushaf')),
              ),
            ),
          if (ready && model.mode == ReadingMode.mushaf)
            PopupMenuItem(
              value: () => _enterFullScreen(context),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fullscreen),
                title: Text(tr('Full Screen')),
              ),
            ),
          PopupMenuItem(
            value: () => showSettings(context),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Badge(
                  isLabelVisible: model.updates.available != null, child: const Icon(Icons.settings_outlined)),
              title: Text(tr('Settings')),
            ),
          ),
        ],
      ),
    ];
  }
}

class _PageField extends StatefulWidget {
  final int page;
  const _PageField({required this.page});

  @override
  State<_PageField> createState() => _PageFieldState();
}

class _PageFieldState extends State<_PageField> {
  late final _controller = TextEditingController(text: '${widget.page}');
  // Not a stop for the remote's arrows: on a TV, focusing it would bring up the on-screen keyboard. The ‹ › buttons
  // beside it and the page itself turn pages.
  final _focus = FocusNode(skipTraversal: true);

  @override
  void didUpdateWidget(_PageField old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) _controller.text = '${widget.page}';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 56,
        child: Tooltip(
          message: tr('Go to page (1–604)'),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            onSubmitted: (v) {
              final p = int.tryParse(v);
              if (p != null) {
                model.goTo(p);
              } else {
                _controller.text = '${model.page}';
              }
            },
          ),
        ),
      );
}
