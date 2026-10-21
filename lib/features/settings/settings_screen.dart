import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/notifications.dart';
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
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Private by design'),
            subtitle: Text('Everything stays on this phone. No account, no tracking.'),
          ),
        ],
      ),
    );
  }
}
