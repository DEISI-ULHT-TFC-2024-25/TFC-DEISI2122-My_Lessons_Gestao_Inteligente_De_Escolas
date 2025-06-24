import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // Exports getAuthHeaders() and baseUrl

Future<T?> showLocationModal<T>(
    BuildContext context, {
      int? lessonId,
      int? packId,
      int? schoolId,
      bool localOnly = false,
      List<int>? initialSelectedIds,
      List<Map<String, dynamic>>? items,
    }) {
  // same sanity‐check as in SubjectModal:
  assert(
  localOnly || [lessonId, packId, schoolId].where((x) => x != null).length == 1,
  'You must provide exactly one of lessonId, packId or schoolId',
  );

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final maxHeight = MediaQuery.of(ctx).size.height * 0.9;
      return SizedBox(
        height: maxHeight,
        child: LocationModal(
          lessonId: lessonId,
          packId: packId,
          schoolId: schoolId,
          localOnly: localOnly,
          initialSelectedIds: initialSelectedIds,
          items: items,
        ),
      );
    },
  );
}


class LocationModal extends StatefulWidget {
  final int? lessonId;
  final int? packId;
  final int? schoolId;

  /// if true, operate purely locally: no HTTP POST for update/create
  final bool localOnly;

  /// initial selection for the picker (IDs)
  final List<int>? initialSelectedIds;

  /// supply list of available items in local mode
  final List<Map<String, dynamic>>? items;

  const LocationModal({
    Key? key,
    this.lessonId,
    this.packId,
    this.schoolId,
    this.localOnly = false,
    this.initialSelectedIds,
    this.items,
  }) : super(key: key);

  @override
  _LocationModalState createState() => _LocationModalState();
}

