import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class StaffProvider extends ChangeNotifier {
  Map<String, dynamic>? foundUser;
  bool isAdmin = false;
  bool isInstructor = false;
  bool isMonitor = false;
  bool isLoading = false;

  /// Searches for a user by email.
  Future<void> searchUser(String email) async {
    if (email.isEmpty) return;
    isLoading = true;
    notifyListeners();

    final url = "$baseUrl/api/schools/check_user/";
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: await getAuthHeaders(),
        body: jsonEncode({"email": email}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data["success"] == true) {
          foundUser = {
            "email": data["email"],
            "first_name": data["first_name"],
            "last_name": data["last_name"],
          };
        } else {
          foundUser = null;
        }
      } else {
        foundUser = null;
      }
    } catch (e) {
      print("Error searching user: $e");
      foundUser = null;
    }

    isLoading = false;
    notifyListeners();
  }

  /// Adds the found user as staff.
  Future<bool> addStaff() async {
    List<String> roles = [];
    if (isAdmin) roles.add('Admin');
    if (isInstructor) roles.add('Instructor');
    if (isMonitor) roles.add('Monitor');

    final url = "$baseUrl/api/schools/add_staff/";
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: await getAuthHeaders(),
        body: jsonEncode({
          "email": foundUser?["email"],
          "roles": roles,
        }),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        print("Error adding staff: ${utf8.decode(response.bodyBytes)}");
        return false;
      }
    } catch (e) {
      print("Error adding staff: $e");
      return false;
    }
  }
}
