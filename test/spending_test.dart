import 'package:flutter_test/flutter_test.dart';
import 'package:renewly/core/chart_colors.dart';
import 'package:renewly/data/database.dart';
import 'package:renewly/data/rates.dart';
import 'package:renewly/data/renewal.dart';
import 'package:renewly/data/spending.dart';

Subscription sub(String name, int minor, String currency, BillingCycle cycle, DateTime start, {String category = 'Other'}) =>
    Subscription(
      id: name, name: name, amountMinor: minor, currency: currency, cycle: cycle, startDate: start,
      category: category, isTrial: false, remindDays: 2, color: 0, active: true, createdAt: DateTime(2026),
    );

void main() {
  const rates = Converter({'USD': 1, 'PKR': 280, 'JPY': 150});

  test('dollars and rupees add up into one rupee total', () {
    final s = Spending([
      sub('ChatGPT', 2000, 'USD', BillingCycle.monthly, DateTime(2026, 1, 5), category: 'AI tools'),
      sub('Netflix', 1100, 'PKR', BillingCycle.monthly, DateTime(2026, 1, 10), category: 'Entertainment'),
    ], 'PKR', rates);
    expect(s.monthly, closeTo(20 * 280 + 1100, .001));
    expect(s.convertedCount, 1);
    expect(s.byCategory['AI tools'], closeTo(5600, .001));
  });

  test('currencies without decimals convert correctly', () {
    final s = Spending([sub('Jp', 1500, 'JPY', BillingCycle.monthly, DateTime(2026))], 'USD', rates);
    expect(s.monthly, closeTo(10, .001));
  });

  test('a currency without a rate is kept apart, not dropped', () {
    final s = Spending([sub('Gym', 5000, 'EUR', BillingCycle.monthly, DateTime(2026))], 'USD', rates);
    expect(s.monthly, 0);
    expect(s.unconverted['EUR'], 50);
  });

  test('next months show real bills: a yearly plan lands in one month only', () {
    final s = Spending([
      sub('Domain', 1200, 'USD', BillingCycle.yearly, DateTime(2025, 12, 3)),
      sub('Music', 1000, 'USD', BillingCycle.monthly, DateTime(2026, 1, 15)),
    ], 'USD', rates);
    final months = s.nextMonths(DateTime(2026, 10, 22));
    expect(months.first.month, DateTime(2026, 10));
    expect([for (final m in months) m.amount], [10, 10, 22, 10, 10, 10]);
  });

  test('charts keep each category colour and fold small ones into Other', () {
    final slices = categorySlices({
      'Entertainment': 50, 'Music': 40, 'AI tools': 30, 'Software': 20,
      'Shopping': 10, 'Health & fitness': 5, 'Utilities': 7, 'Other': 3,
    });
    expect([for (final s in slices) s.label],
        ['Entertainment', 'Music', 'AI tools', 'Software', 'Shopping', 'Other']);
    expect(slices.last.amount, 15);
    expect(slices[2].color, categoryColor('AI tools'));
  });
}
