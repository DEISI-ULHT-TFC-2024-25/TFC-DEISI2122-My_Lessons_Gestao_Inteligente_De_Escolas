import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart'; // Ensure this provides baseUrl and getAuthHeaders

class ProgressPage extends StatefulWidget {
  const ProgressPage({Key? key}) : super(key: key);

  @override
  _ProgressPageState createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final storage = const FlutterSecureStorage();
  List<dynamic> progressRecords = [];
  Map<String, dynamic>? latestReport;
  bool isLoadingRecords = true;
  bool isLoadingReport = true;

  @override
  void initState() {
    super.initState();
    fetchProgressRecords();
    fetchLatestReport();
  }

  Future<void> fetchProgressRecords() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/progress/records/'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      setState(() {
        progressRecords = json.decode(utf8.decode(response.bodyBytes));
        isLoadingRecords = false;
      });
    }
  }

  Future<void> fetchLatestReport() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/progress/reports/latest/'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      setState(() {
        latestReport = json.decode(utf8.decode(response.bodyBytes));
        isLoadingReport = false;
      });
    } else {
      setState(() {
        isLoadingReport = false;
      });
    }
  }

  Widget _buildRecordCard(dynamic record) {
    final date = record['date'] ?? '';
    final lesson = record['lesson'] != null
        ? 'Lesson ${record['lesson']['id']}'
        : 'No Lesson Assigned';
    final notes = record['notes'] ?? '';
    final skillsList = record['skills'] as List<dynamic>? ?? [];
    final skills = skillsList.map((s) {
      // Assuming each skill proficiency has nested skill info
      return s['skill'] != null ? s['skill']['name'] : '';
    }).where((name) => name != '').toList();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd MMM yyyy').format(DateTime.parse(date)),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(lesson),
            const SizedBox(height: 4),
            Text("Skills: " + skills.join(', ')),
            const SizedBox(height: 4),
            Text("Notes: " + notes),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final periodStart = report['period_start'] ?? '';
    final periodEnd = report['period_end'] ?? '';
    final summary = report['summary'] ?? '';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Progress Report",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Period: $periodStart to $periodEnd"),
            const SizedBox(height: 8),
            Text(summary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      Tab(text: "Records"),
      Tab(text: "Report"),
    ];

    final tabViews = [
      isLoadingRecords
          ? const Center(child: CircularProgressIndicator())
          : progressRecords.isNotEmpty
              ? ListView.builder(
                  itemCount: progressRecords.length,
                  itemBuilder: (context, index) {
                    return _buildRecordCard(progressRecords[index]);
                  },
                )
              : const Center(child: Text("No progress records available")),
      isLoadingReport
          ? const Center(child: CircularProgressIndicator())
          : latestReport != null
              ? SingleChildScrollView(child: _buildReportCard(latestReport!))
              : const Center(child: Text("No progress report available")),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Progress"),
        backgroundColor: Colors.orange,
      ),
      body: DefaultTabController(
        length: tabs.length,
        child: Column(
          children: [
            TabBar(
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.grey,
              tabs: tabs,
            ),
            Expanded(
              child: TabBarView(
                children: tabViews,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
