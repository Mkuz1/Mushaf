import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_model.dart';
import '../core/l10n.dart';
import '../core/quran.dart';
import '../data/text_library.dart';
import 'ayah_menu.dart';
import 'common.dart';
import 'share_card.dart';

/// Translation, tafsir and note for the selected ayah.
class AyahInspector extends StatelessWidget {
  final VoidCallback? onClose;

  /// Focus for the translation or tafsir text (the note on the note tab), where a remote control lands when the
  /// inspector opens.
  final FocusNode? textFocus;
  const AyahInspector({super.key, this.onClose, this.textFocus});

  @override
  Widget build(BuildContext context) {
    return ModelBuilder(
      also: [model.text, model.library],
      builder: (context) {
        final key = model.selected;
        if (key == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.touch_app_outlined, size: 40, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                Text(tr('No Ayah Selected'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(tr('Click an ayah on the page to see its translation, tafsir and your notes.'),
                    textAlign: TextAlign.center),
                if (onClose != null) ...[
                  const SizedBox(height: 12),
                  TextButton(onPressed: onClose, child: Text(tr('Done'))),
                ],
              ]),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _header(context, key),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(child: ArabicText(model.text.text(Edition.arabic.id, key), size: 24)),
            ),
            const SizedBox(height: 8),
            RemoteRow(
              child: SegmentedButton<InspectorTab>(
                segments: [for (final t in InspectorTab.values) ButtonSegment(value: t, label: Text(tr(t.label)))],
                selected: {model.inspectorTab},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  model.inspectorTab = s.first;
                  model.update(() {});
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: switch (model.inspectorTab) {
                InspectorTab.translation => _EditionText(
                    ayah: key,
                    editionID: model.translationID,
                    choices: Edition.translations,
                    textFocus: textFocus,
                    onChanged: (id) => model.update(() => model.translationID = id)),
                InspectorTab.tafsir => _EditionText(
                    ayah: key,
                    editionID: model.tafsirID,
                    choices: Edition.tafsirs,
                    textFocus: textFocus,
                    onChanged: (id) => model.update(() => model.tafsirID = id)),
                InspectorTab.note => _NoteEditor(key: ValueKey(key), ayah: key, textFocus: textFocus),
              },
            ),
          ]),
        );
      },
    );
  }

  Widget _header(BuildContext context, AyahKey key) {
    // Left and right stay among the panel's buttons.
    return RemoteRow(child: _headerRow(context, key));
  }

  Widget _headerRow(BuildContext context, AyahKey key) {
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(model.surahTitle(key.sura), style: Theme.of(context).textTheme.titleMedium),
          Text(tr('Ayah %d', [key.ayah]), style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      IconButton(
          onPressed: () => model.audio.play(key, to: key),
          icon: const Icon(Icons.play_circle_outline),
          tooltip: tr('Recite this ayah')),
      IconButton(
          onPressed: () => copyText(context, model.arabicWithCitation(key)),
          icon: const Icon(Icons.copy),
          tooltip: tr('Copy Arabic text')),
      IconButton(
          onPressed: () => showShareCard(context, key),
          icon: const Icon(Icons.image_outlined),
          tooltip: tr('Share as Image…')),
      IconButton(
          onPressed: () => shareText(context, key), icon: const Icon(Icons.share), tooltip: tr('Share this ayah')),
      if (onClose != null) IconButton(onPressed: onClose, icon: const Icon(Icons.close), tooltip: tr('Done')),
    ]);
  }
}

class _EditionText extends StatefulWidget {
  final AyahKey ayah;
  final String editionID;
  final List<Edition> choices;
  final ValueChanged<String> onChanged;
  final FocusNode? textFocus;
  const _EditionText(
      {required this.ayah, required this.editionID, required this.choices, required this.onChanged, this.textFocus});

  @override
  State<_EditionText> createState() => _EditionTextState();
}

class _EditionTextState extends State<_EditionText> {
  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(_EditionText old) {
    super.didUpdateWidget(old);
    if (old.editionID != widget.editionID || old.ayah.sura != widget.ayah.sura) _ensure();
  }

