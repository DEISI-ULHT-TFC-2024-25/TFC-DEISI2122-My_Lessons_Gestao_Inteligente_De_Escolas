import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

Future<void> deleteService(String schoolId, String serviceId) async {
  final url = Uri.parse('$baseUrl/api/schools/$schoolId/services/delete/');
  final payload = {'id': serviceId};
  final headers = await getAuthHeaders();
  final response =
      await http.post(url, headers: headers, body: jsonEncode(payload));
  if (response.statusCode != 200) {
    throw Exception('Failed to delete service: ${response.body}');
  }
}
