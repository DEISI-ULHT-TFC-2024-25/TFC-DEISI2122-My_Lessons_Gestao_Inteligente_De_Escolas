import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Returns the appropriate API base URL based on the current platform.
String getApiBaseUrl() {
  if (kIsWeb) {
    return "http://127.0.0.1:8000"; // Web environment (localhost)
  } else if (Platform.isAndroid) {
    return "http://10.0.2.2:8000"; // Android emulator
  } else {
    return "http://127.0.0.1:8000"; // Default (iOS or others)
  }
}

/// Calls the registration endpoint with the provided user details.
/// Returns the http.Response so that the calling code can handle success or errors.
Future<http.Response> registerUser({
  required String email,
  required String password,
  required String firstName,
  required String lastName,
  required String phone,
  String countryCode = "+351",
}) async {
  final String apiBaseUrl = getApiBaseUrl();
  final Uri registerUrl = Uri.parse("$apiBaseUrl/api/users/register/");

  final response = await http.post(
    registerUrl,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "email": email.trim(),
      "password": password,
      "first_name": firstName.trim(),
      "last_name": lastName.trim(),
      "country_code": countryCode,
      "phone": phone.trim(),
    }),
  );
  return response;
}
