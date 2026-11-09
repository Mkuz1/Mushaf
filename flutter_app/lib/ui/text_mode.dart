import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../core/l10n.dart';
import '../core/quran.dart';
import '../data/text_library.dart';
import 'ayah_menu.dart';
import 'common.dart';

/// Translation/tafsir-only mode: the current surah as a scrolling list of ayahs.
class TextModeView extends StatefulWidget {
  /// Where a remote control goes from the view's options: up (the title bar) and down (the list).
  final VoidCallback? onOptionsUp;
  final VoidCallback? onOptionsDown;
  const TextModeView({super.key, this.onOptionsUp, this.onOptionsDown});

  @override
  State<TextModeView> createState() => TextModeViewState();
}

/// Public for the remote control (Home's keys): it scrolls the list, finds the ayah at the top and shows an ayah.
class TextModeViewState extends State<TextModeView> {
  bool _showTafsir = false;
  final _scroll = ScrollController();
  final _options = FocusNode(debugLabel: 'translation view options');
  final Map<int, GlobalKey> _rowKeys = {};
  AyahKey? _lastAudio;
  String? _ensured;

  /// The surah jumped to, kept while its page shows: many surahs start part-way down a page.
  int? _jumped;

  /// The surah shown: the selected ayah's, or the one jumped to, when on this page; else the page's first.
  int get _sura {
    final page = model.page, db = model.db;
    final onPage = db?.ayahs(page) ?? const <AyahKey>[];
    final selected = model.selected;
    if (selected != null && onPage.contains(selected)) return selected.sura;
    if (_jumped != null && onPage.any((k) => k.sura == _jumped)) return _jumped!;
    return model.firstAyah(page)?.sura ?? 1;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _options.dispose();
    super.dispose();
  }

  void _jump(int n) {
    _jumped = n;
    model.goTo(model.startPage(n));
    // A surah starting on the page already shown: nothing turns, but the list changes.
    setState(() {});
  }

  /// Moves a remote control to the view's options (surah, Arabic / Translation / Both, Tafsir), at the display
  /// choice in use; false when they aren't shown.
  bool focusOptions() {
    final items = _options.traversalDescendants.toList();
    if (items.isEmpty) return false;
    // The segments come after the surah arrows (one of them disabled on the first and last surah).
    final arrows = (_sura > 1 ? 1 : 0) + (_sura < 114 ? 1 : 0);
    final at = arrows + StudyDisplay.values.indexOf(model.studyDisplay);
    items[at < items.length ? at : 0].requestFocus();
    return true;
  }

  /// Scrolls a screenful (less a little) down or up; false at the end, where the arrow moves focus on instead.
  bool scrollPage({required bool down}) {
    if (!_scroll.hasClients) return false;
    final p = _scroll.position;
    final target = (p.pixels + (down ? 1 : -1) * math.max(60.0, p.viewportDimension * 0.8)).clamp(0.0, p.maxScrollExtent);
    if ((target - p.pixels).abs() < 1) return false;
    _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    return true;
  }

  /// The next or previous surah (book order: the left arrow is the next one), from its top; null at either end.
  int? stepSurah({required bool next}) {
    final target = _sura + (next ? 1 : -1);
    if (target < 1 || target > 114) return null;
    _jump(target);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    return target;
  }

