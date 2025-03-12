import 'package:flutter/material.dart';

class LessonReportPage extends StatefulWidget {
  final dynamic lesson;
  final String mode; // 'view' for parents, 'edit' for instructors/admins

  const LessonReportPage({Key? key, required this.lesson, required this.mode}) : super(key: key);

  @override
  _LessonReportPageState createState() => _LessonReportPageState();
}

class _LessonReportPageState extends State<LessonReportPage> {
  String reportSummary = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Load the report for this lesson.
    _loadReport();
  }

  Future<void> _loadReport() async {
    // TODO: Implement your API call to load the lesson report.
    // For demonstration, we simulate a delay and set a sample summary.
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      reportSummary = "This is a sample report summary for lesson ${widget.lesson['id']}.";
      isLoading = false;
    });
  }

  Future<void> _saveReport() async {
    // TODO: Implement your API call to save/update the report.
    // For now, show a confirmation and navigate back.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Report saved successfully.")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    bool isEditMode = widget.mode == 'edit';
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? "Edit Lesson Report" : "View Lesson Report"),
        backgroundColor: Colors.orange,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: isEditMode
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Lesson Report for Lesson ${widget.lesson['id']}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: reportSummary,
                          maxLines: 10,
                          onChanged: (value) {
                            reportSummary = value;
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: "Report Summary",
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _saveReport,
                          child: const Text("Save Report"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Lesson Report for Lesson ${widget.lesson['id']}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(reportSummary),
                      ],
                    ),
            ),
    );
  }
}
