import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/app/app.dart';

void main() {
  testWidgets('app boots to the sign-in screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: UniRentApp()));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Welcome to UniRent'), findsOneWidget);
  });
}
