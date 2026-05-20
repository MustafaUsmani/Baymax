import 'package:flutter_test/flutter_test.dart';
import 'package:crisis_link/main.dart';

void main() {
  testWidgets('CrisisLinkApp instantiation smoke test', (WidgetTester tester) async {
    // Verify that the CrisisLinkApp widget can be constructed successfully.
    const app = CrisisLinkApp();
    expect(app, isNotNull);
  });
}
