import 'package:flutter/material.dart';
import 'pages/register_page.dart';
import 'pages/login_page.dart' as login;
import 'main_layout.dart'; // Import MainScreen
import 'package:flutter/rendering.dart';

// 1. Import the Firebase packages
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

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
        primarySwatch: Colors.orange,
        // Make checkboxes orange when checked:
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.all(Colors.orange),
        ),
        tabBarTheme: const TabBarTheme(
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
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

        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.orange),
          floatingLabelStyle: TextStyle(color: Colors.orange),
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.orange),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => login.LoginPage(),
        '/main': (context) => const MainScreen(), // New main route with navbar
        '/register_page': (context) => RegisterPage(),
      },
    );
  }
}
