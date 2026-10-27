// The worker sends with FCM HTTP v1 `message.token`, which takes an FCM
// registration token. firebase_messaging 17 deprecates getToken() and friends
// in favour of Firebase Installation IDs for its newer direct-send API, which
// the backend doesn't use yet, so the token API is kept on purpose.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import 'firebase_setup.dart';

/// Registers this device for push notifications with the backend.
abstract interface class PushService {
  /// Whether push notifications are configured in this build.
  bool get isAvailable;

  /// Asks for permission and registers the device token. Returns whether
  /// permission was granted.
  Future<bool> enable();

  /// Re-registers the token if permission was granted earlier.
  Future<void> syncIfPermitted();

  /// Removes this device's token from the backend (on sign-out).
  Future<void> unregister();
}

/// Used when Firebase isn't configured.
class UnavailablePushService implements PushService {
  const UnavailablePushService();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> enable() async => false;

  @override
  Future<void> syncIfPermitted() async {}

  @override
  Future<void> unregister() async {}
}

class FirebasePushService implements PushService {
  FirebasePushService(this._api, [FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final UniRentApi _api;
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _tokenRefresh;
  String? _token;

  @override
  bool get isAvailable => true;

  static bool _granted(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  @override
  Future<bool> enable() async {
    final granted = _granted(await _messaging.requestPermission());
    if (granted) await _register();
    return granted;
  }

  @override
  Future<void> syncIfPermitted() async {
    if (_granted(await _messaging.getNotificationSettings())) {
      await _register();
    }
  }

  Future<void> _register() async {
    final token = await _messaging.getToken();
    if (token != null) await _send(token);
    _tokenRefresh ??= _messaging.onTokenRefresh.listen((token) {
      unawaited(_send(token).catchError((Object _) {}));
    });
  }

  Future<void> _send(String token) async {
    await _api.devices.registerPushToken(
      PushTokenIn(
        token: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? DevicePlatform.ios
            : DevicePlatform.android,
      ),
    );
    _token = token;
  }

  @override
  Future<void> unregister() async {
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    final token = _token ?? await _messaging.getToken();
    _token = null;
    if (token == null) return;
    await _api.devices.removePushToken(token);
    await _messaging.deleteToken();
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return const UnavailablePushService();
  return FirebasePushService(ref.watch(apiProvider));
});
