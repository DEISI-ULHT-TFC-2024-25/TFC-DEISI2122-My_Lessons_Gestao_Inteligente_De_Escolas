import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'availability_calendar_page.dart';

/// Abstract interface to represent a time range.
abstract class TimeRangeInterface {
  TimeOfDay? get start;
  set start(TimeOfDay? value);
  TimeOfDay? get end;
  set end(TimeOfDay? value);
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
  String day; // e.g., "Monday"
  List<_TimeRange> ranges;
  DayWithTimes({required this.day, List<_TimeRange>? ranges})
      : ranges = ranges ?? [_TimeRange()];
}

/// Model for Approach B (TimeRange→Days): each time range can have multiple days.
class TimeRangeWithDays implements TimeRangeInterface {
  @override
  TimeOfDay? start;
  @override
  TimeOfDay? end;
  Set<String> days;
  TimeRangeWithDays({this.start, this.end, Set<String>? days})
      : days = days ??
            {
              "Monday",
              "Tuesday",
              "Wednesday",
              "Thursday",
              "Friday",
              "Saturday",
              "Sunday"
            };
}

/// Basic time range with start and end TimeOfDay.
class _TimeRange implements TimeRangeInterface {
  @override
  TimeOfDay? start;
  @override
  TimeOfDay? end;
}

