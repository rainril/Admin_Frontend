import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/login_screen.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Provide the initialPage required by the PrimeFitApp constructor.
    await tester.pumpWidget(const PrimeFitApp(initialPage: LoginScreen()));
    expect(find.text('Admin Sign In'), findsOneWidget);
  });
}
 