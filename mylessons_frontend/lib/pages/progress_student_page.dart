// File: lib/pages/progress_student_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../services/api_service.dart'; // Assumes baseUrl and getAuthHeaders are defined

class StudentProgressPage extends StatefulWidget {
  const StudentProgressPage({Key? key}) : super(key: key);

  @override
  _StudentProgressPageState createState() => _StudentProgressPageState();
}

class _StudentProgressPageState extends State<StudentProgressPage>
    with SingleTickerProviderStateMixin {
  bool _isLoadingRecords = true;
  bool _isLoadingReports = true;
  List<dynamic> progressRecords = [];
  List<dynamic> progressReports = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchProgressRecords();
    fetchProgressReports();
  }

  Future<void> fetchProgressRecords() async {
    setState(() {
      _isLoadingRecords = true;
    });
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/progress/records/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        setState(() {
          progressRecords = json.decode(response.body);
        });
      }
    } catch (e) {
      // Handle error if needed
    }
    setState(() {
      _isLoadingRecords = false;
    });
  }

  Future<void> fetchProgressReports() async {
    setState(() {
      _isLoadingReports = true;
    });
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/progress/reports/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        setState(() {
          progressReports = json.decode(response.body);
        });
      }
    } catch (e) {
      // Handle error if needed
    }
    setState(() {
      _isLoadingReports = false;
    });
  }

  Widget _buildRecordCard(dynamic record) {
    // Assume record has date, lesson info, skills, and notes
    final lessonInfo = record['lesson'] != null
        ? 'Lesson: ${record['lesson']['students_name']}'
        : 'No Lesson Assigned';
    final dateStr = record['date'] ?? '';
    final skillsList = record['skills'] as List<dynamic>? ?? [];
    final skillsStr = skillsList.isNotEmpty
        ? skillsList.map((s) => s['skill_name']).join(', ')
        : 'No skills recorded';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)),
              style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              lessonInfo,
              style: GoogleFonts.lato(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              'Skills: $skillsStr',
              style: GoogleFonts.lato(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Notes: ${record['notes'] ?? 'None'}',
              style: GoogleFonts.lato(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(dynamic report) {
    // Assume report has period_start, period_end, summary, created_at.
    final period = '${report['period_start']} - ${report['period_end']}';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Period: $period',
              style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              report['summary'] ?? '',
              style: GoogleFonts.lato(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Generated on: ${report['created_at'] ?? ''}',
              style: GoogleFonts.lato(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsTab() {
    return RefreshIndicator(
      onRefresh: fetchProgressRecords,
      child: _isLoadingRecords
          ? Center(child: CircularProgressIndicator(color: Colors.orange))
          : progressRecords.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 100),
                    Center(child: Text('No progress records available', style: GoogleFonts.lato())),
                  ],
                )
              : ListView.builder(
                  itemCount: progressRecords.length,
                  itemBuilder: (context, index) => _buildRecordCard(progressRecords[index]),
                ),
    );
  }

  Widget _buildReportsTab() {
    return RefreshIndicator(
      onRefresh: fetchProgressReports,
      child: _isLoadingReports
          ? Center(child: CircularProgressIndicator(color: Colors.orange))
          : progressReports.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 100),
                    Center(child: Text('No progress reports available', style: GoogleFonts.lato())),
                  ],
                )
              : ListView.builder(
                  itemCount: progressReports.length,
                  itemBuilder: (context, index) => _buildReportCard(progressReports[index]),
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Progress', style: GoogleFonts.lato()),
        backgroundColor: Colors.orange,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Records'),
            Tab(text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecordsTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }
}
