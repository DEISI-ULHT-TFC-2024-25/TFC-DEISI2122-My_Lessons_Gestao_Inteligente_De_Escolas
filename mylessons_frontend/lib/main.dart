import 'package:flutter/material.dart';
import 'pages/register_page.dart';
import 'pages/login_page.dart' as login;
import 'main_layout.dart'; // Import MainScreen

void main() {
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
