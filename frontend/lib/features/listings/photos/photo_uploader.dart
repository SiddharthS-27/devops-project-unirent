import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import 'photo_processing.dart';

/// PUTs bytes to a presigned storage URL.
typedef UploadPut =
    Future<void> Function(
      String url,
      Map<String, String> headers,
      Uint8List bytes,
    );

/// Uploads straight to storage with a bare client, so our bearer token is
/// never sent to the storage host. In mock mode it just marks the key as
/// uploaded in the mock backend.
final uploadPutProvider = Provider<UploadPut>((ref) {
  final mock = ref.watch(mockServerProvider);
  if (mock != null) {
    return (url, headers, bytes) async {
      const prefix = 'mock://upload/';
      if (url.startsWith(prefix)) {
        mock.db.uploadedKeys.add(url.substring(prefix.length));
      }
    };
  }
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 60),
    ),
  );
  ref.onDispose(dio.close);
  return (url, headers, bytes) async {
    try {
      await dio.put<void>(
        url,
        data: Stream.value(bytes),
        options: Options(
          headers: {...headers, Headers.contentLengthHeader: bytes.length},
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  };
});

/// Prepares a picked photo and uploads it; returns its storage object key
/// for confirming on a listing.
class PhotoUploader {
  PhotoUploader(this._api, this._process, this._put);

  final UniRentApi _api;
  final PhotoProcessor _process;
  final UploadPut _put;

  Future<String> upload(
    Uint8List rawBytes, {
    UploadPurpose purpose = UploadPurpose.listing,
  }) async {
    final Uint8List jpeg;
    try {
      jpeg = await _process(rawBytes);
    } on FormatException {
      throw const UserFacingException('That file isn’t a photo we can use.');
    }
    final target = await _api.listings.presignPhotoUpload(
      UploadRequest(purpose: purpose),
    );
    await _put(target.uploadUrl, target.headers, jpeg);
    return target.objectKey;
  }
}

final photoUploaderProvider = Provider<PhotoUploader>(
  (ref) => PhotoUploader(
    ref.watch(apiProvider),
    ref.watch(photoProcessorProvider),
    ref.watch(uploadPutProvider),
  ),
);
