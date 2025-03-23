import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mylessons_frontend/services/api_service.dart';

class RegisterLandingPage extends StatefulWidget {
  const RegisterLandingPage({Key? key}) : super(key: key);

  @override
  State<RegisterLandingPage> createState() => _RegisterLandingPageState();
}

class _RegisterLandingPageState extends State<RegisterLandingPage> {
  bool _isSigningInWithGoogle = false;
  bool _isSigningInWithApple = false;

  // Navigate to the email register screen.
  void _continueWithEmail() {
    Navigator.pushNamed(context, '/register_page');
  }

  // Google sign-in logic using GoogleSignIn & FirebaseAuth.
  Future<void> _signInWithGoogle() async {
    setState(() => _isSigningInWithGoogle = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      // After successful sign in with FirebaseAuth
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      // Send the token to your backend endpoint.
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/firebase_login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'firebase_token': idToken}),
      );
      final data = json.decode(utf8.decode(response.bodyBytes));
      // Check if the response status code is 200 before navigating.
      if (response.statusCode == 200) {
        if (data.containsKey('token')) {
          // Store the token securely.
          final storage = const FlutterSecureStorage();
          await storage.write(key: 'auth_token', value: data['token']);
          Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
        } else {
          throw Exception("Unexpected error: Token not received.");
        }
      } else {
        debugPrint('Backend error: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging in. Please try again.')),
        );
      }
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing in with Google.')),
      );
    } finally {
      setState(() => _isSigningInWithGoogle = false);
    }
  }

  // Apple sign-in logic using SignInWithApple & FirebaseAuth.
  Future<void> _signInWithApple() async {
    setState(() => _isSigningInWithApple = true);
    try {
      // 1. Request Apple credentials.
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // 2. Convert the Apple credential to a Firebase OAuth credential.
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // 3. Sign in with Firebase.
      await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      // 4. Get the current Firebase user and their ID token.
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      // 5. Send the ID token to your backend.
      if (idToken != null) {
        final response = await http.post(
          Uri.parse('$baseUrl/api/users/firebase_login/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'firebase_token': idToken}),
        );

        final data = json.decode(utf8.decode(response.bodyBytes));

        if (response.statusCode == 200) {
          if (data.containsKey('token')) {
            // Store the token securely.
            const storage = FlutterSecureStorage();
            await storage.write(key: 'auth_token', value: data['token']);
            Navigator.pushNamedAndRemoveUntil(
                context, '/main', (route) => false);
          } else {
            throw Exception("Unexpected error: Token not received.");
          }
        } else {
          debugPrint('Backend error: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error logging in. Please try again.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error signing in with Apple: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error signing in with Apple.')),
      );
    } finally {
      setState(() => _isSigningInWithApple = false);
    }
  }

  // Extracted widget for the buttons area.
  Widget _buildButtonsArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Continue with Email.
        ElevatedButton.icon(
          icon: const Icon(Icons.email, color: Colors.white),
          label: const Text(
            'Continue with Email',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            minimumSize: const Size(double.infinity, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
          ),
          onPressed: _continueWithEmail,
        ),
        const SizedBox(height: 16),
        // Continue with Google.
        OutlinedButton.icon(
          icon: _isSigningInWithGoogle
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.orange,
                  ),
                )
              : SvgPicture.string(
                  '''
<svg width="25" height="24" viewBox="0 0 25 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path fill-rule="evenodd" clip-rule="evenodd" d="M22.1 12.2272C22.1 11.5182 22.0364 10.8363 21.9182 10.1818H12.5V14.05H17.8818C17.65 15.3 16.9455 16.3591 15.8864 17.0682V19.5772H19.1182C21.0091 17.8363 22.1 15.2727 22.1 12.2272Z" fill="#4285F4"/>
  <path fill-rule="evenodd" clip-rule="evenodd" d="M12.4998 21.9999C15.1998 21.9999 17.4635 21.1045 19.118 19.5772L15.8862 17.0681C14.9907 17.6681 13.8453 18.0227 12.4998 18.0227C9.89529 18.0227 7.69075 16.2636 6.90439 13.8999H3.56348V16.4908C5.20893 19.759 8.59075 21.9999 12.4998 21.9999Z" fill="#34A853"/>
  <path fill-rule="evenodd" clip-rule="evenodd" d="M6.90455 13.9C6.70455 13.3 6.59091 12.6591 6.59091 12C6.59091 11.3409 6.70455 10.7 6.90455 10.1V7.50909H3.56364C2.88636 8.85909 2.5 10.3864 2.5 12C2.5 13.6136 2.88636 15.1409 3.56364 16.4909L6.90455 13.9Z" fill="#FBBC05"/>
  <path fill-rule="evenodd" clip-rule="evenodd" d="M12.4998 5.97727C13.968 5.97727 15.2862 6.48182 16.3226 7.47273L19.1907 4.60455C17.4589 2.99091 15.1953 2 12.4998 2C8.59075 2 5.20893 4.24091 3.56348 7.50909L6.90439 10.1C7.69075 7.73636 9.89529 5.97727 12.4998 5.97727Z" fill="#EA4335"/>
</svg>
                  ''',
                  width: 25,
                  height: 24,
                ),
          label: const Text(
            'Continue with Google',
            style: TextStyle(fontSize: 18),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 45),
            side: const BorderSide(color: Colors.orange),
            foregroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
          ),
          onPressed: _isSigningInWithGoogle ? null : _signInWithGoogle,
        ),
        const SizedBox(height: 16),
        // Continue with Apple.
        OutlinedButton.icon(
          icon: _isSigningInWithApple
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.orange,
                  ),
                )
              : const FaIcon(
                  FontAwesomeIcons.apple,
                  color: Colors.black,
                ),
          label: const Text(
            'Continue with Apple',
            style: TextStyle(fontSize: 18),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 45),
            side: const BorderSide(color: Colors.orange),
            foregroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
          ),
          onPressed: _isSigningInWithApple ? null : _signInWithApple,
        ),
        const SizedBox(height: 32),
        // Bottom text.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Already have an account?",
              style: TextStyle(color: Colors.black),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/login');
              },
              child: const Text(
                'Log In',
                style: TextStyle(
                  color: Colors.orange,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    // Portrait layout.
    Widget portraitContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  children: [
                    TextSpan(text: 'Sign Up\n'),
                    TextSpan(
                      text: 'For Free!',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 60),
          _buildButtonsArea(),
        ],
      ),
    );

    // Landscape layout.
    Widget landscapeContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  children: [
                    TextSpan(text: 'Sign Up\n'),
                    TextSpan(
                      text: 'For Free!',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildButtonsArea(),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isPortrait ? portraitContent : landscapeContent,
      ),
    );
  }
}
