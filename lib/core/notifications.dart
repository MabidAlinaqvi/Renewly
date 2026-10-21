import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/database.dart';
import '../data/renewal.dart';
import 'format.dart';

final _plugin = FlutterLocalNotificationsPlugin();
bool _ready = false;

const _channel = AndroidNotificationDetails(
  'renewly_reminders',
  'Renewal reminders',
  channelDescription: 'Alerts before a subscription renews or a free trial ends',
  importance: Importance.high,
);

/// Reminders are scheduled for this many upcoming bills of each
/// subscription, so they keep coming even if the app isn't opened for a while.
const _billsAhead = 3;

/// [onTap] gets the subscription id of a tapped reminder.
Future<void> initNotifications(void Function(String id) onTap) async {
  try {
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
  } catch (_) {
    tz.setLocalLocation(tz.UTC);
  }
  await _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: (r) {
      if (r.payload != null) onTap(r.payload!);
    },
  );
  _ready = true;
}

/// Subscription id of the reminder that opened the app, if any.
Future<String?> launchPayload() async {
  final details = await _plugin.getNotificationAppLaunchDetails();
  return details?.didNotificationLaunchApp ?? false
      ? details!.notificationResponse?.payload
      : null;
}

Future<bool> requestNotificationPermission() async =>
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission() ??
    true;

/// Rebuilds every reminder from current data. Called on start and whenever
/// subscriptions or settings change.
Future<void> rescheduleNotifications(AppDatabase db) async {
  if (!_ready) return;
  await _plugin.cancelAll();
  final settings = await db.currentSettings();
  if (settings == null || !settings.remindersOn) return;
  final now = tz.TZDateTime.now(tz.local);
  const details = NotificationDetails(android: _channel);

  for (final s in await db.allSubscriptions()) {
    if (!s.active) continue;
    final bills = upcomingBills(s.cycle, s.startDate, now, count: _billsAhead);
    for (var i = 0; i < bills.length; i++) {
      final bill = bills[i];
      final day = bill.subtract(Duration(days: s.remindDays));
      final at = tz.TZDateTime(tz.local, day.year, day.month, day.day, settings.reminderHour);
      if (!at.isAfter(now)) continue;
      // Only the first bill can be the end of a free trial.
      final trialEnding = s.isTrial && i == 0 && !dateOnly(s.startDate).isBefore(dateOnly(now));
      final when = whenLabel(bill, day).toLowerCase();
      await _plugin.zonedSchedule(
        id: ((s.id.hashCode & 0x0fffffff) * _billsAhead + i) & 0x7fffffff,
        scheduledDate: at,
        title: trialEnding ? '${s.name} trial ends $when' : '${s.name} renews $when',
        body: trialEnding
            ? 'Cancel now if you don\'t want to pay ${money(s.amountMinor, s.currency)}.'
            : '${money(s.amountMinor, s.currency)} will be charged on ${fullDate(bill)}.',
        payload: s.id,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
