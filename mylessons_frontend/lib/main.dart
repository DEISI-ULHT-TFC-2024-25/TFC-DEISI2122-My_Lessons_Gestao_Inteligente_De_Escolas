import 'package:flutter/material.dart';
import 'package:mylessons_frontend/pages/register_landing_page.dart';
import 'pages/email_login_page.dart';
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'main_layout.dart'; // Import MainScreen
import 'package:flutter/rendering.dart';

// 1. Import the Firebase packages
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Create a global RouteObserver instance.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> main() async {
  // 2. Ensure bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPaintSizeEnabled = false;
  runApp(
    MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyLessons App',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white, // Bottom navigation bar is white
        ),
        // Progress Indicator theme: orange color for loading indicators.
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.orange,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
        ),
        cardTheme: CardTheme(
          color: Colors.grey[50], // Light grey
        ),
        // ---- SnackBar styling ----
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Colors.orange, // Orange background
          contentTextStyle: TextStyle(
            color: Colors.white, // White text
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          actionTextColor: Colors.white, // Action button text color
          // You can also adjust the shape, behavior, etc.
        ),
        primarySwatch: Colors.orange,
        timePickerTheme: TimePickerThemeData(),
        datePickerTheme: DatePickerThemeData(
          // Header
          headerBackgroundColor: Colors.orange,
          headerForegroundColor: Colors.white,

          // Highlight "today" with an orange border
          todayBorder: const BorderSide(color: Colors.orange, width: 1.5),

          // Day text color for different states
          dayForegroundColor:
              MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.selected)) {
              // Selected day text = white
              return Colors.white;
            }
            // Fallback to default text color
            return null;
          }),

          // Day background color for different states
          dayBackgroundColor:
              MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.selected)) {
              // Selected day background = orange
              return Colors.orange;
            }
            // No background for unselected days
            return null;
          }),

          // “Today” text color for different states
          todayForegroundColor:
              MaterialStateProperty.resolveWith<Color?>((states) {
            // If "today" is also selected, use white text
            if (states.contains(MaterialState.selected)) {
              return Colors.white;
            }
            // Otherwise, orange text
            return Colors.orange;
          }),

          // “Today” background color (only if you want a fill for today)
          todayBackgroundColor:
              MaterialStateProperty.resolveWith<Color?>((states) {
            // If today is selected, fill it with orange
            if (states.contains(MaterialState.selected)) {
              return Colors.orange;
            }
            // Otherwise transparent
            return null;
          }),

          // Remove or customize the Material3 hover/ripple overlay (often purple-ish)
          dayOverlayColor: MaterialStateProperty.all(Colors.transparent),
        ),
        // Make checkboxes orange when checked:
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.all(Colors.orange),
        ),
        tabBarTheme: const TabBarTheme(
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          labelStyle: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 14.0,
          ),
        ),
        // ElevatedButtons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.black, // <--- Button text color
          ),
        ),

        // TextButtons
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.black, // <--- Button text color
          ),
        ),

        // OutlinedButtons (if you use them)
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black, // <--- Button text color
            side: const BorderSide(color: Colors.orange),
          ),
        ),

        // TextField cursor, selection, labels, etc.
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.orange,
          selectionColor: Colors.orange.withOpacity(0.3),
          selectionHandleColor: Colors.orange,
        ),

        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.orange),
          floatingLabelStyle: TextStyle(color: Colors.orange),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
            borderSide: const BorderSide(color: Colors.orange),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
            borderSide: const BorderSide(color: Colors.orange),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LandingPage(),
        '/main': (context) => const MainScreen(), // New main route with navbar
        '/login': (context) => const LoginPage(),
        '/register_landing_page': (context) => const RegisterLandingPage(),
        '/register_page': (context) => const RegisterPage(),
        '/email_login': (context) => const EmailLoginPage(),
      },
      // Add the global RouteObserver to navigatorObservers
      navigatorObservers: [routeObserver],
    );
  }
}
