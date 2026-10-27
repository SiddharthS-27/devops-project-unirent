import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/app/routes.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('app boots to the sign-in screen', (tester) async {
    final app = await pumpTestApp(tester);
    expect(app.location, Routes.signIn);
    expect(find.text('Welcome to UniRent'), findsOneWidget);
    expect(find.text('Staff sign in'), findsOneWidget);
  });
}
