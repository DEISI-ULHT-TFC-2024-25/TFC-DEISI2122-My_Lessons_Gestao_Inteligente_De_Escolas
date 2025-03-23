import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mylessons_frontend/services/api_service.dart';

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
  final Uri registerUrl = Uri.parse("$baseUrl/api/users/register/");

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

Future<bool> isUsernameAvailable(String username) async {
  final url = Uri.parse('$baseUrl/api/users/check_username/?username=$username');
  final response = await http.get(url, headers: {"Content-Type": "application/json"});
  if (response.statusCode == 200) {
    final data = json.decode(utf8.decode(response.bodyBytes));
    return data['available'] as bool;
  } else {
    throw Exception("Failed to check username availability");
  }
}