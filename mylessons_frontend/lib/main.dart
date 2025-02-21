import 'package:flutter/material.dart';
import 'login_success_page.dart';
import 'register_page.dart';
import 'home.dart' as home;
import 'login_page.dart' as login;

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
        '/home': (context) => home.HomePage(),
        '/login_success_page': (context) => const LoginSuccessPage(),
        '/register_page': (context) => RegisterPage(),
      },
    );
  }
}
