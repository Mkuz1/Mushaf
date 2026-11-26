import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../app_model.dart';
import '../core/l10n.dart';

/// Simulator screenshots, in debug builds only (ios-assets/duo-capture.sh): a file screenshot.txt in the app's
/// Documents folder (or the environment) gives MUSHAF_SHOT (reader, recite, text, panel; "dedication" keeps the
/// opening page), MUSHAF_PAGE and MUSHAF_LANG (en, fr, ar), one KEY=value per line. The app opens that screen
/// past the opening page, without the first-run offers and prompts.
Future<void> applyScreenshotHook() async {
  if (!kDebugMode || kIsWeb) return;
  final env = Map<String, String>.of(Platform.environment);
  try {
    final file = File('${(await getApplicationDocumentsDirectory()).path}/screenshot.txt');
    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        final i = line.indexOf('=');
        if (i > 0) env[line.substring(0, i).trim()] = line.substring(i + 1).trim();
      }
    }
  } catch (_) {}
  final shot = env['MUSHAF_SHOT'];
  if (shot == null || shot.isEmpty) return;
  final language = AppLanguage.values.where((l) => l.code == env['MUSHAF_LANG']).firstOrNull;
  if (language != null) model.setLanguage(language);
  await model.prefs.setBool('pagesChoiceMade', true);
  await model.prefs.setBool('kahfAsked', true);
  if (shot == 'dedication') return;
  await model.ready;
  model.showDedication = false;
  final page = int.tryParse(env['MUSHAF_PAGE'] ?? '');
  if (page != null) model.goTo(page);
  final first = model.db?.ayahs(page ?? model.page).firstOrNull;
  await Future<void>.delayed(const Duration(seconds: 2));
  switch (shot) {
    case 'recite':
      if (first != null) model.audio.play(first);
    case 'text':
      model.mode = ReadingMode.text;
    case 'panel':
      final ayahs = model.db?.ayahs(page ?? model.page) ?? const [];
      if (ayahs.length > 1) model.showText(InspectorTab.translation, ayahs[1]);
  }
  model.update(() {});
}
