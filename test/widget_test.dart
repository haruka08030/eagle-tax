// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eagle_tax/main.dart';

void main() {
  testWidgets('Eagle Tax app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EagleTaxApp());

    // Verify that the app title is displayed
    expect(find.text('🇺🇸 Eagle Tax Monitor'), findsOneWidget);
    
    // Verify that the initial status message is displayed
    expect(find.text('ボタンを押して診断を開始してください'), findsOneWidget);
    
    // Verify that the button exists
    expect(find.text('リスク診断を実行'), findsOneWidget);
  });
}


