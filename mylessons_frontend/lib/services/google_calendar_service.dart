// lib/services/google_calendar_service.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GoogleCalendarService {
  /// Your Web client ID (to exchange code on backend)
  static const _webClientId = 
    '768650226651-hn51uf6gvp12tn96b683me6epae9abju.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/calendar'],
    // ON WEB, use clientId; ON MOBILE only use serverClientId
    clientId: kIsWeb ? _webClientId : null,
    serverClientId: kIsWeb ? null : _webClientId,
  );

  Future<String?> getServerAuthCode() async {
    final account = await _googleSignIn.signIn();
    return account?.serverAuthCode;
  }
  
  /// Optional: sign the user out if needed
  Future<void> signOut() async {
    await _googleSignIn.disconnect();
  }
}
