import 'package:flutter_test/flutter_test.dart';
import 'package:xlive_mobile/src/app.dart';
import 'package:xlive_mobile/src/auth/dark_onboarding_screen.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const XLiveApp());
    await tester.pump();
    expect(find.text('Xlive'), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.byType(DarkOnboardingScreen), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
