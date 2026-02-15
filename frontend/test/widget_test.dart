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
    // Verify that the title is present (Dashboard header or Sidebar item).
    // Or just check for key elements.
    expect(find.text('FORENSIC ANALYSIS'), findsOneWidget);

    // Verify input hint or analyze button.
    expect(find.text('ANALYZE'), findsOneWidget);
  });
}
