import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../listings/listing_providers.dart';
import '../reviews/pending_reviews.dart';
import 'booking_providers.dart';

/// Runs booking actions with one idempotency key per action (kept for
/// retries after connection problems), then refreshes everything that
/// shows the booking.
mixin BookingActionRunner<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  final _actions = <String, IdempotentAction>{};
  String? busyAction;

  IdempotentAction actionFor(String name) => _actions.putIfAbsent(
    name,
    () => IdempotentAction(ref.read(idempotencyKeyFactoryProvider)),
  );

  /// Refreshes the booking and the lists and listings that show it.
  void refreshBooking(String bookingId, {String? listingId}) {
    ref
      ..invalidate(bookingProvider(bookingId))
      ..invalidate(myBookingsProvider)
      ..invalidate(incomingRequestsProvider);
    if (listingId != null) ref.invalidate(listingDetailProvider(listingId));
    // A handover or Proceed can open reviews (which gate the app).
    unawaited(ref.read(pendingReviewsProvider.notifier).refresh());
  }

  /// Runs [call] as action [name]; returns its result, or null on failure
  /// (after showing why).
  Future<R?> runAction<R>(
    String name,
    Future<R> Function(String idempotencyKey) call, {
    required String bookingId,
    String? listingId,
    String? done,
  }) async {
    final action = actionFor(name);
    setState(() => busyAction = name);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await call(action.key);
      action.reset();
      if (done != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(done)));
      }
      refreshBooking(bookingId, listingId: listingId);
      return result;
    } on ApiException catch (error) {
      if (!error.isConnectivityProblem) action.reset();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
      // The booking moved on elsewhere: show its current state.
      if (error.code == 'BOOKING_STATE' || error.code == 'STEP_LOCKED') {
        refreshBooking(bookingId, listingId: listingId);
      }
      return null;
    } on Object catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
      return null;
    } finally {
      if (mounted) setState(() => busyAction = null);
    }
  }
}
