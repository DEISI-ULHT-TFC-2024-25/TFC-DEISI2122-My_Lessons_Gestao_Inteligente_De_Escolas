import 'package:flutter/material.dart';

import '../modals/students_modal.dart';
import '../pages/new_progress_record_page.dart';

Future<void> handleLessonReport(context, lesson) async {

    dynamic selectedStudent = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StudentsModal(
        lessonId: lesson["lesson_id"],
        manageProgress: true,
      ),
    );
    if (selectedStudent != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NewProgressRecordPage(
            student: selectedStudent,
            lesson: lesson,
          ),
        ),
      );
    }
  }