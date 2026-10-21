/// How often a subscription bills. Stored by index, so only append.
enum BillingCycle {
  weekly('Weekly', 'week'),
  monthly('Monthly', 'month'),
  quarterly('Every 3 months', 'quarter'),
  yearly('Yearly', 'year');

  const BillingCycle(this.label, this.unit);
  final String label;
  final String unit;

  /// The cost of one bill spread over a month.
  double perMonth(int amountMinor) => switch (this) {
    weekly => amountMinor * 52 / 12,
    monthly => amountMinor.toDouble(),
    quarterly => amountMinor / 3,
    yearly => amountMinor / 12,
  };

  /// The [n]th bill counted from [start] (n = 0 is [start] itself).
  /// Months are added to the start date each time, never step by step, so a
  /// bill on the 31st comes back to the 31st after a short month.
  DateTime billNumber(DateTime start, int n) => switch (this) {
    weekly => DateTime(start.year, start.month, start.day + 7 * n),
    monthly => addMonths(start, n),
    quarterly => addMonths(start, 3 * n),
    yearly => addMonths(start, 12 * n),
  };
}

/// [date] moved [months] ahead, on the same day or the month's last day.
DateTime addMonths(DateTime date, int months) {
  final first = DateTime(date.year, date.month + months);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, date.day > lastDay ? lastDay : date.day);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The next bill on or after [today], plus the [count] - 1 bills after it.
List<DateTime> upcomingBills(
  BillingCycle cycle,
  DateTime start,
  DateTime today, {
  int count = 1,
}) {
  final from = dateOnly(today);
  var n = 0;
  // Jump close first so a weekly plan from years ago doesn't loop thousands of times.
  final days = from.difference(dateOnly(start)).inDays;
  if (days > 0) {
    n = switch (cycle) {
      BillingCycle.weekly => days ~/ 7,
      BillingCycle.monthly => days ~/ 31,
      BillingCycle.quarterly => days ~/ 92,
      BillingCycle.yearly => days ~/ 366,
    };
  }
  while (cycle.billNumber(start, n).isBefore(from)) {
    n++;
  }
  return [for (var i = 0; i < count; i++) cycle.billNumber(start, n + i)];
}
