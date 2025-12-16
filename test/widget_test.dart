// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eagle_tax/main.dart';

void main() {
  setUpAll(() async {
    // Mock SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    
    // Initialize Supabase only if not already initialized
    try {
      // Check if Supabase is already initialized
      Supabase.instance;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://dummy.supabase.co',
        anonKey: 'dummy.anon.key',
      );
    }
  });

  testWidgets('Eagle Tax app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EagleTaxApp());

    // Verify that the app shows a loading indicator initially
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}


