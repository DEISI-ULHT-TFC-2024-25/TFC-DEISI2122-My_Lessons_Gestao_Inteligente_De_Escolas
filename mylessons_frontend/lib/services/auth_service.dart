import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

const String _webBaseUrl = 'http://127.0.0.1:8000';
const String _androidBaseUrl = 'http://10.0.2.2:8000';
const String _defaultBaseUrl = 'http://127.0.0.1:8000';

String getApiBaseUrl() {
  if (kIsWeb) {
    return _webBaseUrl;
  } else if (Platform.isAndroid) {
    return _androidBaseUrl;
  } else {
    return _defaultBaseUrl;
  }
}

/// Returns auth headers with the stored token.
Future<Map<String, String>> getAuthHeaders() async {
  final storage = const FlutterSecureStorage();
  String? token = await storage.read(key: 'auth_token');
  if (token == null) {
    throw Exception("No auth token found");
  }
  return {
    'Authorization': 'Token $token',
    'Content-Type': 'application/json',
  };
}

/// Performs email/password login. Returns the decoded JSON response.
Future<Map<String, dynamic>> login(String email, String password) async {
  final baseUrl = getApiBaseUrl();
  final Uri loginUrl = Uri.parse('$baseUrl/api/users/login/');
  final response = await http.post(
    loginUrl,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'username': email,
      'password': password,
    }),
  );
  final data = jsonDecode(response.body);
  if (response.statusCode == 200) {
    if (data.containsKey('token')) {
      // Store the token securely.
      final storage = const FlutterSecureStorage();
      await storage.write(key: 'auth_token', value: data['token']);
      return data;
    } else {
      throw Exception("Unexpected error: Token not received.");
    }
  } else {
    throw Exception(data['error'] ?? 'Invalid credentials.');
  }
}

/// Performs Google Sign-In and sends the idToken to the backend.
/// Returns the decoded JSON response.
Future<Map<String, dynamic>> googleSignInAuth() async {
  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'openid', // Ensure idToken is generated
    ],
  );

  final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
  if (googleUser == null) {
    throw Exception('Google sign-in canceled.');
  }
  final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
  final baseUrl = getApiBaseUrl();
  final response = await http.post(
    Uri.parse('$baseUrl/api/users/google/'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'token': googleAuth.idToken}),
  );
  final data = jsonDecode(response.body);
  if (response.statusCode == 200) {
    // Optionally, store the token if returned.
    return data;
  } else {
    throw Exception(data['error'] ?? 'Error during Google sign-in.');
  }
}
