import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'rates.dart';
import 'spending.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final subscriptionsProvider = StreamProvider<List<Subscription>>(
  (ref) => ref.watch(databaseProvider).watchSubscriptions(),
);

final subscriptionProvider = StreamProvider.family<Subscription?, String>(
  (ref, id) => ref.watch(databaseProvider).watchSubscription(id),
);

final settingsProvider = StreamProvider<Setting?>(
  (ref) => ref.watch(databaseProvider).watchSettings(),
);

final ratesProvider = StreamProvider<Map<String, double>>(
  (ref) => ref.watch(databaseProvider).watchRates(),
);

/// Totals in the main currency, recalculated when subscriptions, the main
/// currency or the rates change.
final spendingProvider = Provider<Spending>((ref) {
  final subs = ref.watch(subscriptionsProvider).value ?? const [];
  final currency = ref.watch(settingsProvider).value?.currency ?? 'USD';
  final rates = ref.watch(ratesProvider).value ?? const {};
  return Spending(subs, currency, Converter(rates));
});
