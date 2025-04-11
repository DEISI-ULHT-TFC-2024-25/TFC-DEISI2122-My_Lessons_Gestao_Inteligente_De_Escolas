import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class InstructorsProvider extends ChangeNotifier {
  List<dynamic> instructors = [];
  bool isLoading = false;
  String searchQuery = "";

  final int? lessonId;
  final int? packId;
  final int? schoolId;

  InstructorsProvider({this.lessonId, this.packId, this.schoolId}) {
    fetchInstructors();
  }

  Future<void> fetchInstructors() async {
    isLoading = true;
    notifyListeners();

    try {
      // Build the POST body using any available IDs.
      Map<String, dynamic> body = {};
      if (lessonId != null) body["lesson_id"] = lessonId;
      if (packId != null) body["pack_id"] = packId;
      if (schoolId != null) body["school_id"] = schoolId;

      final response = await http.post(
        Uri.parse("$baseUrl/api/users/get_selected_instructors/"),
        headers: await getAuthHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(response.bodyBytes));
        // Expect two lists: "all_instructors" and "associated_instructors"
        final List<dynamic> allInstructors = data["all_instructors"] ?? [];
        final List<dynamic> associatedInstructors =
            data["associated_instructors"] ?? [];

        // Create a set of associated instructor IDs.
        final Set<dynamic> associatedIds =
            associatedInstructors.map((i) => i["id"]).toSet();

        // For each instructor in allInstructors, add a "selected" key.
        final List<dynamic> mergedInstructors = allInstructors.map((instructor) {
          instructor["selected"] = associatedIds.contains(instructor["id"]);
          return instructor;
        }).toList();

        // Sort: selected instructors come first, then alphabetical by name.
        mergedInstructors.sort((a, b) {
          String nameA = (a["name"] ?? "").toString().toLowerCase();
          String nameB = (b["name"] ?? "").toString().toLowerCase();
          if (a["selected"] == b["selected"]) {
            return nameA.compareTo(nameB);
          }
          return a["selected"] ? -1 : 1;
        });

        instructors = mergedInstructors;
      }
    } catch (e) {
      print("Error fetching instructors: $e");
    }

    isLoading = false;
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    searchQuery = query.toLowerCase();
    notifyListeners();
  }

  List<dynamic> get filteredInstructors {
    if (searchQuery.isEmpty) {
      return instructors;
    } else {
      return instructors.where((instructor) {
        String name = (instructor["name"] ?? "").toString().toLowerCase();
        return name.contains(searchQuery);
      }).toList();
    }
  }

  Future<void> toggleInstructorSelection(dynamic instructor, BuildContext context) async {
    bool isSelected = instructor["selected"] ?? false;
    String action = isSelected ? "remove" : "add";
    String instructorName = instructor["name"] ?? "";
    String confirmMessage = isSelected
        ? "Do you want to remove instructor: $instructorName?"
        : "Do you want to add instructor: $instructorName?";

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isSelected ? "Confirm Removal" : "Confirm Selection"),
        content: Text(confirmMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Confirm")),
        ],
      ),
    );

    if (confirmed == true) {
      final url = "$baseUrl/api/lessons/edit_instructors/";
      Map<String, dynamic> payload = {
        "instructor_id": instructor["id"],
        "action": action,
      };
      if (lessonId != null) {
        payload["lesson_id"] = lessonId;
      } else if (packId != null) {
        payload["pack_id"] = packId;
      }
      if (schoolId != null) {
        payload["school_id"] = schoolId;
      }

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: await getAuthHeaders(),
          body: jsonEncode(payload),
        );
        if (response.statusCode == 200) {
          instructor["selected"] = !isSelected;
          // Sort the list after toggling
          instructors.sort((a, b) {
            String nameA = (a["name"] ?? "").toString().toLowerCase();
            String nameB = (b["name"] ?? "").toString().toLowerCase();
            if (a["selected"] == b["selected"]) {
              return nameA.compareTo(nameB);
            }
            return a["selected"] ? -1 : 1;
          });
          notifyListeners();
          // Optionally close the modal (or you can let the caller decide)
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Error updating instructor: ${utf8.decode(response.bodyBytes)}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }
}
