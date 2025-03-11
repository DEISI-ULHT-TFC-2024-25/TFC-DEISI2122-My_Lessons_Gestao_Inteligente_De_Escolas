import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // Exports getAuthHeaders() and baseUrl

class SubjectModal extends StatefulWidget {
  final int lessonId;
  const SubjectModal({super.key, required this.lessonId});

  @override
  _SubjectModalState createState() => _SubjectModalState();
}

class _SubjectModalState extends State<SubjectModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> subjects = [];
  bool isLoading = false;
  String searchQuery = "";
  final TextEditingController _newSubjectController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchSubjects();
  }

  Future<void> fetchSubjects() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/schools/subjects/"),
        headers: await getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        // Sort alphabetically by subject name.
        data.sort((a, b) => a["name"]
            .toString()
            .toLowerCase()
            .compareTo(b["name"].toString().toLowerCase()));
        setState(() {
          subjects = data;
        });
      }
    } catch (e) {
      print("Error fetching subjects: $e");
    }
    setState(() {
      isLoading = false;
    });
  }

  void _selectSubject(dynamic subject) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Selection"),
          content: Text("Do you want to select subject: ${subject["name"]}?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel")),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Confirm")),
          ],
        );
      },
    );
    if (confirmed == true) {
      final url = "$baseUrl/api/lessons/edit_lesson_subject/";
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: await getAuthHeaders(),
          body: jsonEncode({
            "lesson_id": widget.lessonId,
            "subject_id": subject["id"],
            "action": "change",
          }),
        );
        if (response.statusCode == 200) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error updating subject: ${utf8.decode(response.bodyBytes)}"),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _createSubject() async {
    if (_newSubjectController.text.trim().isEmpty) return;
    // Show confirmation dialog before creating.
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Creation"),
          content: Text("Do you want to create subject: ${_newSubjectController.text.trim()}?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final url = "$baseUrl/api/lessons/edit_lesson_subject/";
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: await getAuthHeaders(),
        body: jsonEncode({
          "lesson_id": widget.lessonId,
          // For creating, we pass the new subject name as subject_id.
          "subject_id": _newSubjectController.text.trim(),
          "action": "add",
        }),
      );
      if (response.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error creating subject: ${utf8.decode(response.bodyBytes)}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Wrap content height
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modal Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Select or Create Subject",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // TabBar
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            indicatorColor: Colors.orange,
            tabs: const [
              Tab(text: "Select Existing"),
              Tab(text: "Create New"),
            ],
          ),
          const SizedBox(height: 8),
          // Tab Content
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Select Existing
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: "Search Subject",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                              children: subjects.where((subject) {
                                return subject["name"]
                                    .toString()
                                    .toLowerCase()
                                    .contains(searchQuery);
                              }).map((subject) {
                                return ListTile(
                                  title: Text(subject["name"]),
                                  trailing: const Icon(Icons.arrow_forward, color: Colors.orange),
                                  onTap: () => _selectSubject(subject),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
                // Tab 2: Create New
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _newSubjectController,
                        decoration: const InputDecoration(
                          labelText: "New Subject Name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _createSubject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Create Subject"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
