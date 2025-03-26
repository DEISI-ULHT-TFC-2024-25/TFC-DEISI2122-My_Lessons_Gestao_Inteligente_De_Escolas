import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

/// The main widget to display the Add Staff modal as a bottom sheet.
class AddStaffModal extends StatefulWidget {
  const AddStaffModal({super.key});

  @override
  _AddStaffModalState createState() => _AddStaffModalState();
}

class _AddStaffModalState extends State<AddStaffModal> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? foundUser;

  // Checkbox states for each role.
  bool isAdmin = false;
  bool isInstructor = false;
  bool isMonitor = false;

  /// Searches for a user by email via your Django REST API.
  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final url = "$baseUrl/api/schools/check_user/";
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: await getAuthHeaders(),
        body: jsonEncode({"email": query}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data["success"] == true) {
          setState(() {
            foundUser = {
              "email": data["email"],
              "first_name": data["first_name"],
              "last_name": data["last_name"],
            };
          });
        } else {
          setState(() {
            foundUser = null;
          });
        }
      } else {
        setState(() {
          foundUser = null;
        });
      }
    } catch (e) {
      print("Error searching user: $e");
      setState(() {
        foundUser = null;
      });
    }
  }

  /// Adds the found user as staff using the Django REST API.
  /// On success, the modal is closed and returns true.
  Future<void> _addStaff() async {
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
        print("Staff added successfully");
        Navigator.pop(context, true);
      } else {
        print("Error adding staff: ${utf8.decode(response.bodyBytes)}");
      }
    } catch (e) {
      print("Error adding staff: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Note: The outer widget (in showAddStaffModal) adds keyboard padding,
    // so here we use fixed padding.
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wraps content height
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row with a back arrow and a title.
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Add Staff Member",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search bar to enter an email.
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Search by email",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.orange),
                  onPressed: _searchUser,
                ),
              ),
              onSubmitted: (value) => _searchUser(),
            ),
            const SizedBox(height: 24),

            // Show user details if found.
            if (foundUser != null) ...[
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${foundUser!['email']}"),
                      const SizedBox(height: 8),
                      Text(
                          "${foundUser!['first_name']} ${foundUser!['last_name']}"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Role selection checkboxes.
              CheckboxListTile(
                title: const Text("Admin"),
                value: isAdmin,
                activeColor: Colors.orange,
                onChanged: (bool? value) {
                  setState(() {
                    isAdmin = value ?? false;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text("Instructor"),
                value: isInstructor,
                activeColor: Colors.orange,
                onChanged: (bool? value) {
                  setState(() {
                    isInstructor = value ?? false;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text("Monitor"),
                value: isMonitor,
                activeColor: Colors.orange,
                onChanged: (bool? value) {
                  setState(() {
                    isMonitor = value ?? false;
                  });
                },
              ),
              const SizedBox(height: 24),

              // "Add Staff" button.
              ElevatedButton(
                onPressed: _addStaff,
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: Colors.orange,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                ),
                child: const Text("Add Staff",
                    style: TextStyle(color: Colors.black, fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<dynamic> showAddStaffModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (BuildContext context) {
      // Wrap the draggable sheet in a Padding that uses viewInsets.bottom.
      return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          // The modal will start at 50% of the screen height,
          // can shrink to 30% and expand to a maximum of 90%.
          initialChildSize: 0.9,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The little draggable handle, now in orange.
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const AddStaffModal(),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
