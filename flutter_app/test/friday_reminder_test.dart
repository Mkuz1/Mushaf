import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reader_hd/core/friday_reminder.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('the next Friday at the reminder time', () {
    final dubai = tz.getLocation('Asia/Dubai');
    const nine = TimeOfDay(hour: 9, minute: 0);
    // Wednesday 28 October 2026, noon: Friday the 30th.
    expect(FridayReminder.nextFriday(tz.TZDateTime(dubai, 2026, 10, 28, 12), nine),
        tz.TZDateTime(dubai, 2026, 10, 30, 9));
    // Friday before nine: today; at or after nine: next week.
    expect(FridayReminder.nextFriday(tz.TZDateTime(dubai, 2026, 10, 30, 8), nine),
        tz.TZDateTime(dubai, 2026, 10, 30, 9));
    expect(FridayReminder.nextFriday(tz.TZDateTime(dubai, 2026, 10, 30, 9), nine),
        tz.TZDateTime(dubai, 2026, 11, 6, 9));
    // Across a month and a year.
    expect(FridayReminder.nextFriday(tz.TZDateTime(dubai, 2026, 12, 26, 10), nine),
        tz.TZDateTime(dubai, 2027, 1, 1, 9));
  });

  test('keeps the wall-clock time across a daylight saving change', () {
    final paris = tz.getLocation('Europe/Paris');
    // Clocks go back on Sunday 25 October 2026: the Friday after is still at 9:00 local time.
    final next = FridayReminder.nextFriday(tz.TZDateTime(paris, 2026, 10, 24, 12), const TimeOfDay(hour: 9, minute: 0));
    expect((next.year, next.month, next.day, next.hour, next.minute), (2026, 10, 30, 9, 0));
    expect(next.weekday, DateTime.friday);
  });
}
