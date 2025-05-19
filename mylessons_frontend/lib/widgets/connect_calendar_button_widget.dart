// lib/widgets/connect_calendar_button.dart

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:mylessons_frontend/services/api_service.dart';

// Replace with your actual OAuth client ID
const String _googleClientId = '768650226651-hn51uf6gvp12tn96b683me6epae9abju.apps.googleusercontent.com';

class ConnectCalendarButton extends StatefulWidget {
  const ConnectCalendarButton({Key? key}) : super(key: key);

  @override
  _ConnectCalendarButtonState createState() => _ConnectCalendarButtonState();
}

class _ConnectCalendarButtonState extends State<ConnectCalendarButton> {
  bool _isConnecting = false;
  late final GoogleSignIn _googleSignIn;

  @override
  void initState() {
    super.initState();

    // On Web: use clientId
    // On Android/iOS: use serverClientId so we get a serverAuthCode
    if (kIsWeb) {
      _googleSignIn = GoogleSignIn(
        clientId: _googleClientId,
        scopes: <String>[
          'email',
          'https://www.googleapis.com/auth/calendar.events',
        ],
      );
    } else {
      _googleSignIn = GoogleSignIn(
        scopes: <String>[
          'email',
          'https://www.googleapis.com/auth/calendar.events',
        ],
        serverClientId: _googleClientId,
      );
    }
  }

  Future<void> _connectCalendar() async {
    setState(() => _isConnecting = true);

    try {
      // 1️⃣ Kick off the Google sign-in / consent flow
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // user cancelled
        return;
      }

      // 2️⃣ Grab the serverAuthCode directly from the account
      final serverAuthCode = googleUser.serverAuthCode;
      if (serverAuthCode == null) {
        throw Exception(
          'Missing serverAuthCode; check that your client ID is correct and authorized for this origin',
        );
      }

      // 3️⃣ Get the Firebase ID token so your backend can verify identity
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw Exception('Not signed in with Firebase');
      }

      // 4️⃣ POST to your Django endpoint
      final resp = await http.post(
        Uri.parse('$baseUrl/api/users/connect_calendar/'),
        headers: await getAuthHeaders(),
        body: jsonEncode({
          'google_auth_code': serverAuthCode,
        }),
      );

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Google Calendar connected!')),
        );
      } else {
        debugPrint('Backend error (${resp.statusCode}): ${resp.body}');
        throw Exception('Failed to connect calendar');
      }
    } catch (e) {
      debugPrint('Error in connect_calendar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Could not connect Calendar')),
      );
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.calendar_today),
      label: _isConnecting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Connect Calendar'),
      onPressed: _isConnecting ? null : _connectCalendar,
    );
  }
}
