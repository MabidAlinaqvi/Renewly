import '../core/format.dart';
import 'database.dart';
import 'rates.dart';
import 'renewal.dart';

/// Totals in the main currency, converting other currencies when rates allow.
class Spending {
  Spending(List<Subscription> subs, this.currency, this._converter) {
    for (final s in subs) {
      if (!s.active) continue;
      // Work in major units so currencies with different decimals mix correctly.
      final perMonthMajor = fromMinor(s.cycle.perMonth(s.amountMinor), s.currency);
      final converted = _converter.convert(perMonthMajor, s.currency, currency);
      if (converted == null) {
        unconverted[s.currency] = (unconverted[s.currency] ?? 0) + perMonthMajor;
        continue;
      }
      if (s.currency != currency) convertedCount++;
      monthly += converted;
      byCategory[s.category] = (byCategory[s.category] ?? 0) + converted;
      included.add(s);
    }
  }

  final String currency;
  final Converter _converter;

  /// Monthly total in [currency], major units.
  double monthly = 0;

  /// Monthly spend per category in [currency], major units.
  final byCategory = <String, double>{};

  /// Monthly spend in currencies without rates, by currency, major units.
  final unconverted = <String, double>{};

  /// How many subscriptions in the total were converted from another currency.
  int convertedCount = 0;

  final included = <Subscription>[];

  /// What will actually be charged in each of the next [months] calendar
  /// months, starting with the current one, in [currency] major units.
  List<({DateTime month, double amount})> nextMonths(DateTime today, {int months = 6}) {
    final start = DateTime(today.year, today.month);
    final totals = List.filled(months, 0.0);
    final end = DateTime(start.year, start.month + months);
    for (final s in included) {
      final amount = _converter.convert(fromMinor(s.amountMinor, s.currency), s.currency, currency)!;
      // Every bill from the first of this month to the end of the window;
      // 30 covers weekly plans over six months.
      for (final bill in upcomingBills(s.cycle, s.startDate, start, count: 30)) {
        if (!bill.isBefore(end)) break;
        totals[(bill.year - start.year) * 12 + bill.month - start.month] += amount;
      }
    }
    return [for (var i = 0; i < months; i++) (month: DateTime(start.year, start.month + i), amount: totals[i])];
  }
}
