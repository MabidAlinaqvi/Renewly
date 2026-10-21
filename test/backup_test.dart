import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:renewly/data/backup.dart';
import 'package:renewly/data/database.dart';
import 'package:renewly/data/renewal.dart';

class _TempPaths extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
}

void main() {
  setUp(() => PathProviderPlatform.instance = _TempPaths());

  test('a backup restores every field into an empty database', () async {
    final source = AppDatabase(NativeDatabase.memory());
    await source.saveSubscription(SubscriptionsCompanion.insert(
      id: 'a', name: 'Netflix', amountMinor: 1549, currency: 'USD',
      cycle: BillingCycle.monthly, startDate: DateTime(2026, 1, 31), color: 0xFFE50914,
      isTrial: const Value(true), remindDays: const Value(3), cancelUrl: const Value('https://x.test'),
      notes: const Value('family plan'), active: const Value(false),
    ));
    final file = await writeBackup(source);
    final rows = readBackup(await file.readAsBytes());

    final target = AppDatabase(NativeDatabase.memory());
    await restoreBackup(target, rows);
    final restored = (await target.allSubscriptions()).single;
    final original = (await source.allSubscriptions()).single;
    expect(restored.copyWith(createdAt: original.createdAt), original);
    await source.close();
    await target.close();
  });

  test('other files are rejected with a clear message', () {
    expect(() => readBackup('{"hello":1}'.codeUnits), throwsA(isA<BackupError>()));
    expect(() => readBackup('not json'.codeUnits), throwsA(isA<BackupError>()));
  });
}
