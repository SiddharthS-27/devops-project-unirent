import 'package:flutter/material.dart';
import 'package:unirent/ui/ui.dart';

/// Wraps [child] in a themed app so design-system widgets can be pumped.
Widget themed(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}