  /// The first ayah whose row shows at the top of the list.
  AyahKey? firstVisibleAyah() {
    final list = _scroll.hasClients ? _scroll.position.context.notificationContext?.findRenderObject() : null;
    if (list is! RenderBox) return null;
    final top = list.localToGlobal(Offset.zero).dy;
    final keys = _rowKeys.keys.toList()..sort();
    for (final ayah in keys) {
      final box = _rowKeys[ayah]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached && box.localToGlobal(Offset(0, box.size.height)).dy > top + 8) {
        return AyahKey(_sura, ayah);
      }
    }
    return null;
  }

  /// Scrolls within an ayah taller than the screen (a long tafsir) before the arrows move on to the next ayah; false
  /// when the rest of it already shows.
  bool scrollWithin(AyahKey key, {required bool down}) {
    final row = _rowKeys[key.ayah]?.currentContext?.findRenderObject();
    final list = _scroll.hasClients ? _scroll.position.context.notificationContext?.findRenderObject() : null;
    if (row is! RenderBox || list is! RenderBox || key.sura != _sura) return false;
    final view = list.localToGlobal(Offset.zero) & list.size;
    final box = row.localToGlobal(Offset.zero) & row.size;
    // The bottom 140 of the list is under the player.
    final hidden = down ? box.bottom - (view.bottom - 140) : view.top - box.top;
    if (hidden <= 8) return false;
    final p = _scroll.position;
    final step = math.min(hidden, math.max(60.0, p.viewportDimension * 0.7));
    _scroll.animateTo((p.pixels + (down ? step : -step)).clamp(0.0, p.maxScrollExtent),
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    return true;
  }

  /// Brings an ayah's row into view (on another surah too). The list only builds rows near the screen, so a far one
  /// is reached a screenful at a time.
  void reveal(AyahKey key, {int tries = 12}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || key.sura != _sura) return;
      final ctx = _rowKeys[key.ayah]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx, alignment: 0.2, duration: const Duration(milliseconds: 220));
        return;
      }
      if (tries == 0 || !_scroll.hasClients) return;
      final built = [for (final e in _rowKeys.entries) if (e.value.currentContext != null) e.key];
      if (built.isEmpty) return;
      final p = _scroll.position;
      final below = key.ayah > built.reduce(math.max);
      _scroll.jumpTo((p.pixels + (below ? 1 : -1) * p.viewportDimension).clamp(0.0, p.maxScrollExtent));
      reveal(key, tries: tries - 1);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Fetches once per surah and edition choice; Retry is a sura change or a new edition, not every rebuild.
  void _ensureTexts() {
    final tag = '${model.translationID}/${model.tafsirID}/$_sura/$_showTafsir';
    if (tag == _ensured) return;
    _ensured = tag;
    model.text.ensure(model.translationID);
    if (_showTafsir) model.text.ensure(model.tafsirID, sura: _sura);
  }

  @override
  Widget build(BuildContext context) {
    return ModelBuilder(
      also: [model.text, model.audio, model.library],
      builder: (context) {
        final sura = _sura;
        final count = model.db?.ayahCounts[sura] ?? 0;
        _ensureTexts();
        _followAudio(sura);
        final s = model.surah(sura);
        final theme = Theme.of(context);
        return Container(
          color: theme.brightness == Brightness.dark ? AppColors.paperDark : AppColors.paperLight,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: RemoteRow(
                focusNode: _options,
                onUp: widget.onOptionsUp,
                onDown: widget.onOptionsDown,
                child: Material(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              onPressed: sura > 1 ? () => _jump(sura - 1) : null, icon: const Icon(Icons.chevron_left)),
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(model.surahTitle(sura), style: theme.textTheme.titleSmall),
                            if (s != null)
                              Text(
                                '${Localizer.shared.language == AppLanguage.arabic ? s.englishName : s.englishNameTranslation}'
                                ' · ${tr(s.revelationType == 'Meccan' ? 'Makki' : 'Madani')} · ${tr('%d verses', [s.numberOfAyahs])}',
                                style: theme.textTheme.bodySmall,
                              ),
                          ]),
                          IconButton(
                              onPressed: sura < 114 ? () => _jump(sura + 1) : null, icon: const Icon(Icons.chevron_right)),
                        ]),
                        SegmentedButton<StudyDisplay>(
                          segments: [
                            for (final d in StudyDisplay.values) ButtonSegment(value: d, label: Text(tr(d.label)))
                          ],
                          selected: {model.studyDisplay},
                          showSelectedIcon: false,
                          style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          onSelectionChanged: (v) => model.update(() => model.studyDisplay = v.first),
                        ),
                        FilterChip(
                          label: Text(tr('Tafsir')),
                          selected: _showTafsir,
                          onSelected: (v) => setState(() => _showTafsir = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 140),
                itemCount: count,
                itemBuilder: (context, i) => _row(context, AyahKey(sura, i + 1)),
              ),
            ),
          ]),
        );
      },
    );
  }

  void _followAudio(int sura) {
    final c = model.audio.current;
    if (c == null || c == _lastAudio || c.sura != sura) return;
    _lastAudio = c;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _rowKeys[c.ayah]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 300));
      }
    });
  }

  Widget _row(BuildContext context, AyahKey key) {
    final active = model.audio.current == key;
    final selected = model.selected == key;
    final translation = Edition.named(model.translationID);
    final t = model.studyDisplay != StudyDisplay.arabic ? model.text.text(model.translationID, key) : null;
    final tafsir = _showTafsir ? model.text.text(model.tafsirID, key) : null;
    final note = model.library.notes[key];
    final scheme = Theme.of(context).colorScheme;
    void menu(Offset at) => showAyahMenu(context, key, at);
    return GestureDetector(
      key: _rowKeys.putIfAbsent(key.ayah, GlobalKey.new),
      behavior: HitTestBehavior.opaque,
      onTap: () => model.select(key),
      onDoubleTap: () {
        model.select(key);
        model.audio.play(key);
      },
      onLongPressStart: (d) => menu(d.globalPosition),
      onSecondaryTapUp: (d) => menu(d.globalPosition),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? Colors.green.withValues(alpha: 0.15)
              : selected
                  ? scheme.primary.withValues(alpha: 0.12)
                  : null,
          // An outline too, so the selection shows from across the room on a TV.
          border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$key', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            if (model.studyDisplay != StudyDisplay.translation)
              Expanded(child: ArabicText(model.text.text(Edition.arabic.id, key), size: 24)),
          ]),
          if (t != null)
            translation.isRTL ? ArabicText(t, size: 18, quran: false) : SelectableText(t, style: const TextStyle(height: 1.5)),
          if (tafsir != null) ...[
            const SizedBox(height: 6),
            Edition.named(model.tafsirID).isRTL
                ? ArabicText(tafsir, size: 16, quran: false, color: scheme.onSurfaceVariant)
                : Text(tafsir, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45)),
          ],
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                const Icon(Icons.sticky_note_2_outlined, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(child: Text(note.text, style: const TextStyle(color: Colors.orange))),
              ]),
            ),
        ]),
      ),
    );
  }
}
