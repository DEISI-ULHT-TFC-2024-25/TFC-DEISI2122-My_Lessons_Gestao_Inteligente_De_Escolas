import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/instructors_provider.dart';

class InstructorsModal extends StatelessWidget {
  final int? lessonId;
  final int? packId;
  final int? schoolId;

  const InstructorsModal({Key? key, this.lessonId, this.packId, this.schoolId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<InstructorsProvider>(
      create: (_) =>
          InstructorsProvider(lessonId: lessonId, packId: packId, schoolId: schoolId),
      child: Consumer<InstructorsProvider>(
        builder: (context, provider, child) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Wraps content height.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Select Instructor",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Search Bar.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: "Search Instructor",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      provider.updateSearchQuery(value);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // List of Instructors.
                provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.filteredInstructors.length,
                        itemBuilder: (context, index) {
                          final instructor = provider.filteredInstructors[index];
                          String fullName = instructor["name"] ?? "";
                          return Card(
                            margin:
                                const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: ListTile(
                              title: Text(fullName),
                              trailing: instructor["selected"] == true
                                  ? const Icon(Icons.check_circle, color: Colors.orange)
                                  : const Icon(Icons.arrow_forward, color: Colors.orange),
                              onTap: () =>
                                  provider.toggleInstructorSelection(instructor, context),
                            ),
                          );
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<dynamic> showInstructorsModal(BuildContext context,
    {int? lessonId, int? packId, int? schoolId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (BuildContext context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: InstructorsModal(
              lessonId: lessonId,
              packId: packId,
              schoolId: schoolId,
            ),
          );
        },
      );
    },
  );
}
