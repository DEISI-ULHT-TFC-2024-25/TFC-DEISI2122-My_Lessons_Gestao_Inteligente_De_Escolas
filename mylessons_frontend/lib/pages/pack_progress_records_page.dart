import 'package:flutter/material.dart';
import 'new_progress_record_page.dart';
import '../services/api_service.dart';

class PackProgressRecordsPage extends StatefulWidget {
  final dynamic pack;
  const PackProgressRecordsPage({Key? key, required this.pack}) : super(key: key);

  @override
  _PackProgressRecordsPageState createState() => _PackProgressRecordsPageState();
}

class _PackProgressRecordsPageState extends State<PackProgressRecordsPage> {
  bool _isLoading = false;
  // Assuming the pack object has 'students' and 'lessons' keys.
  late List<dynamic> students;
  late List<dynamic> lessons;
  // Map to store progress records with key as "studentId-lessonId"
  Map<String, dynamic> progressRecords = {};
  // Track expansion state for each student (by student id)
  Map<int, bool> expandedStudents = {};

  @override
  void initState() {
    super.initState();
    students = widget.pack['students'] ?? [];
    lessons = widget.pack['lessons'] ?? [];
    print(lessons);
    print(students);
    for (var student in students) {
      // Convert student id to int in case it's a string.
      int studentId = int.parse(student['id'].toString());
      expandedStudents[studentId] = false;
    }
    fetchAllProgressRecords();
  }

  /// For each student and each lesson, fetch the progress record (if any).
  Future<void> fetchAllProgressRecords() async {
    setState(() {
      _isLoading = true;
      progressRecords.clear();
    });
    try {
      for (var student in students) {
        int studentId = int.parse(student['id'].toString());
        for (var lesson in lessons) {
          // Convert lesson id to int from either 'lesson_id' or 'id'.
          int lessonId = int.parse((lesson['lesson_id'] ?? lesson['id']).toString());
          try {
            var record = await getProgressRecord(studentId, lessonId);
            progressRecords["$studentId-$lessonId"] = record;
          } catch (e) {
            progressRecords["$studentId-$lessonId"] = null;
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching progress records: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Refresh a single progress record after returning from the NewProgressRecordPage.
  Future<void> refreshRecord(int studentId, int lessonId) async {
    try {
      var record = await getProgressRecord(studentId, lessonId);
      setState(() {
        progressRecords["$studentId-$lessonId"] = record;
      });
    } catch (e) {
      // Optionally, handle the error.
    }
  }

  /// Builds a card for a single lesson’s progress record for a student.
  Widget buildLessonRecordCard(dynamic student, dynamic lesson) {
    int studentId = int.parse(student['id'].toString());
    int lessonId = int.parse((lesson['lesson_id'] ?? lesson['id']).toString());
    var record = progressRecords["$studentId-$lessonId"];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(lesson['title'] ?? "Lesson $lessonId"),
        subtitle: record != null 
            ? Text("Record exists – Notes: ${record['notes'] ?? ''}")
            : const Text("No progress record"),
        trailing: const Icon(Icons.arrow_forward, color: Colors.orange),
        onTap: () async {
          // Navigate to the NewProgressRecordPage to create/update the record.
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewProgressRecordPage(student: student, lesson: lesson),
            ),
          );
          // Refresh this specific record when returning.
          await refreshRecord(studentId, lessonId);
        },
      ),
    );
  }

  /// Builds an expansion panel for a single student.
  ExpansionPanel buildStudentPanel(dynamic student) {
    int studentId = int.parse(student['id'].toString());
    List<Widget> lessonCards = lessons.map((lesson) => buildLessonRecordCard(student, lesson)).toList();
    return ExpansionPanel(
      headerBuilder: (context, isExpanded) {
        return ListTile(
          title: Text(student['name'] ?? "Student $studentId"),
        );
      },
      body: Column(children: lessonCards),
      isExpanded: expandedStudents[studentId] ?? false,
      canTapOnHeader: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pack Progress Records"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ExpansionPanelList(
                expansionCallback: (index, isExpanded) {
                  setState(() {
                    int studentId = int.parse(students[index]['id'].toString());
                    expandedStudents[studentId] = !isExpanded;
                  });
                },
                children: students.map((student) => buildStudentPanel(student)).toList(),
              ),
            ),
    );
  }
}
