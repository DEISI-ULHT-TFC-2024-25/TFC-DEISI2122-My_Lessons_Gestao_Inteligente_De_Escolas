import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
const String baseUrl = 'https://mylessons.pythonanywhere.com'; // hosting
//const String baseUrl = 'http://127.0.0.1:8000'; // localhost
//const String baseUrl = 'http://192.168.1.66:8000'; // net da sala
//const String baseUrl = 'http://172.19.72.130:8000'; // freeulusofona
//const String baseUrl = 'http://172.20.10.9:8000'; // hotspot


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

Future<String> fetchCurrentRole() async {
  final headers = await getAuthHeaders();
  final url = '$baseUrl/api/users/current_role/';
  final response = await http.get(Uri.parse(url), headers: headers);

  if (response.statusCode == 200) {
    final data = json.decode(utf8.decode(response.bodyBytes));
    return data['current_role'] as String;
  } else {
    throw Exception('Failed to fetch current role: ${response.statusCode}');
  }
}

/// Performs email/password login. Returns the decoded JSON response.
Future<Map<String, dynamic>> login(String email, String password) async {
  final Uri loginUrl = Uri.parse('$baseUrl/api/users/login/');
  final response = await http.post(
    loginUrl,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
    body: jsonEncode({
      'username': email,
      'password': password,
    }),
  );
  final data = json.decode(utf8.decode(response.bodyBytes));
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
  final response = await http.post(
    Uri.parse('$baseUrl/api/users/google/'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'token': googleAuth.idToken}),
  );
  final data = json.decode(utf8.decode(response.bodyBytes));
  if (response.statusCode == 200) {
    // Optionally, store the token if returned.
    return data;
  } else {
    throw Exception(data['error'] ?? 'Error during Google sign-in.');
  }
}

Future<List<Map<String, dynamic>>> fetchSchools() async {
  final url = Uri.parse('$baseUrl/api/schools/all_schools/');
  final headers = await getAuthHeaders();
  final response = await http.get(url, headers: headers);
  if (response.statusCode == 200) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
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
        'isFavorite': jsonSchool['isFavorite'],
        'lastPurchases': [],
        'services': jsonSchool['services'] ?? []
      };
    }).toList();
  } else {
    throw Exception('Failed to load schools');
  }
}

Future<Map<String, dynamic>?> fetchLessonDetails(int lessonId) async {
  final headers = await getAuthHeaders();
  final response = await http.get(
    Uri.parse('$baseUrl/api/lessons/lesson_details/$lessonId/'),
    headers: headers,
  );
  if (response.statusCode == 200) {
    return jsonDecode(utf8.decode(response.bodyBytes));
  } else {
    return null;
  }
}

Future<Map<String, dynamic>?> fetchPackDetails(int packId) async {
  final headers = await getAuthHeaders();
  final response = await http.get(
    Uri.parse('$baseUrl/api/lessons/pack_details/$packId/'),
    headers: headers,
  );
  if (response.statusCode == 200) {
    return jsonDecode(utf8.decode(response.bodyBytes));
  } else {
    return null;
  }
}

Future<List<String>> fetchAvailableTimes(
    int lessonId, DateTime date, int increment) async {
  final headers = await getAuthHeaders();
  final response = await http.post(
    Uri.parse('$baseUrl/api/lessons/available_lesson_times/'),
    headers: headers,
    body: jsonEncode({
      "lesson_id": lessonId,
      "date": DateFormat('yyyy-MM-dd').format(date),
      "increment": increment,
    }),
  );
  if (response.statusCode == 200) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return List<String>.from(data['available_times']);
  } else {
    return [];
  }
}

Future<bool> canStillReschedule(int lessonId) async {
  final headers = await getAuthHeaders();
  final response = await http.get(
    Uri.parse('$baseUrl/api/lessons/can_still_reschedule/$lessonId/'),
    headers: headers,
  );
  if (response.statusCode == 200) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data;
  } else {
    return false;
  }
}

Future<String?> schedulePrivateLesson(
    int lessonId, DateTime newDate, String newTime) async {
  final headers = await getAuthHeaders();
  final newDateStr = DateFormat('yyyy-MM-dd').format(newDate);
  final payload = {
    "lesson_id": lessonId,
    "new_date": newDateStr,
    "new_time": newTime,
  };

  final response = await http.post(
    Uri.parse('$baseUrl/api/lessons/schedule_private_lesson/'),
    headers: headers,
    body: jsonEncode(payload),
  );

  print("Response Status: ${response.statusCode}");
  print("Response Body: ${response.body}");

  if (response.statusCode == 200) {
    return null; // Success, no error message
  } else {
    final data = json.decode(utf8.decode(response.bodyBytes));
    return data['error'] ?? "Failed to schedule lesson";
  }
}

Future<void> markNotificationsAsRead(List<int> notificationIds) async {
  if (notificationIds.isEmpty) return;
  final headers = await getAuthHeaders();
  final response = await http.post(
    Uri.parse('$baseUrl/api/notifications/read/'),
    headers: headers,
    body: jsonEncode({"notifications_ids": notificationIds}),
  );
  if (response.statusCode != 200) {
    print("Error marking notifications as read: ${response.body}");
  }
}

/// Fetches the school's scheduling time limit (in hours) from the API.
/// Expects the API to return JSON with a "time_limit" key (e.g., 24).
Future<int> fetchSchoolScheduleTimeLimit(schoolName) async {
  final url = Uri.parse('$baseUrl/api/schools/get_school_time_limit/');
  final response = await http.post(
    url,
    headers: await getAuthHeaders(),
    body: jsonEncode({"school_name": schoolName}),
  );
  if (response.statusCode == 200) {
    final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
    return data['time_limit'] as int;
  } else {
    // If an error occurs, default to 0 hours.
    return 0;
  }
}
