import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

/// Longest side of an uploaded photo, in pixels (the backend's limit).
const maxPhotoDimension = 1600;
const photoJpegQuality = 82;

/// Decodes any common image format, applies its EXIF rotation, shrinks it
/// to [maxPhotoDimension] and re-encodes it as JPEG.
///
/// Throws [FormatException] if [bytes] isn't an image.
Uint8List prepareListingPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Not an image');
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > maxPhotoDimension) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxPhotoDimension)
        : img.copyResize(image, height: maxPhotoDimension);
  }
  return img.encodeJpg(image, quality: photoJpegQuality);
}

typedef PhotoProcessor = Future<Uint8List> Function(Uint8List bytes);

/// Runs [prepareListingPhoto] off the UI thread.
final photoProcessorProvider = Provider<PhotoProcessor>(
  (ref) =>
      (bytes) => Isolate.run(() => prepareListingPhoto(bytes)),
);
