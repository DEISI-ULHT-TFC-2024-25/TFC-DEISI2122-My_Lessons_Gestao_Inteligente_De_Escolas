import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class InstructorsModal extends StatefulWidget {
  final int? lessonId;
  final int? packId;
  final int? schoolId; // optional for full payload support

  const InstructorsModal({Key? key, this.lessonId, this.packId, this.schoolId})
      : super(key: key);

  @override
  _InstructorsModalState createState() => _InstructorsModalState();
}

class _InstructorsModalState extends State<InstructorsModal> {
  List<dynamic> instructors = [];
  bool isLoading = false;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    fetchInstructors();
  }

  Future<void> fetchInstructors() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Build the POST body using any available IDs.
      Map<String, dynamic> body = {};
      if (widget.lessonId != null) body["lesson_id"] = widget.lessonId;
      if (widget.packId != null) body["pack_id"] = widget.packId;
      if (widget.schoolId != null) body["school_id"] = widget.schoolId;

      final response = await http.post(
        Uri.parse("$baseUrl/api/users/get_selected_instructors/"),
        headers: await getAuthHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        // Expecting two lists: "associated_instructors" and "all_instructors"
        final List<dynamic> allInstructors = data["all_instructors"] ?? [];
        final List<dynamic> associatedInstructors = data["associated_instructors"] ?? [];

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

        setState(() {
          instructors = mergedInstructors;
        });
      }
    } catch (e) {
      print("Error fetching instructors: $e");
    }
    setState(() {
      isLoading = false;
    });
  }

  void _toggleInstructorSelection(dynamic instructor) async {
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
      // Use the provided endpoint.
      final url = "$baseUrl/api/lessons/edit_instructors/";
      Map<String, dynamic> payload = {
        "instructor_id": instructor["id"],
        "action": action,
      };
      if (widget.lessonId != null) {
        payload["lesson_id"] = widget.lessonId;
      } else if (widget.packId != null) {
        payload["pack_id"] = widget.packId;
      }
      if (widget.schoolId != null) {
        payload["school_id"] = widget.schoolId;
      }

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: await getAuthHeaders(),
          body: jsonEncode(payload),
        );
        if (response.statusCode == 200) {
          setState(() {
            instructor["selected"] = !isSelected;
            instructors.sort((a, b) {
              String nameA = (a["name"] ?? "").toString().toLowerCase();
              String nameB = (b["name"] ?? "").toString().toLowerCase();
              if (a["selected"] == b["selected"]) {
                return nameA.compareTo(nameB);
              }
              return a["selected"] ? -1 : 1;
            });
          });
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Error updating instructor: ${utf8.decode(response.bodyBytes)}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter instructors based on the search query.
    List<dynamic> filteredInstructors = instructors.where((instructor) {
      String name = (instructor["name"] ?? "").toString().toLowerCase();
      return name.contains(searchQuery);
    }).toList();

    // Calculate modal height as 2/3 of the screen.
    final modalHeight = MediaQuery.of(context).size.height * 2 / 3;

    return Container(
      height: modalHeight,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap content height.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Select Instructor",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Search Bar.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextField(
                decoration: InputDecoration(
                  labelText: "Search Instructor",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            // List of Instructors.
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: filteredInstructors.map((instructor) {
                        String fullName = instructor["name"] ?? "";
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: ListTile(
                            title: Text(fullName),
                            trailing: instructor["selected"] == true
                                ? const Icon(Icons.check_circle, color: Colors.orange)
                                : const Icon(Icons.arrow_forward, color: Colors.orange),
                            onTap: () => _toggleInstructorSelection(instructor),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
