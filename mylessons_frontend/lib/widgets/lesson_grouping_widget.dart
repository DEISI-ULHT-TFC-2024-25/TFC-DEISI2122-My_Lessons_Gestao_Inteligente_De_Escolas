import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Widget buildGroupedLessonCard(String groupTitle, Color groupColor, List<Widget> lessonCards) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with colored background and title.
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: groupColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Text(
            groupTitle,
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        // Body containing lesson cards.
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: lessonCards,
          ),
        ),
      ],
    ),
  );
}


