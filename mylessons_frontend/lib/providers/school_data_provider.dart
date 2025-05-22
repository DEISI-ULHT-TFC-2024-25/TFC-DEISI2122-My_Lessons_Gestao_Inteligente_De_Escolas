import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/school_service.dart';
import 'package:path/path.dart' as path;  // for filename

/// Provides the full school details as fetched from the API, and exposes
/// nested lists for locations, subjects, and equipments.
class SchoolDataProvider extends ChangeNotifier {
  Map<String, dynamic>? _schoolDetails;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get schoolDetails => _schoolDetails;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<dynamic> get locations =>
      _schoolDetails?['locations'] as List<dynamic>? ?? [];

  List<dynamic> get subjects =>
      _schoolDetails?['subjects'] as List<dynamic>? ?? [];

  List<dynamic> get equipments =>
      _schoolDetails?['equipment'] as List<dynamic>? ?? [];

  /// Fetches and stores the entire school details.
  Future<void> loadSchoolDetails() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await fetchSchoolDetails();
      _schoolDetails = data;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createSchool(
  String schoolName, {
  File? imageFile,
}) async {
  final uri = Uri.parse('$baseUrl/api/schools/create/');
  final headers = await getAuthHeaders();

  if (imageFile != null) {
    // Use multipart request when there's an image
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields['school_name'] = schoolName
      ..files.add(
        await http.MultipartFile.fromPath(
          'image', 
          imageFile.path,
          filename: path.basename(imageFile.path),
        ),
      );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 201) {
      final decoded = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decoded);
      throw Exception(data['error'] ?? 'Error creating school');
    }
  } else {
    // Fallback to JSON payload if no image
    final payload = jsonEncode({'school_name': schoolName});
    final response = await http.post(uri, headers: headers, body: payload);

    if (response.statusCode != 201) {
      final decoded = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decoded);
      throw Exception(data['error'] ?? 'Error creating school');
    }
  }
}

  /// Convenience for refreshing equipments only.
  Future<void> refreshEquipments() async {
    if (_schoolDetails == null) return;
    await loadSchoolDetails();
  }
}
