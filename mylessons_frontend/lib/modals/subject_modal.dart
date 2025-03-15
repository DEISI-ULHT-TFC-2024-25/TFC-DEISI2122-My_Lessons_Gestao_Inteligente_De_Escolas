import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // Exports getAuthHeaders() and baseUrl

class SubjectModal extends StatefulWidget {
  final int? lessonId;
  final int? packId;
  final int? schoolId;
  const SubjectModal({Key? key, this.lessonId, this.packId, this.schoolId})
      : super(key: key);

  @override
  _SubjectModalState createState() => _SubjectModalState();
}

class _SubjectModalState extends State<SubjectModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> subjects = [];
  bool isLoading = false;
  String searchQuery = "";
  dynamic selectedSubject; // singular selected subject from lesson/pack
  List<int> _selectedIds = []; // for multi-select mode

  final TextEditingController _newSubjectController = TextEditingController();

  // Multi-select mode is active if a school_id is provided.
  bool get isMultiSelect => widget.schoolId != null;

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
      // Build query parameters using lessonId, packId, and schoolId if available.
      Map<String, String> queryParams = {};
      if (widget.lessonId != null) {
        queryParams['lesson_id'] = widget.lessonId.toString();
      }
      if (widget.packId != null) {
        queryParams['pack_id'] = widget.packId.toString();
      }
      if (widget.schoolId != null) {
        queryParams['school_id'] = widget.schoolId.toString();
      }
      Uri uri = Uri.parse("$baseUrl/api/schools/subjects/")
          .replace(queryParameters: queryParams);

      // Decode the response as UTF8.
      final response = await http.get(uri, headers: await getAuthHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          subjects = (data["subjects"] as List?) ?? [];
          selectedSubject = data["selected_subject"];
          if (isMultiSelect) {
            // In multi-select mode, get the list of subject ids currently associated with the school.
            _selectedIds = (data["selected_subjects"] as List?)
                    ?.map((s) => s["id"] as int)
                    .toList() ??
                [];
          }
          // Sort subjects so that items selected (by _selectedIds in multi-select,
          // or by singular selectedSubject otherwise) come first, then alphabetically.
          subjects.sort((a, b) {
            bool aSelected;
            bool bSelected;
            if (isMultiSelect) {
              aSelected = _selectedIds.contains(a["id"]);
              bSelected = _selectedIds.contains(b["id"]);
            } else {
              aSelected =
                  selectedSubject != null && a["id"] == selectedSubject["id"];
              bSelected =
                  selectedSubject != null && b["id"] == selectedSubject["id"];
            }
            if (aSelected && !bSelected) return -1;
            if (bSelected && !aSelected) return 1;
            return a["name"]
                .toString()
                .toLowerCase()
                .compareTo(b["name"].toString().toLowerCase());
          });
        });
      }
    } catch (e) {
      print("Error fetching subjects: $e");
    }
    setState(() {
      isLoading = false;
    });
  }

  // For multi-select mode: toggle the selection of a subject.
  void _toggleSelection(int subjectId) {
    setState(() {
      if (_selectedIds.contains(subjectId)) {
        _selectedIds.remove(subjectId);
      } else {
        _selectedIds.add(subjectId);
      }
    });
  }

  // For single-select mode: handle selection immediately.
  void _selectSubject(dynamic subject) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      ),
    );
    if (confirmed == true) {
      final url = "$baseUrl/api/lessons/edit_subject/";
      // Build payload including all possible IDs.
      Map<String, dynamic> payload = {
        "subject_id": subject["id"],
        "action": "change",
      };
      if (widget.lessonId != null) payload["lesson_id"] = widget.lessonId;
      if (widget.packId != null) payload["pack_id"] = widget.packId;
      if (widget.schoolId != null) payload["school_id"] = widget.schoolId;

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: await getAuthHeaders(),
          body: jsonEncode(payload),
        );
        if (response.statusCode == 200) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Error updating subject: ${utf8.decode(response.bodyBytes)}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // Update subjects for multi-select mode.
  Future<void> _updateSubjects() async {
    final url = "$baseUrl/api/schools/update_subjects/";
    try {
      final response = await http.post(Uri.parse(url),
          headers: await getAuthHeaders(),
          body: jsonEncode({
            "school_id": widget.schoolId,
            "subject_ids": _selectedIds,
          }));
      if (response.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Error updating subjects: ${utf8.decode(response.bodyBytes)}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Updated subject creation: include all provided IDs.
  void _createSubject() async {
    if (_newSubjectController.text.trim().isEmpty) return;
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Creation"),
        content: Text(
            "Do you want to create subject: ${_newSubjectController.text.trim()}?"),
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
    if (confirmed != true) return;

    final url = "$baseUrl/api/schools/create_subject/";
    // Build payload including all possible IDs.
    Map<String, dynamic> payload = {
      "subject_name": _newSubjectController.text.trim(),
    };
    if (widget.lessonId != null) payload["lesson_id"] = widget.lessonId;
    if (widget.packId != null) payload["pack_id"] = widget.packId;
    if (widget.schoolId != null) payload["school_id"] = widget.schoolId;

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: await getAuthHeaders(),
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Error creating subject: ${utf8.decode(response.bodyBytes)}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter subjects based on the search query.
    List<dynamic> filteredSubjects = subjects
        .where((subject) =>
            subject["name"].toString().toLowerCase().contains(searchQuery))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                  onPressed: () => Navigator.pop(context)),
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
                // Tab 1: Select Existing with Search Input
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
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
                                if (isMultiSelect) ...[
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _updateSubjects,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange),
                                    child: const Text("Save"),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: isMultiSelect
                                  ? ListView(
                                      children: filteredSubjects.map((subject) {
                                        bool isChecked =
                                            _selectedIds.contains(subject["id"]);
                                        return CheckboxListTile(
                                          title: Text(subject["name"]),
                                          value: isChecked,
                                          activeColor: Colors.orange,
                                          onChanged: (val) =>
                                              _toggleSelection(subject["id"] as int),
                                        );
                                      }).toList(),
                                    )
                                  : ListView(
                                      children: filteredSubjects.map((subject) {
                                        bool isSelected = selectedSubject != null &&
                                            subject["id"] ==
                                                selectedSubject["id"];
                                        return ListTile(
                                          title: Text(subject["name"]),
                                          trailing: isSelected
                                              ? const Icon(Icons.check_circle,
                                                  color: Colors.orange)
                                              : const Icon(Icons.arrow_forward,
                                                  color: Colors.orange),
                                          onTap: () => _selectSubject(subject),
                                        );
                                      }).toList(),
                                    ),
                            ),
                          ],
                        ),
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
