import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/format.dart';
import 'core/home_widget.dart';
import 'core/notifications.dart';
import 'core/theme.dart';
import 'data/providers.dart';
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
