import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/chart_colors.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/rates.dart';
import '../../data/renewal.dart';
import '../edit/edit_screen.dart';
import '../edit/template_sheet.dart';
import '../insights/insights_screen.dart';
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
                _Summary(active: active),
                const SizedBox(height: 12),
                const _CategoryStrip(),
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

class _Summary extends ConsumerWidget {
  const _Summary({required this.active});
  final List<_Upcoming> active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spending = ref.watch(spendingProvider);
    final converter = Converter(ref.watch(ratesProvider).value ?? const {});
    final currency = spending.currency;
    // Next 7 days, converted like the total; anything without a rate is listed apart.
    var week = 0.0;
    final weekOther = <String, double>{};
    for (final u in active) {
      if (u.next.difference(dateOnly(DateTime.now())).inDays >= 7) continue;
      final amount = fromMinor(u.sub.amountMinor, u.sub.currency);
      final converted = converter.convert(amount, u.sub.currency, currency);
      if (converted != null) {
        week += converted;
      } else {
        weekOther[u.sub.currency] = (weekOther[u.sub.currency] ?? 0) + amount;
      }
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
            moneyMajor(spending.monthly, currency),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
          ),
          if (spending.convertedCount > 0)
            Text(
              'Includes ${spending.convertedCount} converted from other currencies',
              style: light.copyWith(fontSize: 12),
            ),
          for (final e in spending.unconverted.entries)
            Text('+ ${moneyMajor(e.value, e.key)} / month (no rate yet)', style: light),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Stat('Per year', moneyMajor(spending.monthly * 12, currency))),
              Expanded(child: _Stat('Active', '${active.length}')),
              Expanded(
                child: _Stat(
                  'Next 7 days',
                  week == 0 && weekOther.isEmpty
                      ? 'Nothing'
                      : [
                          if (week > 0) moneyMajor(week, currency),
                          for (final e in weekOther.entries) moneyMajor(e.value, e.key),
                        ].join(' + '),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One stacked bar of spend by category; tapping opens Insights.
class _CategoryStrip extends ConsumerWidget {
  const _CategoryStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spending = ref.watch(spendingProvider);
    final slices = categorySlices(spending.byCategory, maxSlices: 5);
    if (slices.isEmpty || spending.monthly <= 0) return const SizedBox();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InsightsScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text('Where it goes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  Text('Insights', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  Icon(Icons.chevron_right, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 12,
                  width: double.infinity,
                  child: Row(
                    // Stretch so each segment fills the bar's height.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < slices.length; i++) ...[
                        // 2px surface gap between segments.
                        if (i > 0) const SizedBox(width: 2),
                        Expanded(
                          flex: (slices[i].amount / spending.monthly * 1000).round().clamp(1, 1000),
                          child: ColoredBox(color: slices[i].color),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  for (final s in slices)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${s.label} ${(s.amount / spending.monthly * 100).round()}%',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
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
