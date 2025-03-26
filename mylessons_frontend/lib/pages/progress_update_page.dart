// File: lib/pages/progress_update_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // Contains baseUrl and getAuthHeaders
import '../modals/update_progress_form.dart';

class ProgressUpdatePage extends StatefulWidget {
  final int recordId; // The progress record ID to update
  const ProgressUpdatePage({Key? key, required this.recordId}) : super(key: key);

  @override
  _ProgressUpdatePageState createState() => _ProgressUpdatePageState();
}

class _ProgressUpdatePageState extends State<ProgressUpdatePage> {
  bool _isLoading = true;
  Map<String, dynamic>? progressRecord;

  @override
  void initState() {
    super.initState();
    _fetchProgressRecord();
  }

  Future<void> _fetchProgressRecord() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final headers = await getAuthHeaders();
      final url = Uri.parse('$baseUrl/api/progress/record/${widget.recordId}/');
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        setState(() {
          progressRecord = json.decode(response.body);
        });
      } else {
        // Handle error as needed.
      }
    } catch (e) {
      // Handle exception as needed.
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _openUpdateForm() async {
    if (progressRecord != null) {
      final updatedData = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (context) => UpdateProgressForm(currentData: progressRecord!),
      );
      if (updatedData != null) {
        // Refresh the progress record with the updated data.
        _fetchProgressRecord();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Progress', style: GoogleFonts.lato()),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.orange))
          : progressRecord == null
              ? Center(child: Text('No progress record found', style: GoogleFonts.lato()))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Progress Record Details',
                          style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text('Notes: ${progressRecord!['notes'] ?? ''}', style: GoogleFonts.lato(fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _openUpdateForm,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        child: Text('Update Progress', style: GoogleFonts.lato(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
    );
  }
}
