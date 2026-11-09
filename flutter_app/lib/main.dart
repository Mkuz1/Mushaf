import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_model.dart';
import 'core/l10n.dart';
import 'core/storage.dart';
import 'ui/common.dart';
import 'ui/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A part of the screen that fails to build shows what went wrong, not the release build's plain grey box,
  // so a screenshot is enough to report it.
  ErrorWidget.builder = (details) => Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFFF6EBD0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('⚠ ${details.exceptionAsString()}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A1C1C), decoration: TextDecoration.none)),
            ),
          ),
        ),
      );
  final prefs = await SharedPreferences.getInstance();
  await Paths.init();
  Localizer.init(prefs, PlatformDispatcher.instance.locale);
  model = AppModel(prefs);
  runApp(const QuranReaderApp());
}

class QuranReaderApp extends StatelessWidget {
  const QuranReaderApp({super.key});

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: brightness);
    // A clear ring on the focused button, for a TV remote or a keyboard (Material's own focus tint is hard to see
    // across a room). Flutter only shows focus after a key press, so touch and mouse look the same as before.
    final ring = WidgetStateProperty.resolveWith<BorderSide?>(
        (states) => states.contains(WidgetState.focused) ? BorderSide(color: scheme.onSurface, width: 3) : null);
    final focused = ButtonStyle(side: ring);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      focusColor: scheme.primary.withValues(alpha: 0.24),
      iconButtonTheme: IconButtonThemeData(style: focused),
      textButtonTheme: TextButtonThemeData(style: focused),
      filledButtonTheme: FilledButtonThemeData(style: focused),
      // Segments share one outline, so the focused one is filled instead.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          // Material's own colours otherwise (a theme colour replaces them for every state).
          backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.focused)
              ? scheme.primary
              : states.contains(WidgetState.selected)
                  ? scheme.secondaryContainer
                  : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.focused)
              ? scheme.onPrimary
              : states.contains(WidgetState.disabled)
                  ? scheme.onSurface.withValues(alpha: 0.38)
                  : states.contains(WidgetState.selected)
                      ? scheme.onSecondaryContainer
                      : scheme.onSurface),
        ),
      ),
      // Every state needs a side here (Material's own otherwise): a null one breaks the theme's animation when
      // it changes, as when the language is switched.
      chipTheme: ChipThemeData(
        side: WidgetStateBorderSide.resolveWith((states) => states.contains(WidgetState.focused)
            ? BorderSide(color: scheme.onSurface, width: 3)
            : states.contains(WidgetState.selected)
                ? BorderSide.none
                : BorderSide(
                    color: states.contains(WidgetState.disabled)
                        ? scheme.onSurface.withValues(alpha: 0.12)
                        : scheme.outlineVariant)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Localizer.shared,
      builder: (context, _) => MaterialApp(
        title: "Mus'haf",
        debugShowCheckedModeBanner: false,
        // The same dark green menus and bars on every device, whatever its light or dark setting (the mushaf
        // page itself still follows that setting: see invertsInk).
        theme: _theme(Brightness.dark),
        // Arabic lays the interface out right-to-left; the mushaf itself keeps book order.
        builder: (context, child) =>
            Directionality(textDirection: Localizer.shared.language.direction, child: child!),
        navigatorObservers: [RemoteFocusObserver()],
        home: const Home(),
      ),
    );
  }
}
