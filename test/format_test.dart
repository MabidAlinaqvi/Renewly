import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renewly/core/format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void phoneIn({required String network, required String sim}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('renewly/country'),
      (_) async => {'network': network, 'sim': sim},
    );
  }

  test('the mobile network decides first, so a traveller gets local money', () async {
    phoneIn(network: 'gb', sim: 'pk');
    expect(await deviceCurrency(), 'GBP');
  });

  test('the SIM decides when there is no network signal', () async {
    phoneIn(network: '', sim: 'ae');
    expect(await deviceCurrency(), 'AED');
  });

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
