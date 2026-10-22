import 'dart:convert';
import 'dart:io';

import 'database.dart';

/// Free daily rates, no key. Their terms ask for a visible credit, shown in
/// Settings and Insights.
const ratesSource = 'https://open.er-api.com/v6/latest/USD';
const ratesCredit = 'Rates by Exchange Rate API';
const ratesCreditUrl = 'https://www.exchangerate-api.com';

/// Rates older than this are downloaded again on start.
const _maxAge = Duration(hours: 20);

/// Downloads fresh rates if the saved ones are missing or old. Offline or
/// failing is fine: the last saved rates keep working.
Future<void> refreshRates(AppDatabase db, {bool force = false}) async {
  final settings = await db.currentSettings();
  final updated = settings?.ratesUpdatedAt;
  if (!force && updated != null && DateTime.now().difference(updated) < _maxAge) return;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(Uri.parse(ratesSource));
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return;
    final body = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
    if (body['result'] != 'success') return;
    final rates = {
      for (final e in (body['rates'] as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble(),
    };
    if (rates.length > 10) await db.saveRates(rates, DateTime.now());
  } catch (_) {
    // No internet: keep the saved rates.
  } finally {
    client.close();
  }
}

/// Converts amounts between currencies using rates per US dollar.
class Converter {
  const Converter(this.perUsd);
  final Map<String, double> perUsd;

  bool canConvert(String from, String to) =>
      from == to || (perUsd.containsKey(from) && perUsd.containsKey(to));

  /// [amount] in [from] expressed in [to] (both in major units or both in
  /// minor units of the same size), or null without rates.
  double? convert(double amount, String from, String to) {
    if (from == to) return amount;
    final a = perUsd[from], b = perUsd[to];
    if (a == null || b == null || a == 0) return null;
    return amount / a * b;
  }
}
