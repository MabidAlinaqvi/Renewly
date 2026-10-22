import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/chart_colors.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../data/rates.dart';
import '../../data/spending.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spending = ref.watch(spendingProvider);
    final updated = ref.watch(settingsProvider).value?.ratesUpdatedAt;
    final slices = categorySlices(spending.byCategory);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: spending.included.isEmpty
          ? const Center(child: Text('Add a subscription to see insights'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _Section(
                  title: 'Where your money goes',
                  subtitle: '${moneyMajor(spending.monthly, spending.currency)} each month',
                  child: _CategoryDonut(slices: slices, spending: spending),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Next 6 months',
                  subtitle: 'What will actually be charged, month by month',
                  child: _MonthsChart(spending: spending),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Biggest subscriptions',
                  subtitle: 'Monthly cost, in ${spending.currency}',
                  child: _Biggest(spending: spending),
                ),
                const SizedBox(height: 16),
                if (spending.convertedCount > 0) _RatesNote(updated: updated),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _CategoryDonut extends StatefulWidget {
  const _CategoryDonut({required this.slices, required this.spending});
  final List<({String label, Color color, double amount})> slices;
  final Spending spending;

  @override
  State<_CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<_CategoryDonut> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final slices = widget.slices;
    final total = widget.spending.monthly;
    final focus = _touched == null || _touched! >= slices.length ? null : slices[_touched!];
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  // Surface-coloured gaps keep neighbouring slices apart.
                  sectionsSpace: 2,
                  centerSpaceRadius: 62,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions) return;
                      setState(() => _touched = response?.touchedSection?.touchedSectionIndex);
                    },
                  ),
                  sections: [
                    for (var i = 0; i < slices.length; i++)
                      PieChartSectionData(
                        value: slices[i].amount,
                        color: slices[i].color,
                        radius: i == _touched ? 34 : 28,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    focus?.label ?? 'Per month',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  Text(
                    moneyCompact(focus?.amount ?? total, widget.spending.currency),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  if (focus != null)
                    Text(
                      '${(focus.amount / total * 100).round()}%',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // The legend doubles as the table view: every slice with its value.
        for (var i = 0; i < slices.length; i++)
          InkWell(
            onTap: () => setState(() => _touched = _touched == i ? null : i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: slices[i].color, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      slices[i].label,
                      style: TextStyle(fontWeight: i == _touched ? FontWeight.w800 : FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${(slices[i].amount / total * 100).round()}%',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 96,
                    child: Text(
                      moneyMajor(slices[i].amount, widget.spending.currency),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthsChart extends StatelessWidget {
  const _MonthsChart({required this.spending});
  final Spending spending;

  @override
  Widget build(BuildContext context) {
    final months = spending.nextMonths(DateTime.now());
    final top = months.fold(0.0, (a, m) => a > m.amount ? a : m.amount);
    final maxY = top == 0 ? 1.0 : top * 1.2;
    final currency = spending.currency;
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) => value == 0 || value >= maxY
                    ? const SizedBox()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(
                          moneyCompact(value, currency),
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat.MMM().format(months[value.toInt()].month),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.textMain,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${DateFormat.yMMMM().format(months[group.x].month)}\n',
                const TextStyle(color: Color(0xFFC7D2FE), fontSize: 12),
                children: [
                  TextSpan(
                    text: moneyMajor(rod.toY, currency),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < months.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: months[i].amount,
                    width: 22,
                    // The current month is solid; later months are the same hue, lighter.
                    color: i == 0 ? AppColors.primary : AppColors.primary.withValues(alpha: .55),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Biggest extends ConsumerWidget {
  const _Biggest({required this.spending});
  final Spending spending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final converter = Converter(ref.watch(ratesProvider).value ?? const {});
    final rows = [
      for (final s in spending.included)
        (
          sub: s,
          monthly: converter.convert(fromMinor(s.cycle.perMonth(s.amountMinor), s.currency), s.currency, spending.currency)!,
        ),
    ]..sort((a, b) => b.monthly.compareTo(a.monthly));
    final top = rows.isEmpty ? 1.0 : rows.first.monthly;
    return Column(
      children: [
        for (final r in rows.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(r.sub.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(
                      moneyMajor(r.monthly, spending.currency),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: r.monthly / top,
                    minHeight: 8,
                    backgroundColor: AppColors.surface,
                    color: categoryColor(r.sub.category),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RatesNote extends StatelessWidget {
  const _RatesNote({required this.updated});
  final DateTime? updated;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => launchUrl(Uri.parse(ratesCreditUrl), mode: LaunchMode.externalApplication),
      child: Text(
        updated == null
            ? 'Other currencies converted. $ratesCredit'
            : 'Converted with rates from ${DateFormat.MMMd().format(updated!)}. $ratesCredit',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    ),
  );
}
