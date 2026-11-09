import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'l10n.dart';

/// A weekly notification on Friday to read Surat Al-Kahf. The system shows it at its time, with the app closed
/// (Android and iPhone/iPad repeat it every week by themselves; Windows has no repeating notifications, so the
/// coming weeks are scheduled and topped up whenever the app opens). Tapping it opens the app at Al-Kahf.
class FridayReminder extends ChangeNotifier {
  final SharedPreferences _prefs;
  FridayReminder(this._prefs);

  static const payload = 'kahf';
  static const _id = 1800;

  /// Windows: this many Fridays ahead, from _id on.
  static const _windowsWeeks = 12;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// On by default: the first time the reader opens, the app asks for permission to notify (see [offer]).
  bool get enabled => _prefs.getBool('kahfReminder') ?? true;
  TimeOfDay get time =>
      TimeOfDay(hour: _prefs.getInt('kahfHour') ?? 9, minute: _prefs.getInt('kahfMinute') ?? 0);

  /// Whether this platform can show it (not the web, Linux or tests).
  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

  /// Sets up notifications; [onOpen] runs when the reminder is tapped while the app runs. Returns true when the
  /// app was started by tapping it.
  Future<bool> init({required VoidCallback onOpen}) async {
    if (!supported) return false;
    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
      } catch (_) {
        // An unknown zone name: the device's current offset is close enough for a weekly reminder.
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_mushaf'),
          iOS: DarwinInitializationSettings(
              requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
          macOS: DarwinInitializationSettings(
              requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
          windows: WindowsInitializationSettings(
            appName: "Mus'haf",
            appUserModelId: 'MKoussa.Mushaf.App',
            guid: '4d3c9a52-8f1e-4b7a-9c61-2f5e0d7b8a14',
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload == payload) onOpen();
        },
      );
      _ready = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (enabled && (_prefs.getBool('kahfAsked') ?? false)) await _schedule();
      return (launch?.didNotificationLaunchApp ?? false) && launch?.notificationResponse?.payload == payload;
    } catch (e) {
      debugPrint('Friday reminder unavailable: $e');
      return false;
    }
  }

  /// The first time the reader opens: asks for permission (Android 13+, iPhone, iPad, Mac) and schedules it.
  Future<void> offer() async {
    if (!_ready || (_prefs.getBool('kahfAsked') ?? false)) return;
    await _prefs.setBool('kahfAsked', true);
    if (enabled) await setEnabled(true);
  }

  /// Turns it on (asking for permission when needed; off again if refused) or off.
  Future<void> setEnabled(bool on) async {
    await _prefs.setBool('kahfAsked', true);
    if (on && _ready) on = await _requestPermission();
    await _prefs.setBool('kahfReminder', on);
    notifyListeners();
    await _schedule();
  }

  Future<void> setTime(TimeOfDay t) async {
    await _prefs.setInt('kahfHour', t.hour);
    await _prefs.setInt('kahfMinute', t.minute);
    notifyListeners();
    await _schedule();
  }

  /// Schedules it again, in the language now in use.
  Future<void> languageChanged() => _schedule();

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    if (Platform.isMacOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return true;
  }

  Future<void> _schedule() async {
    if (!_ready) return;
    try {
      for (var i = 0; i < _windowsWeeks; i++) {
        await _plugin.cancel(id: _id + i);
      }
      if (!enabled) return;
      const details = NotificationDetails(
        android: AndroidNotificationDetails('friday_kahf', 'Friday: Surat Al-Kahf',
            channelDescription: 'A reminder on Fridays to read Surat Al-Kahf',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      );
      final first = nextFriday(tz.TZDateTime.now(tz.local), time);
      if (Platform.isWindows) {
        for (var i = 0; i < _windowsWeeks; i++) {
          await _plugin.zonedSchedule(
              id: _id + i,
              scheduledDate: first.add(Duration(days: 7 * i)),
              notificationDetails: details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              title: title,
              body: body,
              payload: payload);
        }
      } else {
        await _plugin.zonedSchedule(
            id: _id,
            scheduledDate: first,
            notificationDetails: details,
            // Inexact: no exact-alarm permission needed; Android may deliver it a few minutes late.
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: title,
            body: body,
            payload: payload,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime);
      }
    } catch (e) {
      debugPrint('Friday reminder not scheduled: $e');
    }
  }

  static String get title => tr('Friday: Surat Al-Kahf');

  /// The hadith (al-Hakim; sahih per al-Albani).
  static String get body =>
      tr('“Whoever reads Surat Al-Kahf on Friday will have a light shining for them between the two Fridays.”');

  /// The first Friday at [time] after [now] (today, if it is Friday and the time is still to come).
  static tz.TZDateTime nextFriday(tz.TZDateTime now, TimeOfDay time) {
    var d = tz.TZDateTime(now.location, now.year, now.month, now.day, time.hour, time.minute);
    while (d.weekday != DateTime.friday || !d.isAfter(now)) {
      d = tz.TZDateTime(now.location, d.year, d.month, d.day + 1, time.hour, time.minute);
    }
    return d;
  }
}
