import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class StudentsModal extends StatefulWidget {
  final int? lessonId;
  final int? packId;
  const StudentsModal({super.key, this.lessonId, this.packId});

  @override
  _StudentsModalState createState() => _StudentsModalState();
}

class _StudentsModalState extends State<StudentsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> students = [];
  bool isLoading = false;
  String searchQuery = "";

  // Controllers for new student creation.
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  // Birthday picker variables.
  DateTime? selectedBirthday;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchStudents();
  }

  Future<void> fetchStudents() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Prepare the POST body with either lesson_id or pack_id.
      Map<String, dynamic> body = {};
      if (widget.lessonId != null) {
        body["lesson_id"] = widget.lessonId;
      } else if (widget.packId != null) {
        body["pack_id"] = widget.packId;
      }

      final response = await http.post(
        Uri.parse("$baseUrl/api/users/get_selected_students/"),
        headers: await getAuthHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(response.bodyBytes));

        final List<dynamic> allStudents = data["all_students"] ?? [];
        final List<dynamic> associatedStudents = data["associated_students"] ?? [];

        // Mark each student as selected if its id appears in associatedStudents.
        final Set<dynamic> associatedIds =
            associatedStudents.map((s) => s["id"]).toSet();

        final List<dynamic> mergedStudents = allStudents.map((student) {
          student["selected"] = associatedIds.contains(student["id"]);
          return student;
        }).toList();

        // Sort the list so that selected students appear first, then alphabetically.
        mergedStudents.sort((a, b) {
          String nameA =
              "${a['first_name'] ?? ''} ${a['last_name'] ?? ''}".trim().toLowerCase();
          String nameB =
              "${b['first_name'] ?? ''} ${b['last_name'] ?? ''}".trim().toLowerCase();
          if (a["selected"] == b["selected"]) {
            return nameA.compareTo(nameB);
          }
          return a["selected"] ? -1 : 1;
        });

        setState(() {
          students = mergedStudents;
        });
      }
    } catch (e) {
      print("Error fetching students: $e");
    }
    setState(() {
      isLoading = false;
    });
  }

  void _toggleStudentSelection(dynamic student) async {
    bool isSelected = student["selected"] ?? false;
    String action = isSelected ? "remove" : "add";
    String studentName =
        "${student['first_name'] ?? ''} ${student['last_name'] ?? ''}".trim();
    String confirmMessage = isSelected
        ? "Do you want to remove student: $studentName?"
        : "Do you want to add student: $studentName?";

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isSelected ? "Confirm Removal" : "Confirm Selection"),
          content: Text(confirmMessage),
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
    if (confirmed == true) {
      final url = "$baseUrl/api/lessons/edit_lesson_students/";
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: await getAuthHeaders(),
          body: jsonEncode({
            "lesson_id": widget.lessonId,
            "student_id": student["id"],
            "action": action,
          }),
        );
        if (response.statusCode == 200) {
          setState(() {
            student["selected"] = !isSelected;
            students.sort((a, b) {
              String nameA =
                  "${a['first_name'] ?? ''} ${a['last_name'] ?? ''}".trim().toLowerCase();
              String nameB =
                  "${b['first_name'] ?? ''} ${b['last_name'] ?? ''}".trim().toLowerCase();
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
                content:
                    Text("Error updating student: ${utf8.decode(response.bodyBytes)}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _showBirthdayPicker() async {
    DateTime initialDate = selectedBirthday ?? DateTime(2000, 1, 1);
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        selectedBirthday = pickedDate;
        _birthdayController.text = _dateFormat.format(pickedDate);
      });
    }
  }

  void _createStudent() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _birthdayController.text.trim().isEmpty) {
      return;
    }

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        String fullName =
            "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";
        return AlertDialog(
          title: const Text("Confirm Creation"),
          content: Text("Do you want to create student: $fullName?"),
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

    final url = "$baseUrl/api/lessons/edit_lesson_students/";
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: await getAuthHeaders(),
        body: jsonEncode({
          "lesson_id": widget.lessonId,
          "action": "add",
          "new_student": true,
          "first_name": _firstNameController.text.trim(),
          "last_name": _lastNameController.text.trim(),
          "birthday": _birthdayController.text.trim(),
        }),
      );
      if (response.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("Error creating student: ${utf8.decode(response.bodyBytes)}")),
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
        mainAxisSize: MainAxisSize.min, // Wrap content height.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modal Header.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Select or Create Student",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // TabBar.
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
          // Tab Content.
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabController,
              children: [
                // "Select Existing" Tab.
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: "Search Student",
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
                              children: students.where((student) {
                                String studentName =
                                    "${student['first_name'] ?? ''} ${student['last_name'] ?? ''}"
                                        .trim();
                                return studentName.toLowerCase().contains(searchQuery);
                              }).map((student) {
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 8),
                                  child: ListTile(
                                    title: Text(
                                        "${student['id']} - ${student['first_name']} ${student['last_name']}"),
                                    subtitle: Text("Birthday: ${student['birthday']}"),
                                    trailing: student["selected"] == true
                                        ? const Icon(Icons.check_circle,
                                            color: Colors.orange)
                                        : const Icon(Icons.arrow_forward,
                                            color: Colors.orange),
                                    onTap: () => _toggleStudentSelection(student),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
                // "Create New" Tab.
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: "First Name",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: "Last Name",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _birthdayController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: "Birthday",
                                  border: OutlineInputBorder(),
                                  hintText: "Select a date",
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: _showBirthdayPicker,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _createStudent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Create Student"),
                        ),
                      ],
                    ),
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
