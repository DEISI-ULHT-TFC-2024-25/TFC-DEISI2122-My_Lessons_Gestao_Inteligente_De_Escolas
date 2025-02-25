import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform; // Import for platform detection
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final storage = FlutterSecureStorage();

  bool _isLoading = false;
  String? _errorMessage;

  // Dynamic API base URL
  String get _apiBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000'; // Web environment
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000'; // Android Emulator
    } else {
      return 'http://127.0.0.1:8000'; // Default (iOS)
    }
  }

  

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, insere o e-mail/username e a palavra-passe.';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final Uri loginUrl = Uri.parse('$_apiBaseUrl/api/users/login/');

      final response = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data.containsKey('token')) {
          String token = data['token'];

          // Store the token securely
          await storage.write(key: 'auth_token', value: token);
          print("Token stored successfully: $token"); // Debugging

          // Navigate to Home Page
          Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);

        } else {
          print("Login response does not contain a token");
          setState(() {
            _errorMessage = "Erro inesperado: Token não recebido.";
          });
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _errorMessage = data['error'] ?? 'Credenciais inválidas.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro de rede ou servidor: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Google Sign-In Logic
  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'profile',
          'openid',  // Importante para garantir que o idToken é gerado
        ],
      );


      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        setState(() {
          _errorMessage = 'Início de sessão com Google cancelado.';
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      print('ID Token: ${googleAuth.idToken}');  // Verifica se o token aparece no console

      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/users/google/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': googleAuth.idToken}),  // Envio do token
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Login com Google bem-sucedido: $data');

        // You can navigate to another page or store the token here
        // Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);

      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _errorMessage = data['error'] ?? 'Erro ao iniciar sessão com Google.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro durante o login com Google: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // Constrain width so it looks nice on large screens
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Text(
                    'Iniciar sessão no MyLessons',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // "Continuar com Google" button
                  ElevatedButton.icon(
                  icon: SvgPicture.string(
                    '''
                    <svg width="25" height="24" viewBox="0 0 25 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path fill-rule="evenodd" clip-rule="evenodd" d="M22.1 12.2272C22.1 11.5182 22.0364 10.8363 21.9182 10.1818H12.5V14.05H17.8818C17.65 15.3 16.9455 16.3591 15.8864 17.0682V19.5772H19.1182C21.0091 17.8363 22.1 15.2727 22.1 12.2272Z" fill="#4285F4"/>
                      <path fill-rule="evenodd" clip-rule="evenodd" d="M12.4998 21.9999C15.1998 21.9999 17.4635 21.1045 19.118 19.5772L15.8862 17.0681C14.9907 17.6681 13.8453 18.0227 12.4998 18.0227C9.89529 18.0227 7.69075 16.2636 6.90439 13.8999H3.56348V16.4908C5.20893 19.759 8.59075 21.9999 12.4998 21.9999Z" fill="#34A853"/>
                      <path fill-rule="evenodd" clip-rule="evenodd" d="M6.90455 13.9C6.70455 13.3 6.59091 12.6591 6.59091 12C6.59091 11.3409 6.70455 10.7 6.90455 10.1V7.50909H3.56364C2.88636 8.85909 2.5 10.3864 2.5 12C2.5 13.6136 2.88636 15.1409 3.56364 16.4909L6.90455 13.9Z" fill="#FBBC05"/>
                      <path fill-rule="evenodd" clip-rule="evenodd" d="M12.4998 5.97727C13.968 5.97727 15.2862 6.48182 16.3226 7.47273L19.1907 4.60455C17.4589 2.99091 15.1953 2 12.4998 2C8.59075 2 5.20893 4.24091 3.56348 7.50909L6.90439 10.1C7.69075 7.73636 9.89529 5.97727 12.4998 5.97727Z" fill="#EA4335"/>
                    </svg>
                    ''',
                    width: 24,
                    height: 24,
                  ),
                  label: const Text('Continuar com Google'),
                  onPressed: _handleGoogleSignIn,
                ),
                const SizedBox(height: 16),

                  // "ou" separator
                  Row(
                    children: const [
                      Expanded(child: Divider(thickness: 1)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('ou'),
                      ),
                      Expanded(child: Divider(thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Email TextField
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail ou nome de utilizador',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password TextField
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Palavra-passe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error message
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Login button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Iniciar sessão'),
                  ),
                  const SizedBox(height: 16),

                  // Forgot password link
                  TextButton(
                    onPressed: () {
                      // Navigate to a "forgot password" page or show a dialog
                    },
                    child: const Text('Esqueceste-te da tua palavra-passe?'),
                  ),
                  const SizedBox(height: 16),

                  // Register link
                  GestureDetector(
                    onTap: () {
                      // Go to a registration page
                      
                      Navigator.pushReplacementNamed(context, '/register_page');
                    },
                    child: const Text(
                      'Não tens conta? Regista-te no MyLessons',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),


                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}