import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services/api_service.dart';
// import 'package:http/http.dart' as http;
// import '../services/api_service.dart'; // Provides baseUrl & getAuthHeaders()

class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({Key? key}) : super(key: key);

  @override
  _AvailabilityPageState createState() => _AvailabilityPageState();
}

/// Model for single-day availability: a date with a list of time ranges.
class SingleDayAvailability {
  DateTime date;
  List<_TimeRange> ranges;
  SingleDayAvailability({required this.date, List<_TimeRange>? ranges})
      : ranges = ranges ?? [_TimeRange()];
}

/// Model for Approach A (Day→Times): each day has multiple time ranges.
class DayWithTimes {
  String day; // e.g., "monday"
  List<_TimeRange> ranges;
  DayWithTimes({required this.day, List<_TimeRange>? ranges})
      : ranges = ranges ?? [_TimeRange()];
}

/// Model for Approach B (TimeRange→Days): each time range can have multiple days.
class TimeRangeWithDays {
  TimeOfDay? start;
  TimeOfDay? end;
  Set<String> days;
  TimeRangeWithDays({this.start, this.end, Set<String>? days})
      : days = days ?? {};
}

/// Basic time range with start and end TimeOfDay.
class _TimeRange {
  TimeOfDay? start;
  TimeOfDay? end;
}

