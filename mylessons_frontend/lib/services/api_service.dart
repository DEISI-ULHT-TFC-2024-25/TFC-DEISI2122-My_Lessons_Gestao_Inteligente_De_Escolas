import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://127.0.0.1:8000';
final FlutterSecureStorage storage = const FlutterSecureStorage();

Future<Map<String, String>> getAuthHeaders() async {
  String? token = await storage.read(key: 'auth_token');
  if (token == null) {
    throw Exception("No auth token found");
  }
  return {
    'Authorization': 'Token $token',
    'Content-Type': 'application/json',
  };
}

Future<List<Map<String, dynamic>>> fetchSchools() async {
  final url = Uri.parse('$baseUrl/api/schools/all_schools/');
  final headers = await getAuthHeaders();
  final response = await http.get(url, headers: headers);
  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);
    return data.map<Map<String, dynamic>>((jsonSchool) {
      return {
        'name': (jsonSchool['school_name'] ?? '').toString(),
        'image': 'https://via.placeholder.com/150',
        'description': '',
        'rating': 0.0,
        'sports': (jsonSchool['list_of_activities'] as List<dynamic>?)
                ?.map((act) => act['name'].toString())
                .toList() ??
            [],
        'locations': (jsonSchool['list_of_locations'] as List<dynamic>?)
                ?.map((loc) => loc['name'].toString())
                .toList() ??
            [],
        'isFavorite': false,
        'lastPurchases': [],
        'services': jsonSchool['services'] ?? []
      };
    }).toList();
  } else {
    throw Exception('Failed to load schools');
  }
}

