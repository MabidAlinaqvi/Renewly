import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/format.dart';
import 'core/home_widget.dart';
import 'core/notifications.dart';
import 'core/theme.dart';
import 'data/database.dart';
import 'data/providers.dart';
import 'data/rates.dart';
import 'features/edit/edit_screen.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: RenewlyApp()));
}

class RenewlyApp extends ConsumerStatefulWidget {
  const RenewlyApp({super.key});

  @override
  ConsumerState<RenewlyApp> createState() => _RenewlyAppState();
}

class _RenewlyAppState extends ConsumerState<RenewlyApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _subscriptions = <StreamSubscription<void>>[];
  Timer? _rescheduleTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _rescheduleTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final db = ref.read(databaseProvider);
    await db.ensureSettings(await deviceCurrency());
    unawaited(refreshRates(db));
    unawaited(_checkTravel(db));
    await initNotifications(_openSubscription);
    // Any change to subscriptions or settings rebuilds the reminders, batched
    // so a burst of edits schedules once.
    void changed(_) {
      _rescheduleTimer?.cancel();
      _rescheduleTimer = Timer(
        const Duration(milliseconds: 500),
        () {
          rescheduleNotifications(db);
          updateHomeWidget(db);
        },
      );
    }

    _subscriptions
      ..add(db.watchSubscriptions().listen(changed))
      ..add(db.watchSettings().listen(changed));
    final opened = await launchPayload();
    if (opened != null) _openSubscription(opened);
  }

  /// When the phone turns up in a new country, offers that country's
  /// currency. It only ever asks; the user's choice is never changed silently.
  Future<void> _checkTravel(AppDatabase db) async {
    final country = await currentCountry();
    final settings = await db.currentSettings();
    if (country == null || settings == null || settings.lastCountry == country) return;
    await db.updateSettings(SettingsCompanion(lastCountry: Value(country)));
    // The first country seen is just remembered: the currency was picked from it.
    if (settings.lastCountry == null) return;
    final suggested = currencyOfCountry(country);
    if (suggested == null || suggested == settings.currency) return;
    // Wait for the first screen.
    while (_navigator.currentContext == null) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final context = _navigator.currentContext!;
    if (!context.mounted) return;
    final change = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.flight_land_outlined),
        title: const Text('New country?'),
        content: Text(
          'Your phone is now on a network in $country. Show totals in $suggested instead of ${settings.currency}? '
          'Prices you entered stay as they are; totals are converted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Keep ${settings.currency}')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('Switch to $suggested')),
        ],
      ),
    );
    if (change == true) await db.updateSettings(SettingsCompanion(currency: Value(suggested)));
  }

  void _openSubscription(String id) {
    _navigator.currentState?.push(
      MaterialPageRoute(builder: (_) => EditScreen(subscriptionId: id)),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Renewly',
    navigatorKey: _navigator,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const HomeScreen(),
  );
}
