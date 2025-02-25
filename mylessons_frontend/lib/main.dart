import 'package:flutter/material.dart';
import 'login_success_page.dart';
import 'register_page.dart';
import 'login_page.dart' as login;
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
        '/login_success_page': (context) => const LoginSuccessPage(),
        '/register_page': (context) => RegisterPage(),
      },
    );
  }
}
