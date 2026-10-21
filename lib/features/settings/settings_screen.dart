import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/notifications.dart';
import '../../data/backup.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final db = ref.read(databaseProvider);
    if (settings == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Main currency'),
            subtitle: const Text('Used for the monthly total and new subscriptions'),
            trailing: DropdownButton<String>(
              value: settings.currency,
              underline: const SizedBox(),
              items: [
                for (final c in {...currencies, settings.currency})
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => db.updateSettings(SettingsCompanion(currency: Value(v!))),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Renewal reminders'),
            value: settings.remindersOn,
            onChanged: (v) async {
              if (v) await requestNotificationPermission();
              await db.updateSettings(SettingsCompanion(remindersOn: Value(v)));
            },
          ),
          ListTile(
            enabled: settings.remindersOn,
            leading: const Icon(Icons.schedule),
            title: const Text('Reminder time'),
            trailing: Text(
              TimeOfDay(hour: settings.reminderHour, minute: 0).format(context),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: settings.reminderHour, minute: 0),
                helpText: 'Reminders arrive at this hour',
              );
              if (picked != null) {
                await db.updateSettings(SettingsCompanion(reminderHour: Value(picked.hour)));
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Back up'),
            subtitle: const Text('Save a file to Drive, email or anywhere you like'),
            onTap: () async {
              final file = await writeBackup(db);
              await SharePlus.instance.share(
                ShareParams(files: [XFile(file.path)], text: 'Renewly backup'),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Restore from backup'),
            subtitle: const Text('Adds subscriptions from a backup file'),
            onTap: () => _restore(context, db),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Private by design'),
            subtitle: Text('Everything stays on this phone. No account, no tracking.'),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context, AppDatabase db) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFile();
    if (picked == null || !context.mounted) return;
    final List<SubscriptionsCompanion> rows;
    try {
      rows = readBackup(await picked.readAsBytes());
    } on BackupError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!context.mounted) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore ${rows.length} subscriptions?'),
        content: const Text('They are added to your list. Ones you already have are updated from the backup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (sure != true) return;
    await restoreBackup(db, rows);
    messenger.showSnackBar(SnackBar(content: Text('Restored ${rows.length} subscriptions')));
  }
}
