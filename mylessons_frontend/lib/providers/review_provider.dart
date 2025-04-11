// review_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // This should provide your `baseUrl` and a getAuthHeaders() function

class ReviewProvider extends ChangeNotifier {
  /// Submits a review using the provided rating and description.
  Future<bool> submitReview({
    required double rating,
    String? description,
  }) async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/schools/add_review'); // The endpoint we’ll create on the backend.
    final body = jsonEncode({
      'rating': rating,
      'description': description ?? '',
    });
    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 201) {
      // Optionally update any local state or list of reviews.
      notifyListeners();
      return true;
    } else {
      debugPrint('Failed to submit review: ${response.statusCode}');
      return false;
    }
  }
}
