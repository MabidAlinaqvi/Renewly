import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/notifications.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/renewal.dart';
import '../edit/edit_screen.dart';
import '../edit/template_sheet.dart';
import '../settings/settings_screen.dart';

/// A subscription with its next bill worked out for today.
class _Upcoming {
  _Upcoming(this.sub, DateTime today)
    : next = upcomingBills(sub.cycle, sub.startDate, today).first;
  final Subscription sub;
  final DateTime next;
  bool get trialRunning => sub.isTrial && !next.isAfter(dateOnly(sub.startDate));
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _add(BuildContext context) async {
    // Ask for notification permission on the first add, when the reason is obvious.
    await requestNotificationPermission();
    if (!context.mounted) return;
    final template = await showTemplateSheet(context);
    if (template == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditScreen(template: template == customTemplate ? null : template),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(subscriptionsProvider).value ?? const [];
    final currency = ref.watch(settingsProvider).value?.currency ?? 'USD';
    final today = DateTime.now();
    final active = [for (final s in subs) if (s.active) _Upcoming(s, today)]
      ..sort((a, b) => a.next.compareTo(b.next));
    final paused = [for (final s in subs) if (!s.active) s];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Renewly', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      // The empty state has its own add button.
      floatingActionButton: subs.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: const Text('Add subscription'),
            ),
      body: subs.isEmpty
          ? _Empty(onAdd: () => _add(context))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                _Summary(active: active, currency: currency),
                const SizedBox(height: 20),
                if (active.isNotEmpty) const _Heading('Coming up'),
                for (final u in active) _Tile(upcoming: u, today: today),
                if (paused.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _Heading('Paused or cancelled'),
                  for (final s in paused) _Tile.paused(s),
                ],
              ],
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.active, required this.currency});
  final List<_Upcoming> active;
  final String currency;

  @override
  Widget build(BuildContext context) {
    // Totals per currency; the main currency is shown large, others below it.
    final perMonth = <String, double>{};
    for (final u in active) {
      perMonth[u.sub.currency] =
          (perMonth[u.sub.currency] ?? 0) + u.sub.cycle.perMonth(u.sub.amountMinor);
    }
    final main = perMonth.remove(currency) ?? 0;
    final soon = active.where((u) => u.next.difference(dateOnly(DateTime.now())).inDays < 7);
    final soonTotal = <String, int>{};
    for (final u in soon) {
      soonTotal[u.sub.currency] = (soonTotal[u.sub.currency] ?? 0) + u.sub.amountMinor;
    }

    const light = TextStyle(color: Color(0xFFC7D2FE));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('You spend each month', style: light),
          const SizedBox(height: 4),
          Text(
            money(main, currency),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
          ),
          for (final e in perMonth.entries)
            Text('+ ${money(e.value, e.key)} / month', style: light),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Stat('Per year', money(main * 12, currency))),
              Expanded(child: _Stat('Active', '${active.length}')),
              Expanded(
                child: _Stat(
                  'Next 7 days',
                  soonTotal.isEmpty
                      ? 'Nothing'
                      : soonTotal.entries.map((e) => money(e.value, e.key)).join(' + '),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Color(0xFFC7D2FE), fontSize: 12)),
      Text(
        value,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        maxLines: 2,
      ),
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  _Tile({required _Upcoming upcoming, required DateTime this.today})
    : sub = upcoming.sub,
      next = upcoming.next,
      trial = upcoming.trialRunning;

  const _Tile.paused(this.sub) : next = null, trial = false, today = null;

  final Subscription sub;
  final DateTime? next;
  final DateTime? today;
  final bool trial;

  @override
  Widget build(BuildContext context) {
    final days = next == null ? null : dateOnly(next!).difference(dateOnly(today!)).inDays;
    final urgent = days != null && days <= 2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EditScreen(subscriptionId: sub.id)),
          ),
          leading: CircleAvatar(
            backgroundColor: Color(sub.color),
            foregroundColor: Colors.white,
            child: Text(
              sub.name.isEmpty ? '?' : sub.name.characters.first.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  sub.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: next == null ? AppColors.textMuted : null,
                  ),
                ),
              ),
              if (trial) ...[
                const SizedBox(width: 6),
                const _Badge('TRIAL', AppColors.trial),
              ],
            ],
          ),
          subtitle: Text('${sub.cycle.label} · ${sub.category}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(sub.amountMinor, sub.currency),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              Text(
                next == null
                    ? 'Paused'
                    : trial
                    ? 'Trial ends ${whenLabel(next!, today!).toLowerCase()}'
                    : whenLabel(next!, today!),
                style: TextStyle(
                  fontSize: 12,
                  color: urgent ? AppColors.soon : AppColors.textMuted,
                  fontWeight: urgent ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.autorenew_rounded, size: 72, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            'Never pay for a forgotten subscription again',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add what you pay for. Renewly shows your monthly total and reminds you before every renewal and free-trial end.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add your first subscription'),
          ),
        ],
      ),
    ),
  );
}
