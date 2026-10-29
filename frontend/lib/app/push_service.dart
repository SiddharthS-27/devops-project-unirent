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

  /// Deep links (`unirent://bookings/{id}`) of pushes received while the app
  /// is open, so open screens can refetch.
  Stream<Uri> get received;

  /// Deep links of notifications the user tapped, to navigate to.
  Stream<Uri> get opened;
}

/// The `link` a push carries in its data, if any.
Uri? pushLink(Map<String, dynamic> data) {
  final link = data['link'];
  return link is String ? Uri.tryParse(link) : null;
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

  @override
  Stream<Uri> get received => const Stream.empty();

  @override
  Stream<Uri> get opened => const Stream.empty();
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
  Stream<Uri> get received => FirebaseMessaging.onMessage
      .map((m) => pushLink(m.data))
      .where((link) => link != null)
      .cast<Uri>();

  @override
  Stream<Uri> get opened async* {
    final initial = await _messaging.getInitialMessage();
    final link = initial == null ? null : pushLink(initial.data);
    if (link != null) yield link;
    yield* FirebaseMessaging.onMessageOpenedApp
        .map((m) => pushLink(m.data))
        .where((link) => link != null)
        .cast<Uri>();
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

/// A push received while the app is open. Each push is a new object, so
/// two pushes with the same link both notify listeners.
class ReceivedPush {
  ReceivedPush(this.link);

  final Uri link;
}

/// Pushes received while the app is open.
final pushReceivedProvider = StreamProvider<ReceivedPush>(
  (ref) => ref.watch(pushServiceProvider).received.map(ReceivedPush.new),
);
