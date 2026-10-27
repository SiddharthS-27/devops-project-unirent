import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unirent/app/app.dart';

void main() {
  testWidgets('app boots and renders the placeholder home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: UniRentApp()));

    expect(find.text('UniRent'), findsOneWidget);
  });
}
