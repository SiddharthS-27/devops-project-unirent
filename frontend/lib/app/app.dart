import 'package:flutter/material.dart';

import '../ui/ui.dart';

/// Root widget of the UniRent app.
class UniRentApp extends StatelessWidget {
  const UniRentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniRent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Scaffold(body: EmptyState(title: 'UniRent')),
    );
  }
}
