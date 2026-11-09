import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_model.dart';
import '../core/l10n.dart';

class AppColors {
  static const paperLight = Color(0xFFFCF7E8);
  static const paperDark = Color(0xFF1C1C1A);
  static const parchment = Color(0xFFF5E8C9);
  static const parchmentDesk = Color(0xFFCCB894);
  static const deskDark = Color(0xFF403629);
  static const night = Color(0xFF141417);
  static const frameGold = Color(0xFFB08A3D);
  static const frameGreen = Color(0xFF3D6B4A);
  static const allahRed = Color(0xFFC7211A);

  /// App accent: the emerald of the icon and the opening page.
  static const accent = Color(0xFF0D785C);
  static const gold = Color(0xFFDBB86B);
  static const emerald = Color(0xFF083326);
  static const emeraldDeep = Color(0xFF031C14);
}

const quranFont = 'Amiri Quran';
const arabicFont = 'Amiri';

/// Mouse and keyboard rather than touch. From the target platform, so tests run as the phone they render.
bool get isDesktop => switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    };

/// Right-aligned, right-to-left Quran or Arabic text.
class ArabicText extends StatelessWidget {
  final String? text;
  final double size;
  final Color? color;
  final bool quran;
  final int? maxLines;
  const ArabicText(this.text, {super.key, this.size = 22, this.color, this.quran = true, this.maxLines});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: Text(
          text ?? '…',
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          style: TextStyle(fontFamily: quran ? quranFont : arabicFont, fontSize: size, height: 1.9, color: color),
        ),
      );
}

/// Rebuilds when the model, the language or any of the given notifiers change.
class ModelBuilder extends StatelessWidget {
  final List<Listenable> also;
  final WidgetBuilder builder;
  const ModelBuilder({super.key, this.also = const [], required this.builder});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([model, Localizer.shared, ...also]),
        builder: (context, _) => builder(context),
      );
}

void toast(BuildContext context, String message) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));

/// A text field a TV remote can pass through. The up and down arrows move on to the control above or below
/// instead of staying in the field (in a multi-line field, from its first or last line), and when focus arrives by
/// the remote or a keyboard on a TV, phone or tablet, the on-screen keyboard waits for OK instead of opening at
/// once and taking over the arrows. Touch, and keyboards on Windows and macOS, behave as in a plain TextField.
class RemoteTextField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int? maxLines;
  final bool expands;
  final TextAlignVertical? textAlignVertical;

  /// Its focus, when someone else needs to move focus to it; it handles that node's keys.
  final FocusNode? focusNode;
  const RemoteTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLines = 1,
    this.expands = false,
    this.textAlignVertical,
  });

  @override
  State<RemoteTextField> createState() => _RemoteTextFieldState();
}

class _RemoteTextFieldState extends State<RemoteTextField> {
  late final _focus = (widget.focusNode ?? FocusNode(debugLabel: 'text field'))..onKeyEvent = _key;
  bool _typing = false;

  /// Arrow keys rather than touch, away from a desktop: hold the keyboard back until OK.
  bool get _gated => !isDesktop && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
    FocusManager.instance.addHighlightModeListener(_highlightChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_highlightChanged);
    _focus.removeListener(_focusChanged);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _highlightChanged(FocusHighlightMode _) {
    if (mounted) setState(() {});
  }

  void _focusChanged() {
    if (!_focus.hasFocus && _typing) setState(() => _typing = false);
  }

  void _startTyping() {
    setState(() => _typing = true);
    // The field took focus while read-only, so once it is editable, ask it for the keyboard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.context?.findAncestorStateOfType<EditableTextState>()?.requestKeyboard();
    });
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final waiting = _gated && !_typing;
    if (waiting && (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter)) {
      if (event is KeyDownEvent) _startTyping();
      return KeyEventResult.handled;
    }
    final up = key == LogicalKeyboardKey.arrowUp, down = key == LogicalKeyboardKey.arrowDown;
    if (!up && !down) return KeyEventResult.ignored;
    final multiLine = widget.maxLines != 1;
    if (multiLine && !waiting) {
      // Inside the text, the arrows move the cursor; only from its first or last line do they leave.
      final sel = widget.controller.selection;
      final text = widget.controller.text;
      final atStart = !text.substring(0, sel.baseOffset.clamp(0, text.length)).contains('\n');
      final atEnd = !text.substring(sel.extentOffset.clamp(0, text.length)).contains('\n');
      if ((up && !atStart) || (down && !atEnd)) return KeyEventResult.ignored;
    }
    return node.focusInDirection(up ? TraversalDirection.up : TraversalDirection.down)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        focusNode: _focus,
        decoration: widget.decoration,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        autofocus: widget.autofocus,
        maxLines: widget.maxLines,
        expands: widget.expands,
        textAlignVertical: widget.textAlignVertical,
        readOnly: _gated && !_typing,
        onTap: () {
          if (!_typing) setState(() => _typing = true);
        },
      );
}

/// A row of buttons for a remote control: left and right go to the next button in the row and stop at its ends
/// (rather than jumping to whatever lies that way on screen, past buttons laid out on a second line); up and down
/// leave the row for the places given.
class RemoteRow extends StatelessWidget {
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final FocusNode? focusNode;
  final Widget child;
  const RemoteRow({super.key, this.focusNode, this.onUp, this.onDown, required this.child});

  /// The row's first button, where a remote enters it.
  static FocusNode? first(FocusNode row) => row.traversalDescendants.firstOrNull;

  KeyEventResult _key(BuildContext context, FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      final leave = key == LogicalKeyboardKey.arrowUp ? onUp : onDown;
      if (leave == null) return KeyEventResult.ignored;
      leave();
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.arrowLeft && key != LogicalKeyboardKey.arrowRight) return KeyEventResult.ignored;
    final items = node.traversalDescendants.toList();
    final at = items.indexWhere((n) => n.hasPrimaryFocus);
    if (at < 0) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward = (key == LogicalKeyboardKey.arrowRight) != rtl;
    final next = at + (forward ? 1 : -1);
    if (next >= 0 && next < items.length) items[next].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: focusNode, skipTraversal: true, onKeyEvent: (node, event) => _key(context, node, event), child: child);
}

/// Menus and dialogs opened from a remote control or a keyboard start on their first item: Flutter focuses the
/// menu or dialog as a whole, where OK does nothing until an arrow is pressed. Touch is unchanged.
class RemoteFocusObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! ModalRoute || previousRoute == null) return;
    if (FocusManager.instance.highlightMode != FocusHighlightMode.traditional) return;
    _focusFirst(route, tries: 3);
  }

  /// Once the new route has focus (within a frame or two of being pushed), focuses its first item.
  void _focusFirst(ModalRoute<dynamic> route, {required int tries}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!route.isActive) return;
      final focus = FocusManager.instance.primaryFocus;
      if (focus is FocusScopeNode && focus.focusedChild == null) {
        // The first in reading order (the widget tree's order can put a dialog's buttons before its content).
        focus.nextFocus();
      } else if (tries > 1 && focus is! FocusScopeNode && !(route.isCurrent && _inRoute(focus, route))) {
        _focusFirst(route, tries: tries - 1);
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  static bool _inRoute(FocusNode? focus, ModalRoute<dynamic> route) {
    final context = focus?.context;
    return context != null && ModalRoute.of(context) == route;
  }
}
