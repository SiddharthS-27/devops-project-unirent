import 'package:flutter/material.dart';

import '../../../api/api.dart';
import '../listing_format.dart';

/// A listing photo that degrades to a category placeholder.
///
/// `mock://photo/<rrggbb>` URLs (used by the mock backend) render as a solid
/// colour, so mock builds and tests never touch the network.
class ListingPhoto extends StatelessWidget {
  const ListingPhoto({
    super.key,
    required this.url,
    required this.category,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final ListingCategory category;
  final BorderRadius borderRadius;
  final BoxFit fit;

  static Color? mockColor(String url) {
    const prefix = 'mock://photo/';
    if (!url.startsWith(prefix)) return null;
    final hex = int.tryParse(url.substring(prefix.length), radix: 16);
    return hex == null ? null : Color(0xFF000000 | hex);
  }

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final scheme = Theme.of(context).colorScheme;

    Widget placeholder([Color? color]) => ColoredBox(
      color: color ?? scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          categoryIcon(category),
          color: color == null
              ? scheme.onSurfaceVariant
              : Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );

    final Widget image;
    if (url == null) {
      image = placeholder();
    } else if (mockColor(url) case final color?) {
      image = placeholder(color);
    } else {
      image = Image.network(
        url,
        fit: fit,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => placeholder(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder(),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox.expand(child: image),
    );
  }
}
