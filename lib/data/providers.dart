import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

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
