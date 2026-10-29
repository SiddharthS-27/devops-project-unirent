import 'package:flutter/material.dart';

import '../tokens.dart';

/// Outlined surface card; tappable when [onTap] is set.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.semanticContainer = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// False when the card groups separate things (rows, figures) that screen
  /// readers should reach one by one rather than as one node.
  final bool semanticContainer;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Card(
      clipBehavior: Clip.antiAlias,
      semanticContainer: semanticContainer,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}
