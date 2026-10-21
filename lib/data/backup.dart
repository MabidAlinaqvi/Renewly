import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path_provider/path_provider.dart';

import 'database.dart';
import 'renewal.dart';

const _format = 'renewly-backup';
const _version = 1;

class BackupError implements Exception {
  const BackupError(this.message);
  final String message;
}

/// Writes every subscription and the settings to a JSON file in the cache
/// folder, ready to share.
Future<File> writeBackup(AppDatabase db) async {
  final settings = await db.currentSettings();
  final subs = await db.allSubscriptions();
  final data = {
    'format': _format,
    'version': _version,
    'exportedAt': DateTime.now().toIso8601String(),
    if (settings != null)
      'settings': {
        'currency': settings.currency,
        'reminderHour': settings.reminderHour,
        'remindersOn': settings.remindersOn,
      },
    'subscriptions': [
      for (final s in subs)
        {
          'id': s.id,
          'name': s.name,
          'amountMinor': s.amountMinor,
          'currency': s.currency,
          'cycle': s.cycle.name,
          'startDate': s.startDate.toIso8601String(),
          'category': s.category,
          'isTrial': s.isTrial,
          'remindDays': s.remindDays,
          'color': s.color,
          'cancelUrl': s.cancelUrl,
          'notes': s.notes,
          'active': s.active,
        },
    ],
  };
  final dir = await getTemporaryDirectory();
  final stamp = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/renewly-backup-$stamp.json');
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  return file;
}

/// Parses a backup without touching the database, so the user can confirm.
List<SubscriptionsCompanion> readBackup(List<int> bytes) {
  final Object? data;
  try {
    data = jsonDecode(utf8.decode(bytes));
  } catch (_) {
    throw const BackupError('That file isn\'t a Renewly backup.');
  }
  if (data is! Map || data['format'] != _format) {
    throw const BackupError('That file isn\'t a Renewly backup.');
  }
  if ((data['version'] as int? ?? 0) > _version) {
    throw const BackupError('This backup is from a newer Renewly. Update the app first.');
  }
  try {
    return [
      for (final s in data['subscriptions'] as List)
        SubscriptionsCompanion.insert(
          id: s['id'] as String,
          name: s['name'] as String,
          amountMinor: s['amountMinor'] as int,
          currency: s['currency'] as String,
          cycle: BillingCycle.values.byName(s['cycle'] as String),
          startDate: DateTime.parse(s['startDate'] as String),
          category: Value(s['category'] as String? ?? 'Other'),
          isTrial: Value(s['isTrial'] as bool? ?? false),
          remindDays: Value(s['remindDays'] as int? ?? 2),
          color: s['color'] as int,
          cancelUrl: Value(s['cancelUrl'] as String?),
          notes: Value(s['notes'] as String?),
          active: Value(s['active'] as bool? ?? true),
        ),
    ];
  } catch (_) {
    throw const BackupError('This backup is damaged and can\'t be restored.');
  }
}

/// Adds the backup's subscriptions; ones that already exist are updated.
Future<void> restoreBackup(AppDatabase db, List<SubscriptionsCompanion> rows) =>
    db.transaction(() async {
      for (final row in rows) {
        await db.saveSubscription(row);
      }
    });
