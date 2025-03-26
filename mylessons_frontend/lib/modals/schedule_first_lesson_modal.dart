import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ScheduleFirstLessonModal extends StatefulWidget {
  final int lessonId;
  final String expirationDate;
  final int schoolScheduleTimeLimit;
  final String currentRole;
  final Future<List<String>> Function(
      int lessonId, DateTime date, int increment) fetchAvailableTimes;
  final Future<String?> Function(int lessonId, DateTime newDate, String newTime)
      schedulePrivateLesson;
  final VoidCallback onScheduleConfirmed;
  // Checkout item for display in the header.
  final Map<String, dynamic> checkoutItem;

  const ScheduleFirstLessonModal({
    Key? key,
    required this.lessonId,
    required this.expirationDate,
    required this.schoolScheduleTimeLimit,
    required this.currentRole,
    required this.fetchAvailableTimes,
    required this.schedulePrivateLesson,
    required this.onScheduleConfirmed,
    required this.checkoutItem,
  }) : super(key: key);

  @override
  _ScheduleFirstLessonModalState createState() =>
      _ScheduleFirstLessonModalState();
}

class _ScheduleFirstLessonModalState extends State<ScheduleFirstLessonModal> {
  DateTime? selectedDate;
  int increment = 60;
  List<String> availableTimes = [];
  bool isLoading = false;
  bool isScheduling = false;

  @override
  void initState() {
    super.initState();
    // Automatically open the date picker when the modal appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openDatePicker();
    });
  }

  Future<void> _openDatePicker() async {
    DateTime now = DateTime.now();
    DateTime initialDate = widget.currentRole == "Parent"
        ? now.add(Duration(hours: widget.schoolScheduleTimeLimit))
        : now;
    DateTime firstDate = initialDate;
    DateTime lastDate = widget.expirationDate != "None"
        ? DateTime.parse(widget.expirationDate)
        : now.add(const Duration(days: 365));

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
        isLoading = true;
        availableTimes = [];
      });
      widget
          .fetchAvailableTimes(widget.lessonId, selectedDate!, increment)
          .then((times) {
        setState(() {
          availableTimes = times;
          isLoading = false;
        });
      });
    } else {
      // If no date is picked, close the modal.
      Navigator.of(context).pop();
    }
  }

  /// Builds the header section with the title and a checkout card.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Schedule The First Lesson",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildCheckoutCard(widget.checkoutItem),
          const Divider(),
        ],
      ),
    );
  }

  /// Builds a checkout card (you can customize this as needed).
  Widget _buildCheckoutCard(Map<String, dynamic> checkoutItem) {
    // For example, show the service name, school name, duration, etc.
    final service = checkoutItem['service'] as Map<String, dynamic>? ?? {};
    final checkoutDetails =
        service['checkout_details'] as Map<String, dynamic>? ?? {};
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${checkoutDetails['service_name'] ?? 'N/A'} - ${checkoutDetails['school_name'] ?? 'N/A'}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Text("Duration: ${checkoutDetails['duration'] ?? 'N/A'} minutes"),
            Text("Classes: ${checkoutDetails['classes'] ?? 'N/A'}"),
            Text("Students: ${checkoutDetails['number_of_students'] ?? 'N/A'}"),
            const SizedBox(height: 4),
            if (checkoutDetails['student_names'] is List)
              ...List<String>.from(checkoutDetails['student_names'])
                  .map((name) => Text("    - $name")),
            const SizedBox(height: 4),
            Text("Time Limit: ${checkoutDetails['time_limit'] ?? 'N/A'} days"),
            Text("Price: ${checkoutDetails['formatted_price'] ?? 'N/A'}"),
          ],
        ),
      ),
    );
  }

  /// Builds the time selection part (step 2), exactly like in your schedule private lesson modal.
  Widget buildTimeSelection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row with a back button (to reopen the date picker) and the selected date.
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.orange),
                onPressed: _openDatePicker,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    selectedDate != null
                        ? DateFormat('d MMM yyyy').format(selectedDate!)
                        : "",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          // Increment selection using ToggleButtons.
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ToggleButtons(
                  borderRadius: BorderRadius.circular(8),
                  isSelected: [
                    increment == 15,
                    increment == 30,
                    increment == 60
                  ],
                  onPressed: (int index) {
                    int newValue;
                    if (index == 0) {
                      newValue = 15;
                    } else if (index == 1) {
                      newValue = 30;
                    } else {
                      newValue = 60;
                    }
                    setState(() {
                      increment = newValue;
                      if (selectedDate != null) {
                        isLoading = true;
                        availableTimes = [];
                      }
                    });
                    if (selectedDate != null) {
                      widget
                          .fetchAvailableTimes(
                              widget.lessonId, selectedDate!, increment)
                          .then((times) {
                        setState(() {
                          availableTimes = times;
                          isLoading = false;
                        });
                      });
                    }
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text("15 min"),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text("30 min"),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text("60 min"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isLoading)
            const CircularProgressIndicator()
          else if (availableTimes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: availableTimes.length,
                itemBuilder: (context, index) {
                  String timeStr = availableTimes[index];
                  return InkWell(
                    onTap: () {
                      // Show a confirmation dialog.
                      showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            title: const Text("Confirm Reschedule"),
                            content: SizedBox(
                              height: 100,
                              child: Center(
                                child: isScheduling
                                    ? const CircularProgressIndicator(
                                        color: Colors.orange)
                                    : Card(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        color: Colors.grey[100],
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Text(
                                            "Schedule lesson to ${DateFormat('d MMM yyyy').format(selectedDate!).toLowerCase()} at $timeStr?",
                                            style:
                                                GoogleFonts.lato(fontSize: 16),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: isScheduling
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: isScheduling
                                    ? null
                                    : () {
                                        Navigator.of(dialogContext)
                                            .pop(); // Close the dialog
                                        setState(() {
                                          isScheduling = true;
                                        });
                                        widget
                                            .schedulePrivateLesson(
                                                widget.lessonId,
                                                selectedDate!,
                                                timeStr)
                                            .then((errorMessage) {
                                          setState(() {
                                            isScheduling = false;
                                          });
                                          if (errorMessage == null) {
                                            Navigator.of(context).pop();
                                            widget.onScheduleConfirmed();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    "Lesson successfully scheduled"),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(errorMessage)),
                                            );
                                          }
                                        });
                                      },
                                child: isScheduling
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text("Confirm"),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("No available times for the selected date."),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The modal is built as a scrollable view containing a header and the time selection
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            // If a date has been selected, show the time selection grid.
            if (selectedDate != null) buildTimeSelection(),
          ],
        ),
      ),
    );
  }
}