  void _ensure() => model.text.ensure(widget.editionID, sura: widget.ayah.sura);

  @override
  Widget build(BuildContext context) {
    final edition = Edition.named(widget.editionID);
    final t = model.text.text(widget.editionID, widget.ayah);
    final err = model.text.errors[widget.editionID];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DropdownButton<String>(
        value: widget.editionID,
        isExpanded: true,
        items: [
          for (final e in widget.choices)
            DropdownMenuItem(value: e.id, child: Text(e.title, overflow: TextOverflow.ellipsis))
        ],
        onChanged: (id) => widget.onChanged(id!),
      ),
      Expanded(
        child: KeyScroll(
          focusNode: widget.textFocus,
          scrollKey: (widget.ayah, widget.editionID),
          child: t != null
              ? (edition.isRTL
                  ? ArabicText(t, size: 18, quran: false)
                  : SelectableText(t, style: const TextStyle(height: 1.5)))
              : err != null
                  ? Row(children: [
                      const Icon(Icons.warning_amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(err)),
                      TextButton(onPressed: _ensure, child: Text(tr('Retry'))),
                    ])
                  : Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Column(children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(tr('Downloading %@…', [edition.title]), textAlign: TextAlign.center),
                      ]),
                    ),
        ),
      ),
    ]);
  }
}

class _NoteEditor extends StatefulWidget {
  final AyahKey ayah;
  final FocusNode? textFocus;
  const _NoteEditor({super.key, required this.ayah, this.textFocus});

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _controller = TextEditingController(text: model.library.notes[widget.ayah]?.text ?? '');
  Timer? _save;

  @override
  void dispose() {
    _save?.cancel();
    model.library.setNote(_controller.text, widget.ayah);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = model.library.notes[widget.ayah];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: RemoteTextField(
          focusNode: widget.textFocus,
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            filled: true,
            hintText: tr('Note'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (text) {
            _save?.cancel();
            _save = Timer(const Duration(milliseconds: 600), () => model.library.setNote(text, widget.ayah));
          },
        ),
      ),
      if (note != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(tr('Saved %@', [note.updated.toLocal().toString().split('.').first]),
              style: Theme.of(context).textTheme.bodySmall),
        ),
    ]);
  }
}

/// Scrolling text a remote control can read: focused, the up and down arrows scroll it (a page at a time, less a
/// line), moving on to the control above only from its top; left and right go to the next and previous ayah
/// (book order: left is the next one). A ring shows when it has focus.
class KeyScroll extends StatefulWidget {
  final FocusNode? focusNode;
  final Widget child;

  /// When this changes (another ayah or source), the text starts again from its top.
  final Object? scrollKey;
  const KeyScroll({super.key, this.focusNode, this.scrollKey, required this.child});

  @override
  State<KeyScroll> createState() => _KeyScrollState();
}

class _KeyScrollState extends State<KeyScroll> {
  final _scroll = ScrollController();
  bool _focused = false;

  @override
  void didUpdateWidget(KeyScroll old) {
    super.didUpdateWidget(old);
    if (old.scrollKey != widget.scrollKey) {
      // After the build: scrolling notifies listeners (the title bar) that can't rebuild during it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_scroll.hasClients) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final position = _scroll.position;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      final down = key == LogicalKeyboardKey.arrowDown;
      final step = math.max(40.0, position.viewportDimension - 48);
      final target = (position.pixels + (down ? step : -step)).clamp(0.0, position.maxScrollExtent);
      if (target == position.pixels) return KeyEventResult.ignored; // at the end: the arrow moves focus on
      _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      final ayah = model.selected, db = model.db;
      if (ayah == null || db == null) return KeyEventResult.ignored;
      final next = key == LogicalKeyboardKey.arrowLeft ? db.next(ayah) : db.previous(ayah);
      if (next != null) model.goToAyah(next);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _key,
      onFocusChange: (f) => setState(() => _focused = f),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: _focused ? scheme.primary : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(controller: _scroll, padding: const EdgeInsets.all(4), child: widget.child),
      ),
    );
  }
}
