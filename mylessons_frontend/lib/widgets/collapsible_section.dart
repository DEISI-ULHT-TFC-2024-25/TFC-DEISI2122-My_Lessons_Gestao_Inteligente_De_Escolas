import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CollapsibleSection extends StatelessWidget {
  final String title;
  final Widget child;

  const CollapsibleSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        title,
        style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      // Start expanded by default.
      initiallyExpanded: true,
      // Remove borders/lines.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide.none,
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide.none,
      ),
      childrenPadding: EdgeInsets.zero,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [child],
    );
  }
}
