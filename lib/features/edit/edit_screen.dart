import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../core/notifications.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/renewal.dart';
import '../../data/templates.dart';

const _palette = [
  0xFF4F46E5, 0xFFE50914, 0xFF1DB954, 0xFF0EA5E9,
  0xFFF59E0B, 0xFFEC4899, 0xFF8B5CF6, 0xFF111827,
];
const _remindChoices = [0, 1, 2, 3, 7];

/// Adds a subscription (optionally from a [template]) or edits the one with
/// [subscriptionId].
class EditScreen extends ConsumerStatefulWidget {
  const EditScreen({super.key, this.subscriptionId, this.template});
  final String? subscriptionId;
  final Template? template;

  @override
  ConsumerState<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<EditScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _cancelUrl = TextEditingController();
  final _notes = TextEditingController();
  String? _id;
  String _currency = 'USD';
  BillingCycle _cycle = BillingCycle.monthly;
  DateTime _start = dateOnly(DateTime.now());
  String _category = 'Other';
  bool _trial = false;
  int _remindDays = 2;
  int _color = _palette.first;
  bool _active = true;
  bool _loading = true;

  bool get _isNew => widget.subscriptionId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _amount, _cancelUrl, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final settings = await db.currentSettings();
    _currency = settings?.currency ?? 'USD';
    final t = widget.template;
    if (t != null) {
      _name.text = t.name;
      _category = t.category;
      _color = t.color;
      _cancelUrl.text = t.cancelUrl;
    }
    if (!_isNew) {
      final s = await db.watchSubscription(widget.subscriptionId!).first;
      if (s != null) {
        _id = s.id;
        _name.text = s.name;
        _amount.text = _plainAmount(s.amountMinor, s.currency);
        _currency = s.currency;
        _cycle = s.cycle;
        _start = s.startDate;
        _category = s.category;
        _trial = s.isTrial;
        _remindDays = s.remindDays;
        _color = s.color;
        _cancelUrl.text = s.cancelUrl ?? '';
        _notes.text = s.notes ?? '';
        _active = s.active;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  static String _plainAmount(int minor, String currency) {
    final value = fromMinor(minor, currency);
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(decimalsOf(currency));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
      helpText: _trial ? 'Trial ends / first charge' : 'A billing date',
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final amount = double.parse(_amount.text.replaceAll(',', '.'));
    final url = _cancelUrl.text.trim();
    final notes = _notes.text.trim();
    final db = ref.read(databaseProvider);
    await db.saveSubscription(
      SubscriptionsCompanion.insert(
        id: _id ?? const Uuid().v4(),
        name: _name.text.trim(),
        amountMinor: toMinor(amount, _currency),
        currency: _currency,
        cycle: _cycle,
        startDate: _start,
        category: Value(_category),
        isTrial: Value(_trial),
        remindDays: Value(_remindDays),
        color: _color,
        cancelUrl: Value(url.isEmpty ? null : url),
        notes: Value(notes.isEmpty ? null : notes),
        active: Value(_active),
      ),
    );
    // Ask only after the user has chosen a subscription and saved it. Saving
    // still succeeds when notification access is denied.
    final settings = await db.currentSettings();
    if (_isNew && (settings?.remindersOn ?? true)) {
      await requestNotificationPermission();
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_name.text}?'),
        content: const Text('Its reminders stop too. To keep it in your history, pause it instead.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.soon),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true || _id == null) return;
    await ref.read(databaseProvider).deleteSubscription(_id!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openCancelPage() async {
    final uri = Uri.tryParse(_cancelUrl.text.trim());
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn\'t open that link')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final next = upcomingBills(_cycle, _start, DateTime.now()).first;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New subscription' : 'Edit subscription'),
        actions: [
          if (!_isNew)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _save,
            child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: _isNew && widget.template == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _amount,
                    autofocus: _isNew && widget.template != null,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(labelText: 'Price'),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                      return n == null || n <= 0 ? 'Enter the price' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: [
                      for (final c in {...currencies, _currency})
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Billed'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in BillingCycle.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _cycle == c,
                    onSelected: (_) => setState(() => _cycle = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Free trial'),
              subtitle: const Text('Get a warning before the first charge'),
              value: _trial,
              onChanged: (v) => setState(() => _trial = v),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(_trial ? 'Trial ends / first charge' : 'Billing date'),
                subtitle: Text(fullDate(_start)),
                trailing: Text(
                  'Next: ${fullDate(next)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _remindDays,
              decoration: const InputDecoration(labelText: 'Remind me', prefixIcon: Icon(Icons.notifications_outlined)),
              items: [
                for (final d in {..._remindChoices, _remindDays})
                  DropdownMenuItem(value: d, child: Text(remindLabel(d))),
              ],
              onChanged: (v) => setState(() => _remindDays = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in {...categories, _category}) DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            const _Label('Colour'),
            Wrap(
              spacing: 10,
              children: [
                for (final c in {..._palette, _color})
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(c),
                      child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cancelUrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Cancel or manage link (optional)',
                suffixIcon: IconButton(
                  tooltip: 'Open',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: _openCancelPage,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            if (!_isNew)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('Turn off when you pause or cancel it'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
  );
}
