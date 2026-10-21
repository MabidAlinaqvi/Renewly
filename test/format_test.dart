import 'package:flutter_test/flutter_test.dart';
import 'package:renewly/core/format.dart';

void main() {
  test('currency comes from the country, even when intl lacks the locale', () {
    expect(currencyForLocale('en_PK'), 'PKR');
    expect(currencyForLocale('en-GB'), 'GBP');
    expect(currencyForLocale('de_DE'), 'EUR');
    expect(currencyForLocale('en'), 'USD');
  });

  test('amounts convert to and from minor units', () {
    expect(toMinor(15.49, 'USD'), 1549);
    expect(toMinor(1200, 'JPY'), 1200);
    expect(fromMinor(1549, 'USD'), 15.49);
  });
}
