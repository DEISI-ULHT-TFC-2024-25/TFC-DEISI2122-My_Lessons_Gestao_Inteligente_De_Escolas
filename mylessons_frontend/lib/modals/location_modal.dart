import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // Exports getAuthHeaders() and baseUrl

class LocationModal extends StatefulWidget {
  final int? lessonId;
  final int? packId;
  final int? schoolId;
  const LocationModal({Key? key, this.lessonId, this.packId, this.schoolId})
      : super(key: key);

  @override
  _LocationModalState createState() => _LocationModalState();
}

class _LocationModalState extends State<LocationModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> locations = [];
  bool isLoading = false;
  String searchQuery = "";
  dynamic selectedLocation; // singular selected location from lesson/pack
  List<int> _selectedIds = []; // for multi-select mode

  final TextEditingController _newLocationNameController =
      TextEditingController();
  final TextEditingController _newLocationAddressController =
      TextEditingController();

  // Multi-select mode is active if a school_id is provided.
  bool get isMultiSelect => widget.schoolId != null;

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
      // Build query parameters.
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
      Uri uri = Uri.parse("$baseUrl/api/schools/locations/")
          .replace(queryParameters: queryParams);

      // Decode the response as UTF8.
      final response = await http.get(uri, headers: await getAuthHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          locations = data["locations"] ?? [];
          if (isMultiSelect) {
            _selectedIds = (data["selected_locations"] as List?)
                    ?.map((l) => l["id"] as int)
                    .toList() ??
                [];
          } else {
            selectedLocation = data["selected_location"];
          }
          // Sort locations so that selected ones come first.
          locations.sort((a, b) {
            bool aSelected;
            bool bSelected;
            if (isMultiSelect) {
              aSelected = _selectedIds.contains(a["id"]);
              bSelected = _selectedIds.contains(b["id"]);
            } else {
              aSelected = selectedLocation != null && a["id"] == selectedLocation["id"];
              bSelected = selectedLocation != null && b["id"] == selectedLocation["id"];
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
      print("Error fetching locations: $e");
    }
    setState(() {
      isLoading = false;
    });
  }

  // Toggle selection for multi-select mode.
  void _toggleSelection(int locationId) {
    setState(() {
      if (_selectedIds.contains(locationId)) {
        _selectedIds.remove(locationId);
      } else {
        _selectedIds.add(locationId);
      }
    });
  }

  // For single-select mode: handle selection immediately.
  void _selectLocation(dynamic location) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      ),
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
                content: Text("Error updating location: ${utf8.decode(response.bodyBytes)}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // Update locations for multi-select mode.
  Future<void> _updateLocations() async {
    final url = "$baseUrl/api/schools/update_locations/";
    try {
      final response = await http.post(Uri.parse(url),
          headers: await getAuthHeaders(),
          body: jsonEncode({
            "school_id": widget.schoolId,
            "location_ids": _selectedIds,
          }));
      if (response.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error updating locations: ${utf8.decode(response.bodyBytes)}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _createLocation() async {
    if (_newLocationNameController.text.trim().isEmpty ||
        _newLocationAddressController.text.trim().isEmpty) {
      return;
    }
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Creation"),
        content: Text(
            "Do you want to create location: ${_newLocationNameController.text.trim()}?"),
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
    final url = "$baseUrl/api/schools/create_location/";
    // Build the payload based on which ID is available.
    Map<String, dynamic> payload = {
      "location_name": _newLocationNameController.text.trim(),
      "location_address": _newLocationAddressController.text.trim(),
    };
    if (widget.lessonId != null) {
      payload["lesson_id"] = widget.lessonId;
    } else if (widget.packId != null) {
      payload["pack_id"] = widget.packId;
    } else if (widget.schoolId != null) {
      payload["school_id"] = widget.schoolId;
    }
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
    // Filter locations based on the search query.
    List<dynamic> filteredLocations = locations
        .where((loc) =>
            loc["name"].toString().toLowerCase().contains(searchQuery))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modal Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Select or Create Location",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                if (isMultiSelect) ...[
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _updateLocations,
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
                                      children: filteredLocations.map((loc) {
                                        return CheckboxListTile(
                                          title: Text(loc["name"]),
                                          subtitle: Text(loc["address"] ?? ""),
                                          value: _selectedIds.contains(loc["id"]),
                                          activeColor: Colors.orange,
                                          onChanged: (val) =>
                                              _toggleSelection(loc["id"] as int),
                                        );
                                      }).toList(),
                                    )
                                  : ListView(
                                      children: filteredLocations.map((loc) {
                                        bool isSelected = selectedLocation != null &&
                                            loc["id"] == selectedLocation["id"];
                                        return ListTile(
                                          title: Text(loc["name"]),
                                          subtitle: Text(loc["address"] ?? ""),
                                          trailing: isSelected
                                              ? const Icon(Icons.check_circle,
                                                  color: Colors.orange)
                                              : const Icon(Icons.arrow_forward,
                                                  color: Colors.orange),
                                          onTap: () => _selectLocation(loc),
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
