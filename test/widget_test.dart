// Widget test for ADSB Support Desk
//
// This test verifies the app boots up and shows the login screen
// when no user is logged in.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adsb_support_desk/app.dart';

void main() {
  testWidgets('App boots and shows splash screen', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const AdsbSupportApp());

    // Splash screen shows the app name
    expect(find.text('ADSB Support Desk'), findsWidgets);

    // Wait for splash to finish and navigate to login
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Login screen should be visible
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}