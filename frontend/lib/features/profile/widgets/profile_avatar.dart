import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../listings/widgets/listing_photo.dart';

/// A round profile photo, falling back to the first initial.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.bytes,
    this.radius = 28,
  });

  final String name;
  final String? photoUrl;

  /// A just-picked photo, shown before it's saved.
  final Uint8List? bytes;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: TextStyle(fontSize: radius * 0.8),
    );
    final url = photoUrl;
    final bytes = this.bytes;
    final mockColour = url == null ? null : ListingPhoto.mockColor(url);
    final Widget avatar;
    if (bytes != null) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(bytes),
      );
    } else if (mockColour != null) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: mockColour,
        foregroundColor: Colors.white,
        child: initial,
      );
    } else if (url != null) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, _) {},
        child: initial,
      );
    } else {
      avatar = CircleAvatar(radius: radius, child: initial);
    }
    return Semantics(
      image: true,
      label: '$name’s photo',
      child: ExcludeSemantics(child: avatar),
    );
  }
}
