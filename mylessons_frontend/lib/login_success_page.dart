import 'package:flutter/material.dart';

class LoginSuccessPage extends StatelessWidget {
  const LoginSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Bem-Sucedido')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Bem-vindo ao MyLessons!'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/');
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
