import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class Event {
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final Color color;
  final IconData icon;
  final String type; // e.g., 'unavailability', 'lesson', 'activity'

  Event({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.icon,
    required this.type,
  });
}

class AvailabilityCalendarPage extends StatefulWidget {
  const AvailabilityCalendarPage({Key? key}) : super(key: key);

  @override
  _AvailabilityCalendarPageState createState() =>
      _AvailabilityCalendarPageState();
}

class _AvailabilityCalendarPageState extends State<AvailabilityCalendarPage> {
  DateTime _selectedDay = DateTime.now();
  List<Event> _eventsForDay = [];

  @override
  void initState() {
    super.initState();
    _fetchEventsForDay(_selectedDay);
  }

  Future<void> _fetchEventsForDay(DateTime day) async {
    // Fetch from your real API endpoint.
    final String dateStr = DateFormat('yyyy-MM-dd').format(day);
    final String url = '$baseUrl/api/users/daily_timeline/?date=$dateStr';
    final headers = await getAuthHeaders();

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Event> events = [];
        for (var item in data) {
          String type = item['type'];
          String title = item['title'] ?? "";
          if (type == "unavailability" && title.isEmpty) {
            title = "Unavailable";
          } else if (type == "available" && title.isEmpty) {
            title = "Available";
          }
          DateTime startTime = _parseTimeForDay(item['start_time'], day);
          DateTime endTime = _parseTimeForDay(item['end_time'], day);

          // Map types to colors and icons.
          Color eventColor;
          IconData eventIcon;
          switch (type) {
            case "unavailability":
              eventColor = Colors.orange;
              eventIcon = Icons.block;
              break;
            case "available":
              eventColor = Colors.green;
              eventIcon = Icons.check_circle_outline;
              break;
            case "lesson":
              eventColor = Colors.blue;
              eventIcon = Icons.school;
              break;
            case "activity":
              eventColor = Colors.purple;
              eventIcon = Icons.fitness_center;
              break;
            default:
              eventColor = Colors.grey;
              eventIcon = Icons.info;
          }

          events.add(Event(
            title: title,
            startTime: startTime,
            endTime: endTime,
            color: eventColor,
            icon: eventIcon,
            type: type,
          ));
        }
        setState(() {
          _eventsForDay = events;
        });
      } else {
        debugPrint("Error fetching timeline: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      debugPrint("Exception fetching timeline: $e");
    }
  }

  /// Converts a time string ("HH:MM") and a given day into a DateTime.
  DateTime _parseTimeForDay(String timeStr, DateTime day) {
    if (timeStr == "24:00") {
      return DateTime(day.year, day.month, day.day, 23, 59, 59);
    }
    final parts = timeStr.split(":");
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    // Get screen height for a responsive layout.
    final screenHeight = MediaQuery.of(context).size.height;
    // Calendar takes up 50% of screen height.
    final calendarHeight = screenHeight * 0.5;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Availability Calendar"),
      ),
      body: CustomScrollView(
        slivers: [
          // Calendar Section
          SliverToBoxAdapter(
            child: Container(
              height: calendarHeight,
              child: TableCalendar(
                calendarFormat: CalendarFormat.month,
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _selectedDay,
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                  });
                  _fetchEventsForDay(selected);
                },
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: CalendarStyle(
                  cellMargin: const EdgeInsets.all(4.0),
                  defaultTextStyle: const TextStyle(color: Colors.black),
                  weekendTextStyle: const TextStyle(color: Colors.red),
                  todayDecoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          // Spacer between calendar and event list.
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          // Events List Section
          _eventsForDay.isEmpty
              ? SliverFillRemaining(
                  child: Center(child: Text("No events scheduled for this day.")),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = _eventsForDay[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: Icon(event.icon, color: event.color),
                          title: Text(event.title),
                          subtitle: Text(
                            "${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}",
                          ),
                        ),
                      );
                    },
                    childCount: _eventsForDay.length,
                  ),
                ),
        ],
      ),
    );
  }
}
