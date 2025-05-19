import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:mylessons_frontend/services/api_service.dart';
import 'package:mylessons_frontend/providers/lessons_modal_provider.dart';
import 'package:provider/provider.dart';

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
      final paths = [
        '/api/users/student/${widget.studentId}/',
        '/api/users/student/${widget.studentId}/progress_records/',
        '/api/users/student/${widget.studentId}/packs/',
        '/api/users/student/${widget.studentId}/lessons/',
        '/api/users/student/${widget.studentId}/debt/',
        '/api/users/student/${widget.studentId}/parents/',
      ];
      final results = await Future.wait(paths.map(_fetchJson));

      setState(() {
        student         = results[0] as Map<String, dynamic>;
        progressRecords = results[1] as List<dynamic>;
        packs           = results[2] as List<dynamic>;
        lessons         = results[3] as List<dynamic>;
        debtData        = results[4] as Map<String, dynamic>;
        debtItems       = (debtData!['items'] is List)
            ? debtData!['items'] as List<dynamic>
            : [];
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
    final resp = await http.get(Uri.parse('$baseUrl$path'), headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load $path (${resp.statusCode})');
    }
    return json.decode(resp.body);
  }

  void _editProfile() {
    Navigator.pushNamed(context, '/student/${widget.studentId}/edit')
        .then((_) => _loadAll());
  }

  Widget _buildProfileCard() {
    final photoUrl   = _safeString('photo_url', student!['photo_url']);
    final birthRaw   = _safeString('birthday',  student!['birthday']);
    final birthday   = DateTime.tryParse(birthRaw);
    final levelValue = _safeString('level',      student!['level']);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          CircleAvatar(
            radius: 40,
            backgroundImage:
                photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child:
                photoUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_safeString('first_name', student!['first_name'])} '
                  '${_safeString('last_name',  student!['last_name'])}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                if (birthday != null)
                  Text('Birthday: ${DateFormat.yMMMMd().format(birthday)}'),
                const SizedBox(height: 4),
                Text('Level: $levelValue'),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.edit), onPressed: _editProfile),
        ]),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.orange),
        title: Text(title, style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }

  void _showModal(Widget body) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: body,
          ),
        ),
      ),
    );
  }

  void _showProgressModal() {
    _showModal(
      ListView.separated(
        shrinkWrap: true,
        itemCount: progressRecords.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, i) => _buildProgressRecordCard(progressRecords[i]),
      ),
    );
  }

  void _showPacksModal() {
    _showModal(
      ListView(
        shrinkWrap: true,
        children: packs.map((p) => PackCard(pack: p)).toList(),
      ),
    );
  }

  void _showLessonsModal() {
    final lessonModal = Provider.of<LessonModalProvider>(context, listen: false);
    final lessonsOnly = lessons.where((l) => l['is_event'] != true).toList();
    print(lessonsOnly);
    _showModal(
      ListView(
        shrinkWrap: true,
        children: lessonsOnly
            .map((l) => lessonModal.buildLessonCard(context, l, []))
            .toList(),
      ),
    );
  }

  void _showEventsModal() {
    final lessonModal = Provider.of<LessonModalProvider>(context, listen: false);
    final eventsOnly = lessons.where((l) => l['is_event'] == true).toList();
    _showModal(
      ListView(
        shrinkWrap: true,
        children: eventsOnly
            .map((l) => lessonModal.buildLessonCard(context, l, []))
            .toList(),
      ),
    );
  }

  void _showDebtsModal() {
    _showModal(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total debt: €${_safeString('current_debt', debtData!['current_debt'])}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...debtItems.map(_buildDebtRow),
        ],
      ),
    );
  }

  void _showParentsModal() {
    _showModal(
      ListView.separated(
        shrinkWrap: true,
        itemCount: parents.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, i) => _buildParentRow(parents[i]),
      ),
    );
  }

  void _showStatsModal() {
    _showModal(
      Container(
        padding: const EdgeInsets.all(16),
        child: const Text('Stats will appear here...'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          '${_safeString('first', student!['first_name'])} '
          '${_safeString('last',  student!['last_name'])}',
        ),
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

              _sectionCard(
                title: 'Progress Records',
                icon: Icons.track_changes,
                subtitle: 'View all progress records',
                onTap: _showProgressModal,
              ),
              const SizedBox(height: 8),

              _sectionCard(
                title: 'Packs',
                icon: Icons.inventory,
                subtitle: 'View all packs',
                onTap: _showPacksModal,
              ),
              const SizedBox(height: 8),

              _sectionCard(
                title: 'Lessons',
                icon: Icons.school,
                subtitle: 'View all lessons',
                onTap: _showLessonsModal,
              ),
              const SizedBox(height: 8),

              _sectionCard(
                title: 'Events',
                icon: Icons.event,
                subtitle: 'View all events',
                onTap: _showEventsModal,
              ),
              const SizedBox(height: 8),

              _sectionCard(
                title: 'Debts & Payments',
                icon: Icons.payment,
                subtitle: 'View debts and make payments',
                onTap: _showDebtsModal,
              ),
              const SizedBox(height: 8),

              _sectionCard(
                title: 'Parents',
                icon: Icons.people,
                subtitle: 'View and manage parents',
                onTap: _showParentsModal,
              ),
              const SizedBox(height: 8),

              _sectionCard(
                title: 'Stats',
                icon: Icons.bar_chart,
                subtitle: 'View student statistics',
                onTap: _showStatsModal,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressRecordCard(dynamic pr) {
    final dateRaw = _safeString('pr.date', pr['date']);
    final date    = DateTime.tryParse(dateRaw);
    final notes   = (pr['notes'] as String?) ?? '';
    final goals   = (pr['goals'] as List<dynamic>?) ?? [];

    return ExpansionTile(
      title: Text(date != null
          ? DateFormat.yMMMd().format(date)
          : 'Date unknown'),
      subtitle: notes.isNotEmpty
          ? Text(notes, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      children: goals.map<Widget>((g) {
        final skill = _safeString('g.skill_name', g['skill_name']);
        final level = _safeString('g.level',      g['level']);
        final done  = g['is_completed'] == true;
        return ListTile(
          title: Text(skill),
          subtitle: Text('Level: $level${done ? ' ✅' : ''}'),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildDebtRow(dynamic d) {
    final desc = _safeString('d.description', d['description']);
    final date = _safeString('d.date',        d['date']);
    final time = _safeString('d.time',        d['time']);
    final amt  = _safeString('d.amount',      d['amount']);

    return ListTile(
      title: Text(desc),
      subtitle: Text('$date at $time'),
      trailing: TextButton(
        child: Text('Pay €$amt'),
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
    final first = _safeString('p.first_name', p['first_name']);
    final last  = _safeString('p.last_name',  p['last_name']);
    final email = _safeString('p.email',      p['email']);

    return ListTile(
      leading: const Icon(Icons.person),
      title: Text('$first $last'),
      subtitle: Text(email),
      trailing: IconButton(
        icon: const Icon(Icons.link_off),
        onPressed: () async {
          final headers = await getAuthHeaders();
          final resp = await http.delete(
            Uri.parse(
                '$baseUrl/api/users/student/${widget.studentId}/parents/${p['id']}/'),
            headers: headers,
          );
          if (resp.statusCode == 204) _loadAll();
        },
      ),
    );
  }

  String _safeString(String label, dynamic v) {
    return v?.toString() ?? '';
  }

  Widget _buildPackCard(dynamic pack) {
    final isGroup = pack['type'].toString().toLowerCase() == 'group';
    return InkWell(
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
                  if (isGroup) {
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
                  }
                },
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.calendar_today, size: 28, color: Colors.orange),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack['students_name'],
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pack['lessons_remaining']} lessons remaining\n'
                      '${pack['unscheduled_lessons']} unscheduled lessons\n'
                      '${pack['days_until_expiration']} days until expiration',
                      style: GoogleFonts.lato(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isGroup ? Icons.groups : Icons.person, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Icon(Icons.more_vert, size: 28, color: Colors.orange),
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
