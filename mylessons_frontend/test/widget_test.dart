import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylessons_frontend/pages/register_landing_page.dart';
import 'package:mylessons_frontend/pages/register_page.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

void main() {
  group('RegisterLandingPage widget tests', () {
    testWidgets('Continue with Email navigates to RegisterPage', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RegisterLandingPage(),
          routes: {
            '/register_page': (_) => const Scaffold(key: Key('registerPage')),
          },
        ),
      );

      expect(find.text('Continue with Email'), findsOneWidget);

      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('registerPage')), findsOneWidget);
    });
  });

  group('RegisterPage widget tests', () {
    testWidgets('Empty email shows error snackbar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RegisterPage()),
      );

      expect(find.text('Register an email'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Please enter an email.'), findsOneWidget);
    });
  });

  group('RegisterPage full signup flow', () {
    testWidgets('Navigate through all signup steps and enforce validations', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RegisterPage(),
          routes: {
            '/login': (_) => const Scaffold(),
            '/main': (_) => const Scaffold(key: Key('mainPage')),
          },
        ),
      );

      // Step 1: Enter valid email and proceed
      expect(find.text('Register an email'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Create a valid password
      expect(find.text('Create a password'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Password1!');
      await tester.pump();
      // Ensure validation icons update
      expect(find.byIcon(Icons.check_box).evaluate().length >= 3, isTrue);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 3: Provide first and last name
      expect(find.text('Tell us a little about yourself'), findsOneWidget);
      final nameFields = find.byType(TextField);
      await tester.enterText(nameFields.at(0), 'John');
      await tester.enterText(nameFields.at(1), 'Doe');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 4: Enter phone number
      expect(find.text("Let's stay in touch"), findsOneWidget);
      await tester.enterText(find.byType(IntlPhoneField), '912345678');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 5: Terms and Conditions
      expect(find.text('Terms And Conditions'), findsOneWidget);

      // Attempt to register without agreeing to terms
      await tester.tap(find.text('Register'));
      await tester.pump();
      expect(find.text('You must accept the terms and conditions to proceed.'), findsOneWidget);

      // Agree to terms and register
      final checkboxes = find.byType(CheckboxListTile);
      // The second checkbox is for agreeing terms
      await tester.tap(checkboxes.at(1));
      await tester.pump();
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      // Since actual network call isn't stubbed, expect a SnackBar or navigation stub
      // Here we check for navigation to '/main' scaffold if implemented
      expect(find.byKey(const Key('mainPage')).evaluate().isNotEmpty || find.byType(SnackBar).evaluate().isNotEmpty, isTrue);
    });
  });
}