class _AvailabilityPageState extends State<AvailabilityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ---------- SINGLE DAY MODE ----------
  final List<SingleDayAvailability> _singleDayItems = [
    SingleDayAvailability(date: DateTime.now()),
  ];

  // ---------- DATE INTERVAL MODE ----------
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(const Duration(days: 7));
  // Toggle to choose between two approaches in date interval mode:
  // true => Approach A: Day→Times, false => Approach B: TimeRange→Days.
  bool _useDayTimesApproach = true;
  // Approach A: list of days with their time ranges.
  final List<DayWithTimes> _daysList = [];
  // Approach B: list of time ranges where each holds its set of days.
  final List<TimeRangeWithDays> _rangeList = [TimeRangeWithDays()];

  // List of all weekdays.
  final List<String> _allDays = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --------------------- TIME & DATE PICKERS ---------------------
  Future<void> _pickTime(
      BuildContext context, bool isStart, _TimeRange range) async {
    final TimeOfDay initial = isStart
        ? (range.start ?? const TimeOfDay(hour: 9, minute: 0))
        : (range.end ?? const TimeOfDay(hour: 18, minute: 0));
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          range.start = picked;
        else
          range.end = picked;
      });
    }
  }

  Future<void> _pickTimeWithDays(
      BuildContext context, bool isStart, TimeRangeWithDays tr) async {
    final TimeOfDay initial = isStart
        ? (tr.start ?? const TimeOfDay(hour: 9, minute: 0))
        : (tr.end ?? const TimeOfDay(hour: 18, minute: 0));
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          tr.start = picked;
        else
          tr.end = picked;
      });
    }
  }

  Future<void> _pickSingleDayDate(SingleDayAvailability item) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: item.date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        item.date = picked;
      });
    }
  }

  Future<void> _pickFromDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_toDate.isBefore(picked)) {
          _toDate = picked.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
      });
    }
  }

  // --------------------- SINGLE DAY LOGIC ---------------------
  void _addNewSingleDay() {
    setState(() {
      _singleDayItems.add(SingleDayAvailability(date: DateTime.now()));
    });
  }

  void _removeSingleDayItem(int index) {
    setState(() {
      _singleDayItems.removeAt(index);
    });
  }

  void _addNewTimeRangeSingleDay(SingleDayAvailability item) {
    setState(() {
      item.ranges.add(_TimeRange());
    });
  }

  void _removeTimeRangeSingleDay(SingleDayAvailability item, int index) {
    setState(() {
      item.ranges.removeAt(index);
    });
  }

  // --------------------- DATE INTERVAL LOGIC ---------------------
  // Approach A: Day→Times
  void _toggleDayInList(String day) {
    final existingIndex = _daysList.indexWhere((d) => d.day == day);
    setState(() {
      if (existingIndex >= 0) {
        _daysList.removeAt(existingIndex);
      } else {
        _daysList.add(DayWithTimes(day: day));
      }
    });
  }

  void _addTimeRangeToDay(DayWithTimes day) {
    setState(() {
      day.ranges.add(_TimeRange());
    });
  }

  void _removeTimeRangeFromDay(DayWithTimes day, int idx) {
    setState(() {
      day.ranges.removeAt(idx);
      if (day.ranges.isEmpty) {
        _daysList.remove(day);
      }
    });
  }

  void _removeDay(DayWithTimes day) {
    setState(() {
      _daysList.remove(day);
    });
  }

  // Approach B: TimeRange→Days
  void _addTimeRangeWithDays() {
    setState(() {
      _rangeList.add(TimeRangeWithDays());
    });
  }

  void _removeTimeRangeWithDays(int index) {
    setState(() {
      _rangeList.removeAt(index);
    });
  }

  void _toggleDayInTimeRange(TimeRangeWithDays tr, String day) {
    setState(() {
      if (tr.days.contains(day)) {
        tr.days.remove(day);
      } else {
        tr.days.add(day);
      }
    });
  }

  // --------------------- SUBMISSION ---------------------
  String _formatTime(TimeOfDay? tod) {
    if (tod == null) return "--:--";
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat('HH:mm').format(dt);
  }

  Future<void> _submitDefinition(bool isUnavailability) async {
    setState(() => _isSubmitting = true);
    final currentTabIndex = _tabController.index;
    Map<String, dynamic> payload = {};

    if (currentTabIndex == 0) {
      // Single Day payload
      final items = _singleDayItems.map((item) {
        final dateStr = DateFormat('yyyy-MM-dd').format(item.date);
        final times = item.ranges.map((r) {
          return {
            "start_time": _formatTime(r.start),
            "end_time": _formatTime(r.end),
          };
        }).toList();
        return {"date": dateStr, "times": times};
      }).toList();
      // Note: when saving as unavailability, we want to add records.
      payload = {
        "mode": "single_day_list",
        "items": items,
        "action":
            isUnavailability ? "add_unavailability" : "remove_unavailability",
      };
    } else {
      // Date Interval payload
      final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(_toDate);
      if (_useDayTimesApproach) {
        // Approach A: Day→Times
        final dayMap = <String, dynamic>{};
        for (final dwt in _daysList) {
          final times = dwt.ranges.map((r) {
            return {
              "start_time": _formatTime(r.start),
              "end_time": _formatTime(r.end),
            };
          }).toList();
          dayMap[dwt.day] = times;
        }
        payload = {
          "mode": "date_interval_day_times",
          "from_date": fromStr,
          "to_date": toStr,
          "days": dayMap,
          "action":
              isUnavailability ? "add_unavailability" : "remove_unavailability",
        };
      } else {
        // Approach B: TimeRange→Days
        final ranges = _rangeList.map((tr) {
          return {
            "start_time": _formatTime(tr.start),
            "end_time": _formatTime(tr.end),
            "days": tr.days.toList(),
          };
        }).toList();
        payload = {
          "mode": "date_interval_time_ranges",
          "from_date": fromStr,
          "to_date": toStr,
          "ranges": ranges,
          "action":
              isUnavailability ? "add_unavailability" : "remove_unavailability",
        };
      }
    }

    // Integrate current role info (fetched via your API service) into the payload.
    payload["role"] =
        await fetchCurrentRole(); // e.g., "Instructor", "Parent", "Admin"
    // Optionally, you can also add school_id if needed:
    // payload["school_id"] = schoolId;

    // Log the payload before sending
    debugPrint("Submitting payload: ${jsonEncode(payload)}");

    // Retrieve auth headers and send the POST request.
    final headers = await getAuthHeaders();
    final url = '$baseUrl/api/users/update_availability/';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        debugPrint("Availability update successful: ${response.body}");
        // Optionally display a success message or update UI accordingly.
      } else {
        debugPrint(
            "Error updating availability: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      debugPrint("Exception during availability update: $e");
    }
    setState(() => _isSubmitting = false);
  }

  // --------------------- BUILD UI ---------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No background color for the page.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text("Availability", style: GoogleFonts.lato()),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: "Single Day"),
              Tab(text: "Date Interval"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSingleDayTab(),
                _buildDateIntervalTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  // --------------------- SINGLE DAY TAB ---------------------
  Widget _buildSingleDayTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _singleDayItems.length,
              itemBuilder: (context, index) {
                final item = _singleDayItems[index];
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        // Date row in "from ○" style.
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _pickSingleDayDate(item),
                              child: Row(
                                children: [
                                  Text(
                                    DateFormat('yyyy-MM-dd').format(item.date),
                                    style: GoogleFonts.lato(
                                        fontSize: 14, color: Colors.black),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.calendar_today,
                                      size: 16, color: Colors.orange),
                                ],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () => _removeSingleDayItem(index),
                            ),
                          ],
                        ),
                        const Divider(),
                        // Time range rows.
                        ...List.generate(item.ranges.length, (rIndex) {
                          final range = item.ranges[rIndex];
                          return _TimeRangeRow(
                            range: range,
                            onRemove: () =>
                                _removeTimeRangeSingleDay(item, rIndex),
                            onPickStart: () => _pickTime(context, true, range),
                            onPickEnd: () => _pickTime(context, false, range),
                          );
                        }),
                        // "add new times" button.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _addNewTimeRangeSingleDay(item),
                            icon: const Icon(Icons.add, color: Colors.orange),
                            label: Text("add new times",
                                style: GoogleFonts.lato(color: Colors.orange)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // "add new date" button.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addNewSingleDay,
              icon: const Icon(Icons.add, color: Colors.orange),
              label: Text("add new date",
                  style: GoogleFonts.lato(color: Colors.orange)),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------- DATE INTERVAL TAB ---------------------
  Widget _buildDateIntervalTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          // "from ○ to ○" row for dates.
          Row(
            children: [
              GestureDetector(
                onTap: _pickFromDate,
                child: Row(
                  children: [
                    Text("from",
                        style: GoogleFonts.lato(
                            fontSize: 14, color: Colors.black)),
                    const SizedBox(width: 4),
                    const Icon(Icons.calendar_today,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(DateFormat('yyyy-MM-dd').format(_fromDate),
                        style: GoogleFonts.lato(
                            fontSize: 14, color: Colors.black)),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _pickToDate,
                child: Row(
                  children: [
                    Text("to",
                        style: GoogleFonts.lato(
                            fontSize: 14, color: Colors.black)),
                    const SizedBox(width: 4),
                    const Icon(Icons.calendar_today,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(DateFormat('yyyy-MM-dd').format(_toDate),
                        style: GoogleFonts.lato(
                            fontSize: 14, color: Colors.black)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Internal toggle: Approach A (Day→Times) vs. Approach B (Time→Days)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: Text(
                  "By Weekday",
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: _useDayTimesApproach ? Colors.white : Colors.black,
                  ),
                ),
                selected: _useDayTimesApproach,
                onSelected: (selected) =>
                    setState(() => _useDayTimesApproach = true),
                selectedColor: Colors.orange,
              ),
              const SizedBox(width: 16),
              ChoiceChip(
                label: Text(
                  "By Timeframe",
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: !_useDayTimesApproach ? Colors.white : Colors.black,
                  ),
                ),
                selected: !_useDayTimesApproach,
                onSelected: (selected) =>
                    setState(() => _useDayTimesApproach = false),
                selectedColor: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _useDayTimesApproach
                ? _buildDayTimesApproach()
                : _buildTimeRangeDaysApproach(),
          ),
        ],
      ),
    );
  }

  // ---------- Approach A: Day→Times ----------
  Widget _buildDayTimesApproach() {
    return Column(
      children: [
        // Horizontal row of day chips.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _allDays.map((day) {
              final isSelected = _daysList.any((d) => d.day == day);
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(
                    day,
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => _toggleDayInList(day),
                  selectedColor: Colors.orange,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // For each selected day, show a card with time ranges.
        Expanded(
          child: ListView.builder(
            itemCount: _daysList.length,
            itemBuilder: (context, index) {
              final dayItem = _daysList[index];
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // Day label and delete button.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(dayItem.day,
                              style: GoogleFonts.lato(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () => _removeDay(dayItem),
                          ),
                        ],
                      ),
                      const Divider(),
                      // Time range rows.
                      ...List.generate(dayItem.ranges.length, (rIndex) {
                        final r = dayItem.ranges[rIndex];
                        return _TimeRangeRow(
                          range: r,
                          onRemove: () =>
                              _removeTimeRangeFromDay(dayItem, rIndex),
                          onPickStart: () => _pickTime(context, true, r),
                          onPickEnd: () => _pickTime(context, false, r),
                        );
                      }),
                      // "add new times" button.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _addTimeRangeToDay(dayItem),
                          icon: const Icon(Icons.add, color: Colors.orange),
                          label: Text("add new times",
                              style: GoogleFonts.lato(color: Colors.orange)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------- Approach B: TimeRange→Days ----------
  Widget _buildTimeRangeDaysApproach() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _rangeList.length,
            itemBuilder: (context, index) {
              final item = _rangeList[index];
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // Time range row (from → to)
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _pickTimeWithDays(context, true, item),
                            child: Row(
                              children: [
                                Text(
                                  item.start == null
                                      ? "from"
                                      : item.start!.format(context),
                                  style: GoogleFonts.lato(
                                      fontSize: 14, color: Colors.black),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.access_time,
                                    size: 16, color: Colors.orange),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () =>
                                _pickTimeWithDays(context, false, item),
                            child: Row(
                              children: [
                                Text(
                                  item.end == null
                                      ? "to"
                                      : item.end!.format(context),
                                  style: GoogleFonts.lato(
                                      fontSize: 14, color: Colors.black),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.access_time,
                                    size: 16, color: Colors.orange),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () => _removeTimeRangeWithDays(index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Day chips for this time range.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _allDays.map((day) {
                            final isSelected = item.days.contains(day);
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ChoiceChip(
                                label: Text(
                                  day,
                                  style: GoogleFonts.lato(
                                    fontSize: 14,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: Colors.orange,
                                onSelected: (_) =>
                                    _toggleDayInTimeRange(item, day),
                                backgroundColor: Colors.transparent,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // "add new time range" button.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addTimeRangeWithDays,
            icon: const Icon(Icons.add, color: Colors.orange),
            label: Text("add new time range",
                style: GoogleFonts.lato(color: Colors.orange)),
          ),
        ),
      ],
    );
  }

  // --------------------- BOTTOM BUTTONS ---------------------
  Widget _buildBottomButtons() {
    if (_isSubmitting) {
      return SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // No background color on the bottom button section.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => _submitDefinition(false),
            child: Text("Save As Available",
                style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _submitDefinition(true),
            child: Text("Save As Unavailability",
                style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// --------------------- TIME RANGE ROW WIDGET ---------------------
class _TimeRangeRow extends StatelessWidget {
  final _TimeRange range;
  final VoidCallback onRemove;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _TimeRangeRow({
    Key? key,
    required this.range,
    required this.onRemove,
    required this.onPickStart,
    required this.onPickEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fromStr = range.start == null ? "from" : range.start!.format(context);
    final toStr = range.end == null ? "to" : range.end!.format(context);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              GestureDetector(
                onTap: onPickStart,
                child: Row(
                  children: [
                    Text(fromStr,
                        style: GoogleFonts.lato(
                            fontSize: 14, color: Colors.black)),
                    const SizedBox(width: 4),
                    const Icon(Icons.access_time,
                        size: 16, color: Colors.orange),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onPickEnd,
                child: Row(
                  children: [
                    Text(toStr,
                        style: GoogleFonts.lato(
                            fontSize: 14, color: Colors.black)),
                    const SizedBox(width: 4),
                    const Icon(Icons.access_time,
                        size: 16, color: Colors.orange),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
          onPressed: onRemove,
        ),
      ],
    );
  }
}
