import 'package:flutter/material.dart';
import 'payment_widgets.dart';

/// Build a section that displays a list of staff users.
/// Now accepts extra parameters to enable editing of payment types for each staff.
Widget buildStaffSection(
  List<dynamic> staffList, {
  required BuildContext context,
  required Map<String, dynamic> schoolDetails,
  required TextEditingController schoolNameController,
  required Future<void> Function() refreshSchoolDetails,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: staffList.map((staff) {
      final staffName = staff['user_name'] ?? "Unnamed";
      final roles = staff['roles'] as List<dynamic>? ?? [];
      final staffPaymentTypes = staff['payment_types'] ?? {};

      // Make sure you have a user_id in your staff JSON.
      // Convert it to String or keep as int depending on your backend.
      final userId = staff['user_id']?.toString();

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row for the user name and the Edit button icon (for user-level editing).
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    staffName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: If you want a "global" edit for all roles,
                      // you could open a user-level modal here.
                      // Otherwise, you can rely solely on the edit icons
                      // in each payment card below.
                    },
                    icon: const Icon(Icons.edit, color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Display roles.
              if (roles.isNotEmpty)
                Text(
                  "Roles: ${roles.join(', ')}",
                  style: const TextStyle(fontSize: 14),
                ),
              const SizedBox(height: 8),

              // Display payment types with an edit icon on each card.
              buildPaymentTypesWidget(
                Map<String, dynamic>.from(staffPaymentTypes),
                // Provide these parameters so the edit icons appear:
                context: context,
                schoolDetails: schoolDetails,
                schoolNameController: schoolNameController,
                refreshSchoolDetails: refreshSchoolDetails,
                userId: userId, // The key piece for user-specific edits.
              ),
            ],
          ),
        ),
      );
    }).toList(),
  );
}
