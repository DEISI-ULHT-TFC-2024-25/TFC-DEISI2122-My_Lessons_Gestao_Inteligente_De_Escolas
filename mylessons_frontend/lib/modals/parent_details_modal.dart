import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ParentDetailsModal extends StatelessWidget {
  final Map<String, dynamic> parent;

  const ParentDetailsModal({
    Key? key,
    required this.parent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Parent Details",
              style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text("Name"),
              subtitle: Text(parent['name'].toString()),
            ),
            ListTile(
              title: const Text("Email"),
              subtitle: Text(parent['email']?.toString() ?? ''),
            ),
            ListTile(
              title: const Text("Country Code"),
              subtitle: Text(parent['country_code']?.toString() ?? ''),
            ),
            ListTile(
              title: const Text("Phone"),
              subtitle: Text(parent['phone']?.toString() ?? ''),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close", style: TextStyle(color: Colors.orange)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
