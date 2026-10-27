import 'package:flutter/material.dart';

/// Root widget of the UniRent app.
class UniRentApp extends StatelessWidget {
  const UniRentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniRent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const Scaffold(body: Center(child: Text('UniRent'))),
    );
  }
}
