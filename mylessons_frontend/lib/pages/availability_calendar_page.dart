import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
    final String dateStr = DateFormat('yyyy-MM-dd').format(day);
    final String url = '$baseUrl/api/users/daily_timeline/?date=$dateStr';
    final headers = await getAuthHeaders();

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> data =
            json.decode(utf8.decode(response.bodyBytes));
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
        debugPrint(
            "Error fetching timeline: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      debugPrint("Exception fetching timeline: $e");
    }
  }

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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDay) {
      setState(() {
        _selectedDay = picked;
      });
      _fetchEventsForDay(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar so the heading is removed.
      body: Stack(
        children: [
          // Main content: List of events.
          Padding(
            padding: const EdgeInsets.only(
                left: 16.0, right: 16.0, top: 16.0, bottom: 80.0),
            child: _eventsForDay.isEmpty
                ? Center(
                    child: Text("No events scheduled for this day.",
                        style: Theme.of(context).textTheme.titleMedium),
                  )
                : ListView.builder(
                    itemCount: _eventsForDay.length,
                    itemBuilder: (context, index) {
                      final event = _eventsForDay[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: Icon(event.icon, color: event.color),
                          title: Text(event.title),
                          subtitle: Text(
                            "${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}",
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Fixed button at the bottom.
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ElevatedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_today, color: Colors.white),
              label: Text(
                DateFormat('EEEE d MMM yyyy').format(_selectedDay),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
