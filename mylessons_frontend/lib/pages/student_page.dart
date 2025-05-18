import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:mylessons_frontend/services/api_service.dart';
import 'package:mylessons_frontend/providers/lessons_modal_provider.dart';
import 'package:provider/provider.dart';

// Helper widgets (you can move these into their own files)
import '../widgets/pack_card.dart';

class StudentPage extends StatefulWidget {
  final int studentId;

  const StudentPage({Key? key, required this.studentId}) : super(key: key);

  @override
  _StudentPageState createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  Map<String, dynamic>? student;
  List<dynamic> progressRecords = [];
  List<dynamic> packs = [];
  List<dynamic> lessons = [];
  Map<String, dynamic>? debtData;
  List<dynamic> debtItems = [];
  List<dynamic> parents = [];

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final results = await Future.wait([
        _fetchJson('/api/users/student/${widget.studentId}/'),
        _fetchJson('/api/users/student/${widget.studentId}/progress_records/'),
        _fetchJson('/api/users/student/${widget.studentId}/packs/'),
        _fetchJson('/api/users/student/${widget.studentId}/lessons/'),
        _fetchJson('/api/users/student/${widget.studentId}/debt/'),
        _fetchJson('/api/users/student/${widget.studentId}/parents/'),
      ]);

      setState(() {
        student         = results[0] as Map<String, dynamic>;
        progressRecords = results[1] as List<dynamic>;
        packs           = results[2] as List<dynamic>;
        lessons         = results[3] as List<dynamic>;

        debtData        = results[4] as Map<String, dynamic>;
        debtItems       = debtData!['items'] as List<dynamic>;

        parents         = results[5] as List<dynamic>;
        loading         = false;
      });
    } catch (e) {
      setState(() {
        error   = e.toString();
        loading = false;
      });
    }
  }

  Future<dynamic> _fetchJson(String path) async {
    final headers = await getAuthHeaders();
    final resp = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: headers,
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to load $path (${resp.statusCode})');
    }
    return json.decode(resp.body);
  }

  void _editProfile() {
    Navigator.pushNamed(context, '/student/${widget.studentId}/edit')
      .then((_) => _loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final lessonModal = Provider.of<LessonModalProvider>(context, listen: false);

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student')),
        body: Center(child: Text('Error: $error')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${student!['first_name']} ${student!['last_name']}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editProfile,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileCard(),
              const SizedBox(height: 16),

              _buildSectionTitle('Progress Records'),
              ...progressRecords.map(_buildProgressRecordCard),
              const SizedBox(height: 16),

              _buildSectionTitle('Packs'),
              ...packs.map((p) => PackCard(pack: p)),
              const SizedBox(height: 16),

              _buildSectionTitle('Lessons & Events'),
              ...lessons.map((l) => lessonModal.buildLessonCard(context, l, [])),
              const SizedBox(height: 16),

              _buildSectionTitle('Debts & Payments'),
              Text(
                'Total debt: €${debtData!['current_debt']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...debtItems.map(_buildDebtRow),
              const SizedBox(height: 16),

              _buildSectionTitle('Parents'),
              ...parents.map(_buildParentRow),
              const SizedBox(height: 16),

              _buildSectionTitle('Stats'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Stats will appear here...'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final photoUrl = student!['photo_url'] as String?;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${student!['first_name']} ${student!['last_name']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Birthday: ${DateFormat.yMMMMd().format(DateTime.parse(student!['birthday']))}',
                  ),
                  const SizedBox(height: 4),
                  Text('Level: ${student!['level']}'),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editProfile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium!
          .copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildProgressRecordCard(dynamic pr) {
    final date = DateTime.parse(pr['date']);
    final notes = pr['notes'] as String?;
    final goals = pr['goals'] as List<dynamic>;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        title: Text(DateFormat.yMMMd().format(date)),
        subtitle: (notes != null && notes.isNotEmpty)
            ? Text(notes, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        children: goals
            .map((g) => ListTile(
                  title: Text(g['skill_name']),
                  subtitle: Text(
                    'Level: ${g['level']}${g['is_completed'] ? ' ✅' : ''}'
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDebtRow(dynamic d) {
    // d has: pack_id, date, time, description, amount
    return ListTile(
      title: Text(d['description']),
      subtitle: Text('${d['date']} at ${d['time']}'),
      trailing: TextButton(
        child: Text('Pay €${d['amount']}'),
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/students/${widget.studentId}/pay',
            arguments: d['pack_id'],
          );
        },
      ),
    );
  }

  Widget _buildParentRow(dynamic p) {
    return ListTile(
      leading: const Icon(Icons.person),
      title: Text('${p['first_name']} ${p['last_name']}'),
      subtitle: Text(p['email'] ?? ''),
      trailing: IconButton(
        icon: const Icon(Icons.link_off),
        onPressed: () async {
          final resp = await http.delete(Uri.parse(
              '$baseUrl/api/users/student/${widget.studentId}/parents/${p['id']}/'));
          if (resp.statusCode == 204) _loadAll();
        },
      ),
    );
  }

  Widget _buildPackCard(dynamic pack) {
    final isGroup = pack['type'].toString().toLowerCase() == 'group';
    return InkWell(
      //onTap: () => _showPackCardOptions(pack),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 16),
              InkWell(
                onTap: () {
                  if (pack['type'].toString().toLowerCase() == 'group') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Scheduling Unavailable"),
                        content: const Text(
                            "To change the schedule of a group lesson, please contact the school."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"),
                          )
                        ],
                      ),
                    );
                  } else {
                    //_showScheduleMultipleLessonsModal(
                    //    pack['lessons'], pack["expiration_date"]);
                  }
                },
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.calendar_today,
                      size: 28, color: Colors.orange),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack['students_name'],
                      style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pack['lessons_remaining']} lessons remaining\n'
                      '${pack['unscheduled_lessons']} unscheduled lessons\n'
                      '${pack['days_until_expiration']} days until expiration',
                      style:
                          GoogleFonts.lato(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGroup ? Icons.groups : Icons.person,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      //showPackDetailsModal(pack);
                    },
                    child: const Icon(Icons.more_vert,
                        size: 28, color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

}