class _LocationModalState extends State<LocationModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> locations = [];
  bool isLoading = false;
  String searchQuery = "";
  dynamic selectedLocation; // singular selected location
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
    if (widget.localOnly) {
      locations = widget.items ?? [];
      _selectedIds = List<int>.from(widget.initialSelectedIds ?? []);
      isLoading = false;
    } else {
      fetchLocations();
    }
  }

  Future<void> fetchLocations() async {
    setState(() {
      isLoading = true;
    });
    try {
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

      final response = await http.get(uri, headers: await getAuthHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          locations = data["locations"] ?? [];
          if (isMultiSelect) {
            _selectedIds = (data["selected_locations"] as List?)
                    ?.map((l) => l["id"] as int)
                    .toList() ?? [];
          } else {
            selectedLocation = data["selected_location"];
          }
          // Sort so selected come first, then alphabetically
          locations.sort((a, b) {
            bool aSel;
            bool bSel;
            if (isMultiSelect) {
              aSel = _selectedIds.contains(a["id"]);
              bSel = _selectedIds.contains(b["id"]);
            } else {
              aSel = selectedLocation != null &&
                  a["id"] == selectedLocation["id"];
              bSel = selectedLocation != null &&
                  b["id"] == selectedLocation["id"];
            }
            if (aSel && !bSel) return -1;
            if (bSel && !aSel) return 1;
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

  void _toggleSelection(int locationId) {
    setState(() {
      if (_selectedIds.contains(locationId)) {
        _selectedIds.remove(locationId);
      } else {
        _selectedIds.add(locationId);
      }
    });
  }

  void _selectLocation(dynamic location) async {
    if (widget.localOnly) {
      Navigator.pop(context, location);
      return;
    }
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Confirm Selection"),
        content: Text(
          'Do you want to select location: ${location["name"]}?'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Confirm")),
        ],
      ),
    );
    if (confirmed == true) {
      final url = "$baseUrl/api/lessons/edit_location/";
      Map<String, dynamic> payload = {
        "location_id": location["id"],
        "action": "change",
      };
      if (widget.lessonId != null) payload["lesson_id"] = widget.lessonId;
      if (widget.packId != null) payload["pack_id"] = widget.packId;
      if (widget.schoolId != null) payload["school_id"] = widget.schoolId;

      try {
        final resp = await http.post(Uri.parse(url),
            headers: await getAuthHeaders(), body: jsonEncode(payload));
        if (resp.statusCode == 200) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error updating location: ${utf8.decode(resp.bodyBytes)}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<void> _updateLocations() async {
    if (widget.localOnly) {
      final picked = locations.where((l) => _selectedIds.contains(l['id'] as int)).toList();
      Navigator.pop(context, picked);
      return;
    }
    final url = "$baseUrl/api/schools/update_locations/";
    Map<String, dynamic> payload = {"location_ids": _selectedIds};
    if (widget.lessonId != null) payload['lesson_id'] = widget.lessonId;
    if (widget.packId != null) payload['pack_id'] = widget.packId;
    if (widget.schoolId != null) payload['school_id'] = widget.schoolId;

    try {
      final resp = await http.post(Uri.parse(url),
          headers: await getAuthHeaders(), body: jsonEncode(payload));
      if (resp.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating locations: ${utf8.decode(resp.bodyBytes)}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _createLocation() async {
    final name = _newLocationNameController.text.trim();
    final address = _newLocationAddressController.text.trim();
    if (name.isEmpty || address.isEmpty) return;

    if (widget.localOnly) {
      final newItem = {'id': -1, 'name': name, 'address': address};
      Navigator.pop(context, [newItem]);
      return;
    }

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Confirm Creation"),
        content: Text("Create location: $name?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Confirm")),
        ],
      ),
    );
    if (confirmed != true) return;

    final url = "$baseUrl/api/schools/create_location/";
    Map<String, dynamic> payload = {
      "location_name": name,
      "location_address": address,
    };
    if (widget.lessonId != null) payload['lesson_id'] = widget.lessonId;
    if (widget.packId != null) payload['pack_id'] = widget.packId;
    if (widget.schoolId != null) payload['school_id'] = widget.schoolId;

    try {
      print(payload);
      final resp = await http.post(Uri.parse(url),
          headers: await getAuthHeaders(), body: jsonEncode(payload));
      if (resp.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating location: ${utf8.decode(resp.bodyBytes)}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = locations.where((loc) =>
        loc['name'].toString().toLowerCase().contains(searchQuery)).toList();

    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select or Create Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            indicatorColor: Colors.orange,
            tabs: const [Tab(text: 'Select Existing'), Tab(text: 'Create New')],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
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
                                      labelText: 'Search Location',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
                                  ),
                                ),
                                if (isMultiSelect) ...[
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _updateLocations,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: isMultiSelect
                                  ? ListView(
                                      children: filtered.map((loc) {
                                        return CheckboxListTile(
                                          title: Text(loc['name']),
                                          subtitle: Text(loc['address'] ?? ''),
                                          value: _selectedIds.contains(loc['id']),
                                          activeColor: Colors.orange,
                                          onChanged: (_) => _toggleSelection(loc['id'] as int),
                                        );
                                      }).toList(),
                                    )
                                  : ListView(
                                      children: filtered.map((loc) {
                                        final sel = selectedLocation != null && loc['id'] == selectedLocation['id'];
                                        return ListTile(
                                          title: Text(loc['name']),
                                          subtitle: Text(loc['address'] ?? ''),
                                          trailing: sel
                                              ? const Icon(Icons.check_circle, color: Colors.orange)
                                              : const Icon(Icons.arrow_forward, color: Colors.orange),
                                          onTap: () => _selectLocation(loc),
                                        );
                                      }).toList(),
                                    ),
                            ),
                          ],
                        ),
                      ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _newLocationNameController,
                        decoration: const InputDecoration(
                          labelText: 'New Location Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _newLocationAddressController,
                        decoration: const InputDecoration(
                          labelText: 'New Location Address',
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
                        child: const Text('Create Location'),
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
