import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// Lets the user take or choose photos.
abstract interface class PhotoPicker {
  /// Returns up to [max] photos' bytes; empty if the user cancelled.
  Future<List<Uint8List>> pick(PhotoSource source, {required int max});
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<Uint8List>> pick(PhotoSource source, {required int max}) async {
    if (max <= 0) return const [];
    final List<XFile> files;
    if (source == PhotoSource.camera) {
      final file = await _picker.pickImage(source: ImageSource.camera);
      files = [?file];
    } else if (max == 1) {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      files = [?file];
    } else {
      files = await _picker.pickMultiImage(limit: max);
    }
    return [for (final f in files.take(max)) await f.readAsBytes()];
  }
}

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => ImagePickerPhotoPicker(),
);
