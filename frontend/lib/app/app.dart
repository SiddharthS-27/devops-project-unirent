import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/ui.dart';
import 'router.dart';
import 'session.dart';

/// Root widget of the UniRent app. Restores the stored session on start.
class UniRentApp extends ConsumerStatefulWidget {
  const UniRentApp({super.key});

  @override
  ConsumerState<UniRentApp> createState() => _UniRentAppState();
}

class _UniRentAppState extends ConsumerState<UniRentApp> {
  @override
  void initState() {
    super.initState();
    // After the first build: providers can't change during initState.
    unawaited(Future.microtask(ref.read(sessionProvider.notifier).restore));
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
