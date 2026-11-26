import 'dart:io';

import 'package:flutter/foundation.dart';

import '../app_model.dart';
import '../core/l10n.dart';

/// Simulator screenshots, in debug builds only (ios-assets/duo-capture.sh): the simulator starts the app with
/// MUSHAF_SHOT (reader, recite, text, panel; "dedication" keeps the opening page), MUSHAF_PAGE and MUSHAF_LANG
/// (en, fr, ar). It opens that screen past the opening page, without the first-run offers and prompts.
Future<void> applyScreenshotHook() async {
  if (!kDebugMode || kIsWeb) return;
  final env = Platform.environment;
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
