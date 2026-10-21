import 'dart:io';

import 'package:intl/intl.dart';

import '../data/renewal.dart';

const currencies = [
  'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'NZD', 'INR', 'PKR', 'AED', 'SAR',
  'JPY', 'CNY', 'SGD', 'MYR', 'ZAR', 'BRL', 'MXN', 'TRY', 'CHF', 'SEK',
  'BDT', 'NGN', 'EGP', 'IDR', 'PHP', 'KRW', 'QAR', 'KWD', 'NOK', 'DKK', 'PLN',
];

/// Currency by country code. intl lacks many locales (en_PK falls back to
/// en and USD), so the country decides.
const _countryCurrency = {
  'US': 'USD', 'GB': 'GBP', 'CA': 'CAD', 'AU': 'AUD', 'NZ': 'NZD',
  'IN': 'INR', 'PK': 'PKR', 'AE': 'AED', 'SA': 'SAR', 'JP': 'JPY',
  'CN': 'CNY', 'SG': 'SGD', 'MY': 'MYR', 'ZA': 'ZAR', 'BR': 'BRL',
  'MX': 'MXN', 'TR': 'TRY', 'CH': 'CHF', 'SE': 'SEK', 'BD': 'BDT',
  'NG': 'NGN', 'EG': 'EGP', 'ID': 'IDR', 'PH': 'PHP', 'KR': 'KRW',
  'QA': 'QAR', 'KW': 'KWD', 'NO': 'NOK', 'DK': 'DKK', 'PL': 'PLN',
  'DE': 'EUR', 'FR': 'EUR', 'IT': 'EUR', 'ES': 'EUR', 'NL': 'EUR',
  'IE': 'EUR', 'BE': 'EUR', 'AT': 'EUR', 'PT': 'EUR', 'FI': 'EUR',
  'GR': 'EUR',
};

/// The phone's own currency, used as the default on first start.
String deviceCurrency() => currencyForLocale(Platform.localeName);

String currencyForLocale(String locale) {
  final parts = locale.split(RegExp('[-_.]'));
  final country = parts.length > 1 ? parts[1].toUpperCase() : '';
  if (_countryCurrency[country] case final code?) return code;
  try {
    final code = NumberFormat.simpleCurrency(locale: locale).currencyName;
    if (code != null && code.length == 3) return code;
  } catch (_) {}
  return 'USD';
}

/// Digits after the decimal point; 0 for currencies like JPY.
int decimalsOf(String currency) =>
    NumberFormat.simpleCurrency(name: currency).decimalDigits ?? 2;

int toMinor(double amount, String currency) {
  var factor = 1;
  for (var i = 0; i < decimalsOf(currency); i++) {
    factor *= 10;
  }
  return (amount * factor).round();
}

double fromMinor(num minor, String currency) {
  var factor = 1;
  for (var i = 0; i < decimalsOf(currency); i++) {
    factor *= 10;
  }
  return minor / factor;
}

String money(num minor, String currency) =>
    NumberFormat.simpleCurrency(name: currency).format(fromMinor(minor, currency));

/// "Today", "Tomorrow", "In 5 days", then a date for anything further.
String whenLabel(DateTime date, DateTime today) {
  final days = dateOnly(date).difference(dateOnly(today)).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days < 14) return 'In $days days';
  return DateFormat.MMMd().format(date);
}

String fullDate(DateTime date) => DateFormat.yMMMd().format(date);

String remindLabel(int days) => switch (days) {
  0 => 'On the day',
  1 => '1 day before',
  _ => '$days days before',
};
