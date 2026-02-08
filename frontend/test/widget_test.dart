// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:fake_news_detector/main.dart';

void main() {
  testWidgets('VeriScan UI smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VeriScanApp());

    // Verify that the title is present.
    expect(find.text('VeriScan AI'), findsOneWidget);

    // Verify that the helper text is present.
    expect(find.text('Verify the truth with Gemini AI'), findsOneWidget);

    // Verify that the button is present.
    expect(find.text('Verify Claim'), findsOneWidget);
  });
}
