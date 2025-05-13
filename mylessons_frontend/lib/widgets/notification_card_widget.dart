import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NotificationCard extends StatefulWidget {
  final Map<String, dynamic> notification;
  const NotificationCard({Key? key, required this.notification}) : super(key: key);

  @override
  _NotificationCardState createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final created = DateFormat("dd MMM yyyy, HH:mm")
        .format(DateTime.parse(n['created_at']));

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: icon + subject
              Row(
                children: [
                  const Icon(Icons.notifications, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(n['subject'],
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Date + Details button on same line
              Row(
                children: [
                  Text(created,
                    style: GoogleFonts.lato(fontSize: 14, color: Colors.black54),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(Icons.expand_more),
                    ),
                    label: Text(
                      "details",
                      style: GoogleFonts.lato(color: Colors.orange),
                    ),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                ],
              ),

              // Expanded message
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(n['message'],
                  style: GoogleFonts.lato(fontSize: 15),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
