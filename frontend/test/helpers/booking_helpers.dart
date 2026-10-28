import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:unirent/api/mock/mock_server.dart';
import 'package:unirent/app/routes.dart';
import 'package:unirent/features/listings/photos/photo_picker.dart';
import 'package:unirent/features/listings/photos/photo_processing.dart';
import 'package:unirent/ui/ui.dart';

import 'test_app.dart';

class FakePhotoPicker implements PhotoPicker {
  @override
  Future<List<Uint8List>> pick(PhotoSource source, {required int max}) async =>
      [img.encodeJpg(img.Image(width: 20, height: 20))];
}

/// Photos without the camera, processed in-process (isolates don't run
/// under the widget-test clock).
List<Override> photoOverrides() => [
  photoPickerProvider.overrideWithValue(FakePhotoPicker()),
  photoProcessorProvider.overrideWithValue(
    (bytes) async => prepareListingPhoto(bytes),
  ),
];

/// "Switches phones": pumps the app signed in as [email] on the shared
/// [server] and opens [location].
Future<TestApp> as(
  WidgetTester tester,
  MockServer server,
  String email, {
  String? location,
  FakePushService? push,
}) async {
  final app = await pumpSignedIn(
    tester,
    email,
    server: server,
    push: push,
    overrides: photoOverrides(),
  );
  if (location != null) {
    unawaited(app.router.push(location));
    await tester.pumpAndSettle();
  }
  return app;
}

Future<TestApp> openBookingAs(
  WidgetTester tester,
  MockServer server,
  String email,
  String bookingId,
) => as(tester, server, email, location: Routes.booking(bookingId));

Finder stepFinder(String title) =>
    find.widgetWithText(ChecklistStep, title).first;

ChecklistStepState stepState(WidgetTester tester, String title) =>
    tester.widget<ChecklistStep>(stepFinder(title)).state;

Future<void> tapStep(TestApp app, String title, String action) => app.tap(
  find.descendant(of: stepFinder(title), matching: find.text(action)).last,
);

Future<void> confirmDialog(TestApp app, String label) => app.tap(
  find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, label),
  ),
);

Future<void> addPhotosVia(TestApp app, String step) async {
  await tapStep(app, step, 'Add photos');
  await app.tapText('Choose from gallery');
}

/// The 6-digit code shown on screen, read back from the OtpDisplay.
String shownCode(WidgetTester tester) =>
    tester.widget<OtpDisplay>(find.byType(OtpDisplay)).code;
