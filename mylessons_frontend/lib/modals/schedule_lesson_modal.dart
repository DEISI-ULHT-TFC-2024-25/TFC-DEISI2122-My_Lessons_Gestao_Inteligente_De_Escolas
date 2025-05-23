import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ScheduleLessonModal extends StatefulWidget {
  final int lessonId;
  final String expirationDate;
  final int schoolScheduleTimeLimit;
  final String currentRole;
  final Future<List<String>> Function(
      int lessonId, DateTime date, int increment) fetchAvailableTimes;
  final Future<String?> Function(int lessonId, DateTime newDate, String newTime)
      schedulePrivateLesson;
  final VoidCallback onScheduleConfirmed;

  const ScheduleLessonModal({
    Key? key,
    required this.lessonId,
    required this.expirationDate,
    required this.schoolScheduleTimeLimit,
    required this.currentRole,
    required this.fetchAvailableTimes,
    required this.schedulePrivateLesson,
    required this.onScheduleConfirmed,
  }) : super(key: key);

  @override
  _ScheduleLessonModalState createState() => _ScheduleLessonModalState();
}

class _ScheduleLessonModalState extends State<ScheduleLessonModal> {
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
  final now = DateTime.now();
  final initialDate = widget.currentRole == "Parent"
      ? now.add(Duration(hours: widget.schoolScheduleTimeLimit))
      : now;
  final firstDate = initialDate;

  // Parse expiration (or 1 year out if “None”)
  final parsedExp = widget.expirationDate != "None"
      ? DateTime.parse(widget.expirationDate)
      : now.add(const Duration(days: 365));

  // If the pack has already expired before firstDate, show popup and close.
  if (parsedExp.isBefore(firstDate)) {
    await showDialog(
      context: context,
      barrierDismissible: false, // force user to tap button
      builder: (ctx) => AlertDialog(
        title: const Text("Pack Expired"),
        content: const Text(
          "This lesson pack has expired and can no longer be scheduled.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();       // close dialog
              Navigator.of(context).pop();   // close modal
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
    return;
  }

  // Clamp lastDate to at least firstDate
  final lastDate = parsedExp.isBefore(firstDate) ? firstDate : parsedExp;

  // …now safe to show the date picker…
  final pickedDate = await showDatePicker(
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
    Navigator.of(context).pop();
  }
}

  Widget buildTimeSelection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row with a back button and the selected date.
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
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
              // Spacer to balance the row.
              const SizedBox(width: 48),
            ],
          ),
          // New increment selection using ToggleButtons.
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
          // Show a loading indicator if times are being fetched.
          if (isLoading) const CircularProgressIndicator(),
          // Grid view to display available times.
          if (!isLoading && availableTimes.isNotEmpty)
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
                      // Confirm reschedule dialog.
                      showDialog(
                        context: context,
                        barrierDismissible:
                            false, // Prevents dismiss by tapping outside
                        builder: (BuildContext dialogContext) {
                          return StatefulBuilder(
                            builder: (BuildContext dialogContext,
                                StateSetter setDialogState) {
                              return AlertDialog(
                                title: const Text("Confirm Reschedule"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isScheduling)
                                      const CircularProgressIndicator(
                                          color: Colors.orange)
                                    else
                                      Card(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        color: Colors.grey[100],
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            "Reschedule lesson to "
                                            "${DateFormat('d MMM yyyy').format(selectedDate!).toLowerCase()} "
                                            "at $timeStr?",
                                            style:
                                                GoogleFonts.lato(fontSize: 16),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: isScheduling
                                        ? null
                                        : () =>
                                            Navigator.of(dialogContext).pop(),
                                    child: Text("Cancel",
                                        style: GoogleFonts.lato(fontSize: 16)),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: isScheduling
                                        ? null
                                        : () {
                                            setDialogState(() {
                                              isScheduling = true;
                                            });
                                            widget
                                                .schedulePrivateLesson(
                                                    widget.lessonId,
                                                    selectedDate!,
                                                    timeStr)
                                                .then((errorMessage) {
                                              setDialogState(() {
                                                isScheduling = false;
                                              });
                                              if (errorMessage == null) {
                                                Navigator.of(dialogContext)
                                                    .pop();
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
                                                Navigator.of(dialogContext)
                                                    .pop();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content:
                                                          Text(errorMessage)),
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
                                        : Text("Confirm",
                                            style:
                                                GoogleFonts.lato(fontSize: 16)),
                                  ),
                                ],
                              );
                            },
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
            ),
          // Message when no times are available.
          if (!isLoading && availableTimes.isEmpty)
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
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: selectedDate != null
            ? buildTimeSelection()
            : const SizedBox.shrink(),
      ),
    );
  }
}
