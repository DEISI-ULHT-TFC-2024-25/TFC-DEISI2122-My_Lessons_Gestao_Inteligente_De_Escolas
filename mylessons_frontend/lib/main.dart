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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyLessons App',
      initialRoute: '/',
      routes: {
        '/': (context) => login.LoginPage(),
        '/main': (context) => const MainScreen(), // New main route with navbar
        '/register_page': (context) => RegisterPage(),
      },
    );
  }
}
