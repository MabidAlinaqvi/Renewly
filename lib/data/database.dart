import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'renewal.dart';

part 'database.g.dart';

class Subscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  // Cents (or the currency's smallest unit), so totals never round wrongly.
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  IntColumn get cycle => intEnum<BillingCycle>()();
  // First bill date. For a free trial, this is the day the trial turns paid.
  DateTimeColumn get startDate => dateTime()();
  TextColumn get category => text().withDefault(const Constant('Other'))();
  BoolColumn get isTrial => boolean().withDefault(const Constant(false))();
  // Days before a bill to remind; 0 means on the day.
  IntColumn get remindDays => integer().withDefault(const Constant(2))();
  IntColumn get color => integer()();
  TextColumn get cancelUrl => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row (id 1) of app-wide preferences.
class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get currency => text()();
  IntColumn get reminderHour => integer().withDefault(const Constant(9))();
  BoolColumn get remindersOn => boolean().withDefault(const Constant(true))();
  // When the exchange rates were last downloaded.
  DateTimeColumn get ratesUpdatedAt => dateTime().nullable()();
  // Country code (e.g. PK) seen on the last start, to notice travel.
  TextColumn get lastCountry => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// How many units of [currency] one US dollar buys.
class Rates extends Table {
  TextColumn get currency => text()();
  RealColumn get perUsd => real()();

  @override
  Set<Column> get primaryKey => {currency};
}

@DriftDatabase(tables: [Subscriptions, Settings, Rates])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'renewly'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(settings, settings.ratesUpdatedAt);
        await m.addColumn(settings, settings.lastCountry);
        await m.createTable(rates);
      }
    },
  );

  Stream<List<Subscription>> watchSubscriptions() =>
      (select(subscriptions)..orderBy([(s) => OrderingTerm(expression: s.name)])).watch();

  Future<List<Subscription>> allSubscriptions() => select(subscriptions).get();

  Stream<Subscription?> watchSubscription(String id) =>
      (select(subscriptions)..where((s) => s.id.equals(id))).watchSingleOrNull();

  Future<void> saveSubscription(SubscriptionsCompanion row) =>
      into(subscriptions).insertOnConflictUpdate(row);

  Future<void> deleteSubscription(String id) =>
      (delete(subscriptions)..where((s) => s.id.equals(id))).go();

  Stream<Setting?> watchSettings() =>
      (select(settings)..where((s) => s.id.equals(1))).watchSingleOrNull();

  Future<Setting?> currentSettings() =>
      (select(settings)..where((s) => s.id.equals(1))).getSingleOrNull();

  /// Creates the settings row on first start with the phone's currency.
  Future<void> ensureSettings(String currency) =>
      into(settings).insert(
        SettingsCompanion.insert(currency: currency),
        mode: InsertMode.insertOrIgnore,
      );

  Stream<Map<String, double>> watchRates() =>
      select(rates).watch().map((rows) => {for (final r in rows) r.currency: r.perUsd});

  Future<Map<String, double>> currentRates() async =>
      {for (final r in await select(rates).get()) r.currency: r.perUsd};

  /// Replaces all rates in one go, so readers never see half a set.
  Future<void> saveRates(Map<String, double> perUsd, DateTime at) => transaction(() async {
    await delete(rates).go();
    await batch(
      (b) => b.insertAll(rates, [
        for (final e in perUsd.entries) RatesCompanion.insert(currency: e.key, perUsd: e.value),
      ]),
    );
    await updateSettings(SettingsCompanion(ratesUpdatedAt: Value(at)));
  });

  Future<void> updateSettings(SettingsCompanion changes) =>
      (update(settings)..where((s) => s.id.equals(1))).write(changes);
}
