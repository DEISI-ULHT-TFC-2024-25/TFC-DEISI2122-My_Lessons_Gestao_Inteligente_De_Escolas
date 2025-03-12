import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // Exports getAuthHeaders() and baseUrl

class LocationModal extends StatefulWidget {
  final int lessonId;
  const LocationModal({super.key, required this.lessonId});

  @override
  _LocationModalState createState() => _LocationModalState();
}

class _LocationModalState extends State<LocationModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> locations = [];
  bool isLoading = false;
  String searchQuery = "";
  final TextEditingController _newLocationNameController = TextEditingController();
  final TextEditingController _newLocationAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchLocations();
  }

  Future<void> fetchLocations() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/schools/locations/"),
        headers: await getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        // Sort alphabetically by location name.
        data.sort((a, b) => a["name"]
            .toString()
            .toLowerCase()
            .compareTo(b["name"].toString().toLowerCase()));
        setState(() {
          locations = data;
        });
      }
    } catch (e) {
      print("Error fetching locations: $e");
    }
    setState(() {
      isLoading = false;
    });
  }

  void _selectLocation(dynamic location) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Selection"),
          content: Text("Do you want to select location: ${location["name"]}?"),
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
      final url = "$baseUrl/api/lessons/edit_lesson_location/";
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: await getAuthHeaders(),
          body: jsonEncode({
            "lesson_id": widget.lessonId,
            "location_id": location["id"],
            "action": "change",
          }),
        );
        if (response.statusCode == 200) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error updating location: ${utf8.decode(response.bodyBytes)}"),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _createLocation() async {
    if (_newLocationNameController.text.trim().isEmpty ||
        _newLocationAddressController.text.trim().isEmpty) {
      return;
    }
    // Show confirmation dialog before creating.
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Creation"),
          content: Text("Do you want to create location: ${_newLocationNameController.text.trim()}?"),
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

    final url = "$baseUrl/api/lessons/edit_lesson_location/";
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: await getAuthHeaders(),
        body: jsonEncode({
          "lesson_id": widget.lessonId,
          "new_location": true,
          "location_name": _newLocationNameController.text.trim(),
          "location_address": _newLocationAddressController.text.trim(),
          "action": "add",
        }),
      );
      if (response.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating location: ${utf8.decode(response.bodyBytes)}")),
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
                "Select or Create Location",
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
                          labelText: "Search Location",
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
                              children: locations.where((loc) {
                                return loc["name"]
                                    .toString()
                                    .toLowerCase()
                                    .contains(searchQuery);
                              }).map((loc) {
                                return ListTile(
                                  title: Text(loc["name"]),
                                  subtitle: Text(loc["address"] ?? ""),
                                  trailing: const Icon(Icons.arrow_forward, color: Colors.orange),
                                  onTap: () => _selectLocation(loc),
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
                        controller: _newLocationNameController,
                        decoration: const InputDecoration(
                          labelText: "New Location Name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _newLocationAddressController,
                        decoration: const InputDecoration(
                          labelText: "New Location Address",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _createLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Create Location"),
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
