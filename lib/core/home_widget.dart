import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../data/database.dart';
import '../data/rates.dart';
import '../data/spending.dart';
import '../data/renewal.dart';
import 'format.dart';

/// Sends the monthly total and upcoming bills to the home-screen widget.
///
/// The widget drops bills whose date has passed and works out "Today" or
/// "In 3 days" itself, so it stays right for weeks without the app opening.
/// That's why it gets several bills per subscription, not just the next.
Future<void> updateHomeWidget(AppDatabase db) async {
  final settings = await db.currentSettings();
  final currency = settings?.currency ?? 'USD';
  final today = DateTime.now();
  final subs = [for (final s in await db.allSubscriptions()) if (s.active) s];

  final monthly = Spending(subs, currency, Converter(await db.currentRates())).monthly;
  final bills = <({DateTime date, String name, String amount})>[];
  for (final s in subs) {
    for (final d in upcomingBills(s.cycle, s.startDate, today, count: 3)) {
      bills.add((date: d, name: s.name, amount: money(s.amountMinor, s.currency)));
    }
  }
  bills.sort((a, b) => a.date.compareTo(b.date));

  try {
    await HomeWidget.saveWidgetData('total', subs.isEmpty ? '' : '${moneyMajor(monthly, currency)} / month');
    await HomeWidget.saveWidgetData(
      'bills',
      jsonEncode([
        for (final b in bills.take(15))
          {'date': b.date.toIso8601String().substring(0, 10), 'name': b.name, 'amount': b.amount},
      ]),
    );
    await HomeWidget.updateWidget(androidName: 'RenewlyWidget');
  } catch (_) {
    // No widget support (tests, or a launcher without widgets): nothing to update.
  }
}