class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({Key? key}) : super(key: key);

  @override
  _AvailabilityPageState createState() => _AvailabilityPageState();
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
  // true => Approach A: Day→Times (By Weekday)
  // false => Approach B: TimeRange→Days (By Timeframe)
  bool _useDayTimesApproach = false; // "By Timeframe" is selected by default.
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
    // Update the TabController length to 3.
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(
          () {}); // trigger rebuild when tab changes (to update bottom buttons)
    });
  }

  // --------------------- CUSTOM CUPERTINO TIME PICKER ---------------------
  Future<void> _showCupertinoTimePickerForRange(
      BuildContext context, bool isStart, TimeRangeInterface range,
      {TimeOfDay? minTime}) async {
    final hours =
        List.generate(24, (index) => index.toString().padLeft(2, '0'));
    final minutes =
        List.generate(60, (index) => index.toString().padLeft(2, '0'));

    int selectedHour =
        isStart ? (range.start?.hour ?? 0) : (range.end?.hour ?? 0);
    int selectedMinute =
        isStart ? (range.start?.minute ?? 0) : (range.end?.minute ?? 0);

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

    if (!isStart && minTime != null) {
      if (selectedHour < minTime.hour ||
          (selectedHour == minTime.hour && selectedMinute < minTime.minute)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Please select a time after ${minTime.format(context)}",
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      if (isStart) {
        range.start = TimeOfDay(hour: selectedHour, minute: selectedMinute);
      } else {
        range.end = TimeOfDay(hour: selectedHour, minute: selectedMinute);
      }
    });
  }

  // --------------------- DATE & TIME PICKERS ---------------------
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

    if (currentTabIndex == 1) {
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
      payload = {
        "mode": "single_day_list",
        "items": items,
        "action":
            isUnavailability ? "add_unavailability" : "remove_unavailability",
      };
    } else if (currentTabIndex == 0) {
      // Date Interval payload
      final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(_toDate);
      if (_useDayTimesApproach) {
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

    payload["role"] = await fetchCurrentRole();

    debugPrint("Submitting payload: ${jsonEncode(payload)}");

    final headers = await getAuthHeaders();
    final url = '$baseUrl/api/users/update_availability/';

    try {
      final response = await http.post(Uri.parse(url),
          headers: headers, body: jsonEncode(payload));
      if (response.statusCode == 200) {
        final result = json.decode(utf8.decode(response.bodyBytes));

        final dynamic summaryData = result["summary"];
        String summaryString;
        if (summaryData is String) {
          summaryString = summaryData;
        } else if (summaryData is List) {
          summaryString = summaryData.join("\n");
        } else {
          summaryString = "Update successful";
        }

        final lines = summaryString
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Update Summary", style: GoogleFonts.lato()),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines.map((line) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.grey[100],
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        line,
                        style: GoogleFonts.lato(fontSize: 14),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text("OK", style: GoogleFonts.lato(fontSize: 16)),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Update Summary", style: GoogleFonts.lato()),
            content: Text(response.body, style: GoogleFonts.lato()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("OK", style: GoogleFonts.lato()),
              ),
            ],
          ),
        );
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
      appBar: AppBar(
        title: Text("Availability", style: GoogleFonts.lato()),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "Interval"),
            Tab(text: "Daily"),
            Tab(text: "Calendar"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDateIntervalTab(),
          _buildSingleDayTab(),
          const AvailabilityCalendarPage(),
        ],
      ),
      // Show bottom buttons only if we're not on the "Calendar" tab.
      bottomNavigationBar:
          _tabController.index == 2 ? null : _buildBottomButtons(),
    );
  }

  // --------------------- SINGLE DAY TAB ---------------------
  Widget _buildSingleDayTab() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: _singleDayItems.length + 1, // extra item for "Add New Date"
      itemBuilder: (context, index) {
        if (index < _singleDayItems.length) {
          final item = _singleDayItems[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(bottom: 16), // extra bottom margin
            child: Padding(
              padding: const EdgeInsets.all(16), // increased padding
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _pickSingleDayDate(item),
                        child: Row(
                          children: [
                            // Date formatted in two lines with a smaller font
                            Text(
                              DateFormat('EEEE').format(item.date) +
                                  "\n" +
                                  DateFormat('d MMM yyyy').format(item.date),
                              style: GoogleFonts.lato(
                                  fontSize: 16, color: Colors.black),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.calendar_today,
                                size: 28, color: Colors.orange),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _removeSingleDayItem(index),
                      ),
                    ],
                  ),
                  const Divider(),
                  ...List.generate(item.ranges.length, (rIndex) {
                    final range = item.ranges[rIndex];
                    return _TimeRangeRow(
                      range: range,
                      onRemove: () => _removeTimeRangeSingleDay(item, rIndex),
                      onPickStart: () => _showCupertinoTimePickerForRange(
                          context, true, range),
                      onPickEnd: () => _showCupertinoTimePickerForRange(
                          context, false, range,
                          minTime: range.start),
                    );
                  }),
                ],
              ),
            ),
          );
        } else {
          // Extra item: "Add New Date" button at the bottom of the list
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: _addNewSingleDay,
                icon: const Icon(Icons.add, color: Colors.orange),
                label: Text("Add New Date",
                    style:
                        GoogleFonts.lato(color: Colors.orange, fontSize: 16)),
              ),
            ),
          );
        }
      },
    );
  }

  // --------------------- DATE INTERVAL TAB ---------------------
  Widget _buildDateIntervalTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // Toggle Buttons Row:
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ToggleButtons(
              borderRadius: BorderRadius.circular(16),
              isSelected: [(!_useDayTimesApproach), _useDayTimesApproach],
              onPressed: (int index) {
                setState(() {
                  _useDayTimesApproach = (index == 1);
                });
              },
              selectedColor: Colors.white,
              fillColor: Colors.orange,
              color: Colors.orange,
              borderColor: Colors.orange,
              borderWidth: 2.0,
              selectedBorderColor: Colors.orange,
              constraints: const BoxConstraints(minHeight: 32, minWidth: 100),
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_useDayTimesApproach)
                        const Icon(Icons.check, color: Colors.black, size: 16),
                      if (!_useDayTimesApproach) const SizedBox(width: 4),
                      Text(
                        "By Timeframe",
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: !_useDayTimesApproach
                              ? Colors.white
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_useDayTimesApproach)
                        const Icon(Icons.check, color: Colors.black, size: 16),
                      if (_useDayTimesApproach) const SizedBox(width: 4),
                      Text(
                        "By Weekday",
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _useDayTimesApproach
                              ? Colors.white
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 20),
        // Date Selection Row:
        Row(
          children: [
            GestureDetector(
              onTap: _pickFromDate,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 28, color: Colors.orange),
                  const SizedBox(width: 8),
                  // Date formatted in two lines.
                  Text(
                    DateFormat('EEEE').format(_fromDate) +
                        "\n" +
                        DateFormat('d MMM yyyy').format(_fromDate),
                    style: GoogleFonts.lato(fontSize: 16, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text("To",
                style: GoogleFonts.lato(fontSize: 18, color: Colors.black)),
            const Spacer(),
            GestureDetector(
              onTap: _pickToDate,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 28, color: Colors.orange),
                  const SizedBox(width: 8),
                  // Date formatted in two lines.
                  Text(
                    DateFormat('EEEE').format(_toDate) +
                        "\n" +
                        DateFormat('d MMM yyyy').format(_toDate),
                    style: GoogleFonts.lato(fontSize: 16, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Display either of the two approaches:
        _useDayTimesApproach
            ? _buildDayTimesApproach()
            : _buildTimeRangeDaysApproach(),
      ],
    );
  }

  // ---------- Approach A: Day→Times ----------
  Widget _buildDayTimesApproach() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _allDays.map((day) {
              final isSelected = _daysList.any((d) => d.day == day);
              final chipShape = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
                side: BorderSide(
                  color: isSelected ? Colors.white : Colors.orange,
                  width: 2.0,
                ),
              );
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(
                    day,
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.orange,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Colors.orange,
                  backgroundColor: Colors.white,
                  shape: chipShape,
                  onSelected: (_) => _toggleDayInList(day),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dayItem.day,
                            style: GoogleFonts.lato(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon:
                              const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _removeDay(dayItem),
                        ),
                      ],
                    ),
                    const Divider(),
                    ...List.generate(dayItem.ranges.length, (rIndex) {
                      final r = dayItem.ranges[rIndex];
                      return _TimeRangeRow(
                        range: r,
                        onRemove: () =>
                            _removeTimeRangeFromDay(dayItem, rIndex),
                        onPickStart: () =>
                            _showCupertinoTimePickerForRange(context, true, r),
                        onPickEnd: () => _showCupertinoTimePickerForRange(
                            context, false, r,
                            minTime: r.start),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Align(
                        alignment: Alignment.center,
                        child: TextButton.icon(
                          onPressed: () => _addTimeRangeToDay(dayItem),
                          icon: const Icon(Icons.add, color: Colors.orange),
                          label: Text("Add New Time Range",
                              style: GoogleFonts.lato(
                                  color: Colors.orange, fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------- Approach B: TimeRange→Days ----------
  Widget _buildTimeRangeDaysApproach() {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showCupertinoTimePickerForRange(
                              context, true, item),
                          child: Row(
                            children: [
                              Text(
                                item.start == null
                                    ? "From"
                                    : item.start!.format(context),
                                style: GoogleFonts.lato(
                                    fontSize: 16, color: Colors.black),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.access_time,
                                  size: 28, color: Colors.orange),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _showCupertinoTimePickerForRange(
                              context, false, item,
                              minTime: item.start),
                          child: Row(
                            children: [
                              Text(
                                item.end == null
                                    ? "To"
                                    : item.end!.format(context),
                                style: GoogleFonts.lato(
                                    fontSize: 16, color: Colors.black),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.access_time,
                                  size: 28, color: Colors.orange),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon:
                              const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _removeTimeRangeWithDays(index),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _allDays.map((day) {
                          final isSelected = item.days.contains(day);
                          final chipShape = RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                            side: BorderSide(
                              color: isSelected ? Colors.white : Colors.orange,
                              width: 2.0,
                            ),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(
                                day,
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isSelected ? Colors.white : Colors.orange,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: Colors.orange,
                              backgroundColor: Colors.white,
                              shape: chipShape,
                              onSelected: (_) =>
                                  _toggleDayInTimeRange(item, day),
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: _addTimeRangeWithDays,
              icon: const Icon(Icons.add, color: Colors.orange),
              label: Text("Add New Time Range",
                  style: GoogleFonts.lato(color: Colors.orange, fontSize: 16)),
            ),
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
    return BottomAppBar(
      color: Colors.transparent, // transparent background
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => _submitDefinition(false),
              child: Text("Available",
                  style: GoogleFonts.lato(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => _submitDefinition(true),
              child: Text("Unavailable",
                  style: GoogleFonts.lato(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------- TIME RANGE ROW WIDGET ---------------------
class _TimeRangeRow extends StatelessWidget {
  final TimeRangeInterface range;
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
    final fromStr = range.start == null ? "From" : range.start!.format(context);
    final toStr = range.end == null ? "To" : range.end!.format(context);
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 4.0), // extra vertical padding
      child: Row(
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
                              fontSize: 16, color: Colors.black)),
                      const SizedBox(width: 4),
                      const Icon(Icons.access_time,
                          size: 28, color: Colors.orange),
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
                              fontSize: 16, color: Colors.black)),
                      const SizedBox(width: 4),
                      const Icon(Icons.access_time,
                          size: 28, color: Colors.orange),
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
      ),
    );
  }
}
