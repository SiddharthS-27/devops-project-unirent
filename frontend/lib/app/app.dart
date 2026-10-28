import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/ui.dart';
import 'push_service.dart';
import 'router.dart';
import 'session.dart';

/// Root widget of the UniRent app. Restores the stored session on start.
class UniRentApp extends ConsumerStatefulWidget {
  const UniRentApp({super.key});

  @override
  ConsumerState<UniRentApp> createState() => _UniRentAppState();
}

class _UniRentAppState extends ConsumerState<UniRentApp> {
  StreamSubscription<Uri>? _openedPushes;

  @override
  void initState() {
    super.initState();
    // Tapping a notification opens its deep link (unirent://bookings/{id}).
    _openedPushes = ref
        .read(pushServiceProvider)
        .opened
        .listen((link) => ref.read(routerProvider).go(link.toString()));
    // After the first build: providers can't change during initState.
    unawaited(Future.microtask(ref.read(sessionProvider.notifier).restore));
  }

  @override
  void dispose() {
    unawaited(_openedPushes?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'UniRent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
