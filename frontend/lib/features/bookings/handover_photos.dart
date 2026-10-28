import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../listings/photos/photo_picker.dart';
import '../listings/photos/photo_uploader.dart';

/// Lets the user take or choose up to [max] photos and uploads them for a
/// handover. Returns the storage keys, or null if nothing was picked.
Future<List<String>?> pickAndUploadHandoverPhotos(
  BuildContext context,
  WidgetRef ref, {
  int max = 8,
}) async {
  final source = await showModalBottomSheet<PhotoSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photos'),
            onTap: () => Navigator.pop(context, PhotoSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, PhotoSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final List<Uint8List> picked = await ref
      .read(photoPickerProvider)
      .pick(source, max: max);
  if (picked.isEmpty) return null;
  final uploader = ref.read(photoUploaderProvider);
  return [
    for (final bytes in picked)
      await uploader.upload(bytes, purpose: UploadPurpose.handover),
  ];
}
