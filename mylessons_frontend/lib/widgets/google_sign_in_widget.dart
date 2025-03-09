import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({Key? key}) : super(key: key);

  @override
  _GoogleSignInButtonState createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isSigningIn = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isSigningIn = true);

    try {
      // 1. Trigger the Google Sign-In flow.
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // If user cancels, exit.
      if (googleUser == null) {
        setState(() => _isSigningIn = false);
        return;
      }

      // 2. Obtain the auth details from the request.
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Create a new credential for Firebase.
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase.
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // 5. Send tokens to your Django backend.
      await _sendCredentialsToBackend(
        googleAuth.idToken,
        googleAuth.accessToken,
      );

      // Optional: Navigate to your main app screen, show a message, etc.
      final user = userCredential.user;
      if (user != null) {
        print('Signed in as: ${user.displayName}, ${user.email}');
      }
    } catch (e) {
      print('Error during Google sign-in: $e');
    } finally {
      setState(() => _isSigningIn = false);
    }
  }

  Future<void> _sendCredentialsToBackend(String? idToken, String? accessToken) async {
    if (idToken == null || accessToken == null) return;

    // Use your Django endpoint here.
    final url = Uri.parse('http://192.168.1.66:8000/api/users/store_google_credentials/');
    final payload = {
      'idToken': idToken,
      'accessToken': accessToken,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('Credentials stored successfully on Django backend.');
      } else {
        print('Failed to store credentials. Status code: ${response.statusCode}');
      }
    } catch (error) {
      print('Error sending credentials to backend: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isSigningIn
        ? const CircularProgressIndicator()
        : ElevatedButton(
            onPressed: _signInWithGoogle,
            child: const Text('Sign in with Google'),
          );
  }
}
