import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:http/http.dart' as http;
import 'package:mylessons_frontend/services/api_service.dart';

class ScheduleMultipleLessonsModal extends StatefulWidget {
  /// List of lessons. Each lesson must be a map with keys: "lesson_id" and "lesson_str"
  final List<dynamic> lessons;

  /// Callback to refresh the home page after scheduling is confirmed.
  final VoidCallback onScheduleConfirmed;
  final String currentRole;
  final int schoolScheduleTimeLimit;

  /// The expiration date as a string (yyyy-mm-dd) for parents - calendar will only allow dates until this date.
  final String expirationDate;

  const ScheduleMultipleLessonsModal({
    super.key,
    required this.lessons,
    required this.onScheduleConfirmed,
    required this.currentRole,
    required this.schoolScheduleTimeLimit,
    required this.expirationDate,
  });

  @override
  _ScheduleMultipleLessonsModalState createState() =>
      _ScheduleMultipleLessonsModalState();
}

class _ScheduleMultipleLessonsModalState
    extends State<ScheduleMultipleLessonsModal> {
  // Lesson selection: one boolean per lesson.
  late List<bool> selectedLessons;
  bool selectAll = false;

  // For single lesson scheduling (private scheduling):
  DateTime? singleSelectedDate;
  int singleIncrement = 60;
  List<String> singleAvailableTimes = [];
  bool singleIsLoading = false;

  // For multiple lessons scheduling:
  // Each block is a Map with:
  //   'from_date': DateTime?,
  //   'to_date': DateTime?,
  //   'options': List<Map<String, String>>
  List<Map<String, dynamic>> schedulingBlocks = [];

  // Parsed expiration date from widget.expirationDate (yyyy-mm-dd)
  late DateTime parsedExpirationDate;

  @override
  void initState() {
    super.initState();
    // Parse expiration date string into DateTime
    parsedExpirationDate = DateTime.parse(widget.expirationDate);

    selectedLessons = List.generate(widget.lessons.length, (_) => false);

    // Initialize with one default block for multiple lessons
    schedulingBlocks.add({
      'from_date': null,
      'to_date': null,
      'options': [
        {'weekday': 'Monday', 'time': '09:00'}
      ]
    });
  }

  void toggleSelectAll(bool? value) {
    setState(() {
      selectAll = value ?? false;
      for (int i = 0; i < selectedLessons.length; i++) {
        selectedLessons[i] = selectAll;
      }
    });
  }

  // ------------------- MULTIPLE LESSONS LOGIC ------------------- //

  void addSchedulingOption(int blockIndex) {
    setState(() {
      schedulingBlocks[blockIndex]['options'].add({
        'weekday': 'Monday',
        'time': '09:00',
      });
    });
  }

  void removeSchedulingOption(int blockIndex, int optionIndex) {
    setState(() {
      final opts = schedulingBlocks[blockIndex]['options'] as List;
      if (opts.length > 1) {
        opts.removeAt(optionIndex);
      }
    });
  }

  void addNewTimePeriod() {
    setState(() {
      schedulingBlocks.add({
        'from_date': null,
        'to_date': null,
        'options': [
          {'weekday': 'Monday', 'time': '09:00'}
        ]
      });
    });
  }

  /// Build payload for multiple lessons scheduling
  Map<String, dynamic> buildMultiplePayload() {
    // Gather selected lesson IDs
    final lessonIds = <String>[];
    for (int i = 0; i < widget.lessons.length; i++) {
      if (selectedLessons[i]) {
        lessonIds.add(widget.lessons[i]['lesson_id']);
      }
    }
    if (lessonIds.isEmpty) throw Exception('No lessons selected.');

    // Convert each block to from_date, to_date, options
    final blocks = <Map<String, dynamic>>[];
    for (var block in schedulingBlocks) {
      final from = block['from_date'] as DateTime?;
      final to = block['to_date'] as DateTime?;
      if (from == null || to == null) {
        throw Exception('Please select both From and To dates for each block.');
      }
      blocks.add({
        'from_date': DateFormat('yyyy-MM-dd').format(from),
        'to_date': DateFormat('yyyy-MM-dd').format(to),
        'options': block['options'],
      });
    }

    return {
      'lesson_ids': lessonIds,
      'Data': blocks,
      'schedule_flag': true, // Tells backend to actually schedule
    };
  }

  Future<void> _submitMultipleSchedule() async {
    try {
      final payload = buildMultiplePayload();
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/lessons/schedule_multiple_lessons/'),
        headers: {
          "Content-Type": "application/json",
          ...headers,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        // Show final confirmation dialog for multiple lessons
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Schedule Options"),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Here are the available options for your desired schedule!\nWould you wish to confirm?",
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(result.length, (index) {
                      final lesson = result[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          "${lesson['lesson_str']}\nNew Date: ${lesson['new_date']} at ${lesson['new_time']} (${lesson['weekday']})\nInstructor(s): ${lesson['instructors_str'].join(', ')}",
                          style: GoogleFonts.lato(fontSize: 14),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Dismiss
                  },
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Dismiss confirmation
                    Navigator.of(context).pop(); // Dismiss scheduling modal
                    widget.onScheduleConfirmed(); // Refresh home
                  },
                  child: const Text("Confirm"),
                ),
              ],
            );
          },
        );
      } else {
        throw Exception("Error scheduling lessons: ${response.statusCode}");
      }
    } catch (e) {
      // Show a warning popup if scheduling fails
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Warning"),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            )
          ],
        ),
      );
    }
  }

  // ------------------- SINGLE LESSON LOGIC ------------------- //

  /// Build payload for single lesson scheduling
  Map<String, dynamic> buildSinglePayload() {
    // Gather exactly one lesson ID
    final lessonIds = <String>[];
    for (int i = 0; i < widget.lessons.length; i++) {
      if (selectedLessons[i]) {
        lessonIds.add(widget.lessons[i]['lesson_id']);
      }
    }
    if (lessonIds.length != 1) {
      throw Exception('Exactly one lesson must be selected.');
    }
    if (singleSelectedDate == null) {
      throw Exception('No date selected.');
    }

    return {
      'lesson_id': lessonIds.first,
      'new_date': DateFormat('yyyy-MM-dd').format(singleSelectedDate!),
      'new_time': singleAvailableTimes.isNotEmpty
          ? singleAvailableTimes.first
          : '00:00', // fallback if user never picks a time
    };
  }

  Future<void> _submitSingleSchedule() async {
    // We skip the second confirmation popup for single lessons
    // (the user already saw the "Confirm Reschedule" alert).
    try {
      final payload = buildSinglePayload();
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/lessons/schedule_private_lesson/'),
        headers: {
          "Content-Type": "application/json",
          ...headers,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        // On success, close the scheduling modal and refresh home
        Navigator.of(context).pop(); // close the bottom sheet
        widget.onScheduleConfirmed();

        // Optionally show a success SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Lesson scheduled successfully!"),
          ),
        );
      } else {
        throw Exception("Error scheduling lesson: ${response.statusCode}");
      }
    } catch (e) {
      // Show a warning popup if scheduling fails
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Warning"),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            )
          ],
        ),
      );
    }
  }

  /// Single-lesson UI with a date picker + increments + available times
  Widget _buildSingleLessonUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select a Date',
            style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: SfDateRangePicker(
            initialDisplayDate: widget.currentRole == "Parent"
                ? DateTime.now().add(
                    Duration(hours: widget.schoolScheduleTimeLimit),
                  )
                : null,
            minDate: widget.currentRole == "Parent"
                ? DateTime.now().add(
                    Duration(hours: widget.schoolScheduleTimeLimit),
                  )
                : null,
            maxDate:
                widget.currentRole == "Parent" ? parsedExpirationDate : null,
            view: DateRangePickerView.month,
            selectionMode: DateRangePickerSelectionMode.single,
            onSelectionChanged: (args) {
              if (args.value is DateTime) {
                setState(() {
                  singleSelectedDate = args.value;
                  singleAvailableTimes = [];
                  singleIsLoading = true;
                });
                // Find the selected lesson id instead of hardcoding the first lesson
                final selectedIndex =
                    selectedLessons.indexWhere((isSelected) => isSelected);
                if (selectedIndex == -1) {
                  // Fallback or error handling if no lesson is selected.
                  return;
                }
                final lessonId =
                    int.parse(widget.lessons[selectedIndex]['lesson_id']);
                print("Lesson id: $lessonId");
                fetchAvailableTimes(
                        lessonId, singleSelectedDate!, singleIncrement)
                    .then((times) {
                  setState(() {
                    singleAvailableTimes = times;
                    singleIsLoading = false;
                  });
                });
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text("Increment: "),
            DropdownButton<int>(
              value: singleIncrement,
              items: [15, 30, 60].map((value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text("$value minutes"),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  setState(() {
                    singleIncrement = newValue;
                    if (singleSelectedDate != null) {
                      singleIsLoading = true;
                      singleAvailableTimes = [];
                    }
                  });
                  if (singleSelectedDate != null) {
                    final selectedIndex =
                        selectedLessons.indexWhere((isSelected) => isSelected);
                    if (selectedIndex == -1) {
                      // Handle error appropriately if no lesson is selected.
                      return;
                    }
                    final lessonId =
                        int.parse(widget.lessons[selectedIndex]['lesson_id']);
                    fetchAvailableTimes(
                            lessonId, singleSelectedDate!, singleIncrement)
                        .then((times) {
                      setState(() {
                        singleAvailableTimes = times;
                        singleIsLoading = false;
                      });
                    });
                  }
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (singleIsLoading)
          const CircularProgressIndicator()
        else if (singleAvailableTimes.isNotEmpty)
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
              itemCount: singleAvailableTimes.length,
              itemBuilder: (context, index) {
                final timeStr = singleAvailableTimes[index];
                return InkWell(
                  onTap: () {
                    // For single lessons, we show a small confirm alert,
                    // then schedule and skip any final confirm button.
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("Confirm Reschedule"),
                          content: Text(
                            "Reschedule lesson to ${DateFormat('d MMM yyyy').format(singleSelectedDate!).toLowerCase()} at $timeStr?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(); // close alert
                                // Schedule the lesson
                                singleAvailableTimes = [timeStr];
                                _submitSingleSchedule();
                              },
                              child: const Text("Confirm"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedLessons.where((e) => e).length;

    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Schedule Multiple Lessons',
                  style: GoogleFonts.lato(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // Lesson selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Lessons',
                      style: GoogleFonts.lato(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      const Text("Select All"),
                      Checkbox(value: selectAll, onChanged: toggleSelectAll),
                    ],
                  )
                ],
              ),
              ...List.generate(widget.lessons.length, (index) {
                return CheckboxListTile(
                  title: Text(widget.lessons[index]['lesson_str']),
                  value: selectedLessons[index],
                  onChanged: (bool? value) {
                    setState(() {
                      selectedLessons[index] = value ?? false;
                    });
                  },
                );
              }),
              const Divider(),
              // Single or multiple logic
              if (selectedCount == 1)
                _buildSingleLessonUI()
              else if (selectedCount > 1) ...[
                Text('Select Time Periods',
                    style: GoogleFonts.lato(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: schedulingBlocks.length,
                  itemBuilder: (context, blockIndex) {
                    final block = schedulingBlocks[blockIndex];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Time Period ${blockIndex + 1}",
                                style: GoogleFonts.lato(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      DateTime? picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: widget.currentRole == "Parent"
                                            ? parsedExpirationDate
                                            : DateTime.now()
                                                .add(const Duration(days: 365)),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          schedulingBlocks[blockIndex]
                                              ['from_date'] = picked;
                                        });
                                      }
                                    },
                                    child: Text(
                                      block['from_date'] == null
                                          ? 'From Date'
                                          : DateFormat('yyyy-MM-dd')
                                              .format(block['from_date']),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final initial =
                                          block['from_date'] ?? DateTime.now();
                                      DateTime? picked = await showDatePicker(
                                        context: context,
                                        initialDate: initial,
                                        firstDate: initial,
                                        lastDate: widget.currentRole == "Parent"
                                            ? parsedExpirationDate
                                            : DateTime.now()
                                                .add(const Duration(days: 365)),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          block['to_date'] = picked;
                                        });
                                      }
                                    },
                                    child: Text(
                                      block['to_date'] == null
                                          ? 'To Date'
                                          : DateFormat('yyyy-MM-dd')
                                              .format(block['to_date']),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Scheduling Options:',
                                style: GoogleFonts.lato(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...List.generate(
                              (block['options'] as List).length,
                              (optionIndex) {
                                final option = block['options'][optionIndex];
                                return Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButton<String>(
                                        value: option['weekday'],
                                        items: <String>[
                                          'Monday',
                                          'Tuesday',
                                          'Wednesday',
                                          'Thursday',
                                          'Friday',
                                          'Saturday',
                                          'Sunday'
                                        ]
                                            .map((day) => DropdownMenuItem(
                                                value: day, child: Text(day)))
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            option['weekday'] = value!;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: DropdownButton<String>(
                                        value: option['time'],
                                        items: <String>[
                                          '08:00',
                                          '09:00',
                                          '10:00',
                                          '11:00',
                                          '12:00',
                                          '13:00',
                                          '14:00',
                                          '15:00',
                                          '16:00',
                                          '17:00'
                                        ]
                                            .map((time) => DropdownMenuItem(
                                                value: time, child: Text(time)))
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            option['time'] = value!;
                                          });
                                        },
                                      ),
                                    ),
                                    if ((block['options'] as List).length > 1)
                                      IconButton(
                                        icon: const Icon(
                                            Icons.remove_circle_outline),
                                        onPressed: () => removeSchedulingOption(
                                            blockIndex, optionIndex),
                                      ),
                                  ],
                                );
                              },
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    addSchedulingOption(blockIndex),
                                child: const Text("Add Option"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: addNewTimePeriod,
                    child: const Text("Add New Time Period"),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Only show final Confirm button if more than one lesson is selected.
              if (selectedCount > 1)
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedLessons.where((e) => e).isEmpty) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Warning"),
                            content: const Text("No lessons selected."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text("OK"),
                              )
                            ],
                          ),
                        );
                        return;
                      }
                      await _submitMultipleSchedule();
                    },
                    child: const Text('Confirm'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
