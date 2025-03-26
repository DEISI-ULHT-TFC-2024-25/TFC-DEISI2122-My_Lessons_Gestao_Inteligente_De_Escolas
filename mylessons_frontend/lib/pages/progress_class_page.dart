// File: lib/pages/progress_class_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // Assumes baseUrl and getAuthHeaders are defined

class ClassProgressPage extends StatefulWidget {
  final Map<String, dynamic> lesson;
  const ClassProgressPage({Key? key, required this.lesson}) : super(key: key);

  @override
  _ClassProgressPageState createState() => _ClassProgressPageState();
}

class _ClassProgressPageState extends State<ClassProgressPage> {
  bool _isLoading = true;
  Map<String, dynamic>? progressRecord;

  @override
  void initState() {
    super.initState();
    fetchProgressRecord();
  }

  Future<void> fetchProgressRecord() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final headers = await getAuthHeaders();
      final lessonId = widget.lesson['id'];
      final response = await http.get(
        Uri.parse('$baseUrl/api/progress/record/$lessonId/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        setState(() {
          progressRecord = json.decode(response.body);
        });
      } else {
        // Handle error if necessary
      }
    } catch (e) {
      // Handle exception if necessary
    }
    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildSkillCard(Map<String, dynamic> skillData) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: ListTile(
        title: Text(
          skillData['skill_name'] ?? '',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Level: ${skillData['level'] ?? ''}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Class Progress', style: GoogleFonts.lato()),
        backgroundColor: Colors.orange,
      ),
      body: RefreshIndicator(
        onRefresh: fetchProgressRecord,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.orange))
            : progressRecord == null
                ? Center(child: Text('No progress data available', style: GoogleFonts.lato()))
                : ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Lesson: ${widget.lesson['students_name'] ?? 'N/A'}',
                          style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Date: ${progressRecord!['date'] ?? ''}',
                          style: GoogleFonts.lato(fontSize: 16, color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Skills Covered:',
                          style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (progressRecord!['skills'] != null &&
                          (progressRecord!['skills'] as List).isNotEmpty)
                        ...List<Widget>.from((progressRecord!['skills'] as List)
                            .map((skill) => _buildSkillCard(skill)))
                      else
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('No skills updated.', style: GoogleFonts.lato()),
                        ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Notes:',
                          style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          progressRecord!['notes'] ?? 'No notes provided.',
                          style: GoogleFonts.lato(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),
    );
  }
}
