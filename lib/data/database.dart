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

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Subscriptions, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'renewly'));

  @override
  int get schemaVersion => 1;

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

  Future<void> updateSettings(SettingsCompanion changes) =>
      (update(settings)..where((s) => s.id.equals(1))).write(changes);
}
