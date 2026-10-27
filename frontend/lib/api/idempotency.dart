import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A fresh `Idempotency-Key` value.
String newIdempotencyKey() => _uuid.v4();

/// Holds the idempotency key for one user action (one tap).
///
/// Use [key] for every attempt of the action, so retries after a timeout or
/// network error are recognised by the server as the same request. Call
/// [reset] once the action succeeded, or when the user starts a new one.
class IdempotentAction {
  IdempotentAction([this._generate = newIdempotencyKey]);

  final String Function() _generate;
  String? _key;

  String get key => _key ??= _generate();

  void reset() => _key = null;
}
