// integration_test/register_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mylessons_frontend/main.dart' as app;


void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full signup flow with real backend', (WidgetTester tester) async {

    // Launch the actual app.
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // LandingPage → Sign up for free
    final signUpButton = find.text('Sign up for free');
    expect(signUpButton, findsOneWidget);
    await tester.tap(signUpButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // RegisterLandingPage → Continue with Email
    final continueEmail = find.text('Continue with Email');
    expect(continueEmail, findsOneWidget);
    await tester.tap(continueEmail);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Step 1: Email
    final emailField = find.byType(TextField).first;
    await tester.enterText(emailField, 'test${DateTime.now().millisecondsSinceEpoch}@example.com');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Step 2: Password
    final passwordField = find.byType(TextField).first;
    await tester.enterText(passwordField, 'StrongPass1!');
    await tester.pump(); // wait for validation
    expect(find.byIcon(Icons.check_box).evaluate().length >= 3, isTrue);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Step 3: First & Last Name
    final nameFields = find.byType(TextField);
    await tester.enterText(nameFields.at(0), 'Integration');
    await tester.enterText(nameFields.at(1), 'Test');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Step 4: Phone
    // Note: IntlPhoneField renders as a TextField internally
    final phoneField = find.byType(TextField).last;
    await tester.enterText(phoneField, '912345678');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Step 5: Terms & Conditions
    final termsTitle = find.text('Terms And Conditions');
    expect(termsTitle, findsOneWidget);

    // Try without agreeing
    await tester.tap(find.text('Register'));
    await tester.pump();
    expect(find.text('You must accept the terms and conditions to proceed.'), findsOneWidget);

    // Agree and submit
    final checkboxes = find.byType(CheckboxListTile);
    await tester.tap(checkboxes.at(1)); // agree terms
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('Register'));
    // give it some time to POST and navigate
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // instead of byKey:
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
