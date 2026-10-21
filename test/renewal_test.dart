import 'package:flutter_test/flutter_test.dart';
import 'package:renewly/data/renewal.dart';

void main() {
  test('monthly bill on the 31st falls back to month end and returns', () {
    final start = DateTime(2026, 1, 31);
    expect(BillingCycle.monthly.billNumber(start, 1), DateTime(2026, 2, 28));
    expect(BillingCycle.monthly.billNumber(start, 2), DateTime(2026, 3, 31));
  });

  test('yearly bill on 29 Feb lands on 28 Feb in normal years', () {
    expect(BillingCycle.yearly.billNumber(DateTime(2028, 2, 29), 1), DateTime(2029, 2, 28));
  });

  test('next bill is today when today is a billing day', () {
    final bills = upcomingBills(BillingCycle.monthly, DateTime(2026, 1, 15), DateTime(2026, 10, 15, 18));
    expect(bills, [DateTime(2026, 10, 15)]);
  });

  test('next bill skips past ones and lists the following', () {
    final bills = upcomingBills(BillingCycle.quarterly, DateTime(2025, 3, 10), DateTime(2026, 10, 21), count: 3);
    expect(bills, [DateTime(2026, 12, 10), DateTime(2027, 3, 10), DateTime(2027, 6, 10)]);
  });

  test('a future start date is the next bill (free trial)', () {
    final bills = upcomingBills(BillingCycle.monthly, DateTime(2026, 11, 2), DateTime(2026, 10, 21));
    expect(bills.first, DateTime(2026, 11, 2));
  });

  test('weekly from years ago stays exact', () {
    final bills = upcomingBills(BillingCycle.weekly, DateTime(2020, 1, 6), DateTime(2026, 10, 21));
    expect(bills.first, DateTime(2026, 10, 26));
    expect(bills.first.weekday, DateTime.monday);
  });

  test('monthly cost of each cycle', () {
    expect(BillingCycle.yearly.perMonth(12000), 1000);
    expect(BillingCycle.quarterly.perMonth(3000), 1000);
    expect(BillingCycle.weekly.perMonth(1200), 5200);
  });
}
