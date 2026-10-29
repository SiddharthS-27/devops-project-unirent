import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// The UniRent mark: a "U" whose right stem turns into an arrow pointing
/// back up. Lend it out, get it back. Drawn in the one accent hue.
class UniRentMark extends StatelessWidget {
  const UniRentMark({super.key, this.size = 24, this.color});

  final double size;

  /// Defaults to the theme's accent.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'UniRent',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(color ?? AppSurfaces.of(context).accent),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The U: left stem, bowl, right stem.
    final u = Path()
      ..moveTo(4.5 * s, 4 * s)
      ..lineTo(4.5 * s, 13 * s)
      ..arcTo(
        Rect.fromLTWH(4.5 * s, 6 * s, 14 * s, 14 * s),
        3.14159265,
        -3.14159265,
        false,
      )
      ..lineTo(18.5 * s, 8 * s);
    canvas.drawPath(u, paint);

    // The arrowhead on the right stem: the item comes back.
    final arrow = Path()
      ..moveTo(14.5 * s, 8 * s)
      ..lineTo(18.5 * s, 4 * s)
      ..lineTo(22.5 * s, 8 * s);
    canvas.drawPath(arrow, paint);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}

/// The mark beside the name, for the shell and the first screen.
class UniRentWordmark extends StatelessWidget {
  const UniRentWordmark({super.key, this.markSize = 22});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: UniRentMark(size: markSize)),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'UniRent',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
