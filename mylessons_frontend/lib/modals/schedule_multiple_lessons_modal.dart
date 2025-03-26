import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:mylessons_frontend/services/api_service.dart';

class ScheduleMultipleLessonsModal extends StatefulWidget {
  final List<dynamic> lessons;
  final List<String> unschedulableLessons;
  final VoidCallback onScheduleConfirmed;
  final String currentRole;
  final int schoolScheduleTimeLimit;
  final String expirationDate;

  const ScheduleMultipleLessonsModal({
    super.key,
    required this.lessons,
    required this.onScheduleConfirmed,
    required this.currentRole,
    required this.schoolScheduleTimeLimit,
    required this.expirationDate,
    required this.unschedulableLessons,
  });

  @override
  _ScheduleMultipleLessonsModalState createState() =>
      _ScheduleMultipleLessonsModalState();
}

class _ScheduleMultipleLessonsModalState
    extends State<ScheduleMultipleLessonsModal> with TickerProviderStateMixin {
  // Controls which step is shown: 0 = lesson selection, 1 = scheduling details.
  int _currentStep = 0;

  // Lesson selection: one boolean per lesson.
  late List<bool> selectedLessons;
  bool selectAll = false;

  // Single lesson scheduling state (for when exactly one lesson is selected).
  DateTime? singleSelectedDate;
  int singleIncrement = 60;
  List<String> singleAvailableTimes = [];
  bool singleIsLoading = false;
  bool singleIsScheduling = false;

  // For multiple lessons scheduling:
  // Each block now includes a boolean flag to indicate whether to use a custom time period.
  List<Map<String, dynamic>> schedulingBlocks = [];

  // Parsed expiration date from widget.expirationDate (yyyy-mm-dd)
  late DateTime parsedExpirationDate;

  @override
  void initState() {
    super.initState();
    parsedExpirationDate = DateTime.parse(widget.expirationDate);
    selectedLessons = List.generate(widget.lessons.length, (_) => false);

    // Initialize with one default scheduling block (for multiple lessons).
    schedulingBlocks.add({
      'select_time_period': false,
      'from_date': null,
      'to_date': null,
      'options': [
        {'weekday': 'Monday', 'time': '09:00'}
      ]
    });
  }

  // ------------------ STEP 1: Lesson Selection ------------------ //

  Widget buildLessonSelectionStep() {
    return Column(
      key: const ValueKey<int>(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bigger heading for lesson selection.
        Text(
          'Select Lessons',
          style: GoogleFonts.lato(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text("Select All"),
            Checkbox(value: selectAll, onChanged: toggleSelectAll),
          ],
        ),
        ...List.generate(widget.lessons.length, (index) {
          final lessonId = widget.lessons[index]['lesson_id'];
          final isUnschedulable =
              widget.unschedulableLessons.contains(lessonId);
          return CheckboxListTile(
            title: Text(widget.lessons[index]['lesson_str']),
            value: selectedLessons[index],
            onChanged: isUnschedulable
                ? null
                : (bool? value) {
                    setState(() {
                      selectedLessons[index] = value ?? false;
                    });
                  },
            secondary: isUnschedulable ? const Icon(Icons.block) : null,
          );
        }),
      ],
    );
  }

  void toggleSelectAll(bool? value) {
    setState(() {
      selectAll = value ?? false;
      for (int i = 0; i < selectedLessons.length; i++) {
        final lessonId = widget.lessons[i]['lesson_id'];
        if (!widget.unschedulableLessons.contains(lessonId)) {
          selectedLessons[i] = selectAll;
        }
      }
    });
  }

  // ------------------ SINGLE LESSON SCHEDULING ------------------ //

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
        singleSelectedDate = pickedDate;
        singleIsLoading = true;
        singleAvailableTimes = [];
      });
      final selectedIndex = selectedLessons.indexWhere((e) => e);
      if (selectedIndex == -1) return;
      final lessonId = int.parse(widget.lessons[selectedIndex]['lesson_id']);
      fetchAvailableTimes(lessonId, singleSelectedDate!, singleIncrement)
          .then((times) {
        setState(() {
          singleAvailableTimes = times;
          singleIsLoading = false;
        });
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget buildTimeSelection() {
    if (singleSelectedDate == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openDatePicker();
      });
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: const ValueKey<int>(1),
        width: double.infinity,
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with orange back icon and heading.
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.orange),
                  onPressed: () {
                    setState(() {
                      _currentStep = 0;
                    });
                  },
                ),
                Text(
                  singleSelectedDate != null
                      ? DateFormat('d MMM yyyy').format(singleSelectedDate!)
                      : "",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
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
                      singleIncrement == 15,
                      singleIncrement == 30,
                      singleIncrement == 60
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
                        singleIncrement = newValue;
                        if (singleSelectedDate != null) {
                          singleIsLoading = true;
                          singleAvailableTimes = [];
                        }
                      });
                      if (singleSelectedDate != null) {
                        final selectedIndex =
                            selectedLessons.indexWhere((e) => e);
                        if (selectedIndex == -1) return;
                        final lessonId = int.parse(
                            widget.lessons[selectedIndex]['lesson_id']);
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
            if (singleIsLoading) const CircularProgressIndicator(),
            if (!singleIsLoading && singleAvailableTimes.isNotEmpty)
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
                    String timeStr = singleAvailableTimes[index];
                    return InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return StatefulBuilder(
                              builder: (BuildContext dialogContext,
                                  StateSetter setDialogState) {
                                return AlertDialog(
                                  title: const Text("Confirm Reschedule"),
                                  content: SizedBox(
                                    height: 80,
                                    child: Center(
                                      child: singleIsScheduling
                                          ? const CircularProgressIndicator()
                                          : Text(
                                              "Reschedule lesson to ${DateFormat('d MMM yyyy').format(singleSelectedDate!).toLowerCase()} at $timeStr?",
                                            ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: singleIsScheduling
                                          ? null
                                          : () =>
                                              Navigator.of(dialogContext).pop(),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: singleIsScheduling
                                          ? null
                                          : () {
                                              setDialogState(() {
                                                singleIsScheduling = true;
                                              });
                                              _submitSingleSchedule().then((_) {
                                                setDialogState(() {
                                                  singleIsScheduling = false;
                                                });
                                              });
                                            },
                                      child: singleIsScheduling
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : const Text("Confirm"),
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
            if (!singleIsLoading && singleAvailableTimes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("No available times for the selected date."),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ------------------ MULTIPLE LESSONS SCHEDULING ------------------ //

  Widget buildMultipleLessonsUI() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: const ValueKey<int>(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with back icon and heading.
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.orange),
                  onPressed: () {
                    setState(() {
                      _currentStep = 0;
                    });
                  },
                ),
                Text(
                  'Select Time Periods',
                  style: GoogleFonts.lato(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
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
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          title: const Text(
                            "Custom Time Period",
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          activeColor: Colors.orange,
                          value: block['select_time_period'] ?? false,
                          onChanged: (val) {
                            setState(() {
                              block['select_time_period'] = val;
                            });
                          },
                        ),
                        if (block['select_time_period'] ?? false) ...[
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
                                        block['from_date'] = picked;
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.orange,
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    minimumSize: const Size(80, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                  ),
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
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.orange,
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    minimumSize: const Size(80, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                  ),
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
                        ],
                        const SizedBox(height: 8),
                        ...List.generate(
                          (block['options'] as List).length,
                          (optionIndex) {
                            final option = block['options'][optionIndex];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _showWeekdayPicker(
                                          blockIndex, optionIndex),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.orange),
                                          borderRadius:
                                              BorderRadius.circular(32),
                                        ),
                                        child: Text(
                                          option['weekday'],
                                          style: const TextStyle(fontSize: 16),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _showTimePicker(
                                          blockIndex, optionIndex),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.orange),
                                          borderRadius:
                                              BorderRadius.circular(32),
                                        ),
                                        child: Text(
                                          option['time'],
                                          style: const TextStyle(fontSize: 16),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
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
                              ),
                            );
                          },
                        ),
                        // Row with left-aligned "Add Option" and right-aligned delete icon.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.orange),
                              onPressed: () => addSchedulingOption(blockIndex),
                              child: const Text("+ Add Option"),
                            ),
                            if (schedulingBlocks.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                color: Colors.red,
                                onPressed: () =>
                                    removeSchedulingBlock(blockIndex),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // "Add New Time Period" button aligned to the left.
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 8),
              child: Center(
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  onPressed: addNewTimePeriod,
                  child: const Text("+ Add New Time Period"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWeekdayPicker(int blockIndex, int optionIndex) async {
    final weekdays = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday"
    ];
    int selectedIndex = weekdays.indexOf(
        schedulingBlocks[blockIndex]['options'][optionIndex]['weekday']);

    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        height: 250,
        child: CupertinoPicker(
          magnification: 1.2,
          squeeze: 1.0,
          itemExtent: 50,
          scrollController:
              FixedExtentScrollController(initialItem: selectedIndex),
          onSelectedItemChanged: (int index) {
            selectedIndex = index;
          },
          children: weekdays
              .map((d) => Center(
                    child: Text(d, style: const TextStyle(fontSize: 18)),
                  ))
              .toList(),
        ),
      ),
    );

    setState(() {
      schedulingBlocks[blockIndex]['options'][optionIndex]['weekday'] =
          weekdays[selectedIndex];
    });
  }

  Future<void> _showTimePicker(int blockIndex, int optionIndex) async {
    final hours =
        List.generate(24, (index) => index.toString().padLeft(2, '0'));
    final minutes =
        List.generate(60, (index) => index.toString().padLeft(2, '0'));
    List<String> parts =
        schedulingBlocks[blockIndex]['options'][optionIndex]['time'].split(":");
    int selectedHour = int.parse(parts[0]);
    int selectedMinute = int.parse(parts[1]);

    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        height: 300,
        child: Row(
          children: [
            Expanded(
              child: CupertinoPicker(
                magnification: 1.2,
                squeeze: 1.0,
                itemExtent: 50,
                scrollController:
                    FixedExtentScrollController(initialItem: selectedHour),
                onSelectedItemChanged: (int index) {
                  selectedHour = index;
                },
                children: hours
                    .map((h) => Center(
                          child: Text(h, style: const TextStyle(fontSize: 18)),
                        ))
                    .toList(),
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                magnification: 1.2,
                squeeze: 1.0,
                itemExtent: 50,
                scrollController:
                    FixedExtentScrollController(initialItem: selectedMinute),
                onSelectedItemChanged: (int index) {
                  selectedMinute = index;
                },
                children: minutes
                    .map((m) => Center(
                          child: Text(m, style: const TextStyle(fontSize: 18)),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );

    setState(() {
      schedulingBlocks[blockIndex]['options'][optionIndex]['time'] =
          '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}';
    });
  }

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
        'select_time_period': false,
        'from_date': null,
        'to_date': null,
        'options': [
          {'weekday': 'Monday', 'time': '09:00'}
        ]
      });
    });
  }

  void removeSchedulingBlock(int blockIndex) {
    setState(() {
      if (schedulingBlocks.length > 1) {
        schedulingBlocks.removeAt(blockIndex);
      }
    });
  }

  /// Decide which scheduling UI to show based on the number of selected lessons.
  Widget buildSchedulingStep() {
    final selectedCount = selectedLessons.where((e) => e).length;
    if (selectedCount == 1) {
      return buildTimeSelection();
    } else if (selectedCount > 1) {
      return buildMultipleLessonsUI();
    }
    return const SizedBox.shrink();
  }

  // ------------------ PAYLOAD BUILDING AND SUBMISSION ------------------ //

  Map<String, dynamic> buildMultiplePayload() {
    final lessonIds = <String>[];
    for (int i = 0; i < widget.lessons.length; i++) {
      if (selectedLessons[i]) {
        lessonIds.add(widget.lessons[i]['lesson_id']);
      }
    }
    if (lessonIds.isEmpty) throw Exception('No lessons selected.');

    final blocks = <Map<String, dynamic>>[];
    for (var block in schedulingBlocks) {
      bool useCustom = block['select_time_period'] ?? false;
      DateTime fromDate = useCustom && block['from_date'] != null
          ? block['from_date'] as DateTime
          : DateTime.now();
      DateTime toDate = useCustom && block['to_date'] != null
          ? block['to_date'] as DateTime
          : parsedExpirationDate;

      blocks.add({
        'from_date': DateFormat('yyyy-MM-dd').format(fromDate),
        'to_date': DateFormat('yyyy-MM-dd').format(toDate),
        'options': block['options'],
      });
    }

    return {
      'lesson_ids': lessonIds,
      'Data': blocks,
      'schedule_flag': true,
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
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Schedule Options"),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Each scheduling option is displayed as its own card.
                    ...List.generate(result.length, (index) {
                      final lesson = result[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.grey[100],
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            "${lesson['lesson_str']}\nNew Date: ${lesson['new_date']} at ${lesson['new_time']} (${lesson['weekday']})\nInstructor(s): ${lesson['instructors_str'].join(', ')}",
                            style: GoogleFonts.lato(fontSize: 14),
                          ),
                        ),
                      );
                    }),
                    // Optionally, you could also add a final Card with a confirmation question if needed.
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                    widget.onScheduleConfirmed();
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

  Future<void> _submitSingleSchedule() async {
    try {
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
      final payload = {
        'lesson_id': lessonIds.first,
        'new_date': DateFormat('yyyy-MM-dd').format(singleSelectedDate!),
        'new_time': singleAvailableTimes.isNotEmpty
            ? singleAvailableTimes.first
            : '00:00',
      };
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
        Navigator.of(context).pop();
        widget.onScheduleConfirmed();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Lesson scheduled successfully!"),
          ),
        );
      } else {
        throw Exception("Error scheduling lesson: ${response.statusCode}");
      }
    } catch (e) {
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

  // ------------------ BUILD METHOD: MODAL WITH HEIGHT ANIMATION ------------------ //

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    bool showNextButton = selectedLessons.any((e) => e);
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: _currentStep == 0
                      ? buildLessonSelectionStep()
                      : buildSchedulingStep(),
                ),
              ),
            ),
            if (showNextButton)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentStep == 0) {
                          setState(() {
                            _currentStep = 1;
                          });
                        } else if (_currentStep == 1) {
                          final selectedCount =
                              selectedLessons.where((e) => e).length;
                          if (selectedCount == 1) {
                            _submitSingleSchedule();
                          } else if (selectedCount > 1) {
                            _submitMultipleSchedule();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.orange,
                        minimumSize: const Size(150, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      child: Text(_currentStep == 0 ? "Next" : "Submit"),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
