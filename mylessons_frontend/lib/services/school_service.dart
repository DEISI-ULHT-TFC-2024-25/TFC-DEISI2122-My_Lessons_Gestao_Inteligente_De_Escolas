import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

Future<Map<String, dynamic>> fetchSchoolDetails() async {
  final url = Uri.parse('$baseUrl/api/schools/details/');
  final headers = await getAuthHeaders();
  final response = await http.get(url, headers: headers);
  if (response.statusCode == 200) return jsonDecode(response.body);
  throw Exception('Failed to fetch school details');
}

Future<void> createSchool(String schoolName) async {
  final url = Uri.parse('$baseUrl/api/schools/create/');
  final headers = await getAuthHeaders();
  final payload = jsonEncode({'school_name': schoolName});
  final response = await http.post(url, headers: headers, body: payload);
  if (response.statusCode != 201) {
    final data = jsonDecode(response.body);
    throw Exception(data['error'] ?? 'Error creating school');
  }
}
