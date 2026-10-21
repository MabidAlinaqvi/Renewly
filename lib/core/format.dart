import 'dart:io';

import 'package:intl/intl.dart';

import '../data/renewal.dart';

const currencies = [
  'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'NZD', 'INR', 'PKR', 'AED', 'SAR',
  'JPY', 'CNY', 'SGD', 'MYR', 'ZAR', 'BRL', 'MXN', 'TRY', 'CHF', 'SEK',
];

/// The phone's own currency, used as the default on first start.
String deviceCurrency() {
  try {
    final code = NumberFormat.simpleCurrency(locale: Platform.localeName).currencyName;
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
