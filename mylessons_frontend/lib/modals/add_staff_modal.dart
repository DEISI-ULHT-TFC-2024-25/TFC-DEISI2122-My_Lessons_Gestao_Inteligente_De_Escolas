import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/staff_provider.dart';

/// The modal to display and add a staff member using the provider.
class AddStaffModal extends StatefulWidget {
  const AddStaffModal({Key? key}) : super(key: key);

  @override
  _AddStaffModalState createState() => _AddStaffModalState();
}

class _AddStaffModalState extends State<AddStaffModal> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the modal with a provider.
    return ChangeNotifierProvider<StaffProvider>(
      create: (_) => StaffProvider(),
      child: Consumer<StaffProvider>(
        builder: (context, staffProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, // Wrap content height
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header row with a back arrow and title.
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Add Staff Member",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
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
                        onPressed: () {
                          staffProvider
                              .searchUser(_searchController.text.trim());
                        },
                      ),
                    ),
                    onSubmitted: (value) {
                      staffProvider.searchUser(value.trim());
                    },
                  ),
                  const SizedBox(height: 24),
                  // Show a loading indicator during the search.
                  if (staffProvider.isLoading)
                    const Center(child: CircularProgressIndicator()),
                  // Show user details if found.
                  if (staffProvider.foundUser != null) ...[
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${staffProvider.foundUser!['email']}"),
                            const SizedBox(height: 8),
                            Text(
                              "${staffProvider.foundUser!['first_name']} ${staffProvider.foundUser!['last_name']}",
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Role selection checkboxes.
                    CheckboxListTile(
                      title: const Text("Admin"),
                      value: staffProvider.isAdmin,
                      activeColor: Colors.orange,
                      onChanged: (bool? value) {
                        staffProvider.isAdmin = value ?? false;
                        staffProvider.notifyListeners();
                      },
                    ),
                    CheckboxListTile(
                      title: const Text("Instructor"),
                      value: staffProvider.isInstructor,
                      activeColor: Colors.orange,
                      onChanged: (bool? value) {
                        staffProvider.isInstructor = value ?? false;
                        staffProvider.notifyListeners();
                      },
                    ),
                    CheckboxListTile(
                      title: const Text("Monitor"),
                      value: staffProvider.isMonitor,
                      activeColor: Colors.orange,
                      onChanged: (bool? value) {
                        staffProvider.isMonitor = value ?? false;
                        staffProvider.notifyListeners();
                      },
                    ),
                    const SizedBox(height: 24),
                    // "Add Staff" button.
                    ElevatedButton(
                      onPressed: () async {
                        bool success = await staffProvider.addStaff();
                        if (success) {
                          Navigator.pop(context, true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 10),
                      ),
                      child: const Text(
                        "Add Staff",
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
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
      // Wrap with a padding to account for any on-screen keyboard.
      return Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9, // The modal starts at 90% of screen height.
          minChildSize: 0.3, // It can shrink to 30%...
          maxChildSize: 0.9, // ...and expand to 90% of the screen height.
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: const AddStaffModal(),
            );
          },
        ),
      );
    },
  );
}
