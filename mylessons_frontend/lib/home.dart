import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final storage = const FlutterSecureStorage();
  String firstName = '';
  int notificationsCount = 0;
  String currentRole = '';
  List<dynamic> upcomingLessons = [];
  List<dynamic> lastLessons = [];
  List<dynamic> activePacks = [];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<Map<String, String>> getAuthHeaders() async {
    String? token = await storage.read(key: 'auth_token');
    if (token == null) {
      throw Exception("No auth token found");
    }
    return {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
    };
  }

  Future<void> fetchData() async {
    try {
      final headers = await getAuthHeaders();

      final profileResponse = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/users/profile/'),
        headers: headers,
      );
      final roleResponse = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/users/current_role/'),
        headers: headers,
      );

      if (profileResponse.statusCode == 200 && roleResponse.statusCode == 200) {
        final profileData = json.decode(utf8.decode(profileResponse.bodyBytes)); // ✅ UTF-8 decoding
        final roleData = json.decode(utf8.decode(roleResponse.bodyBytes)); // ✅ UTF-8 decoding

        setState(() {
          firstName = profileData['first_name'];
          notificationsCount = profileData['notifications_count'];
          currentRole = roleData['current_role'];
        });
      }

      if (currentRole == "Parent") {
        final lessonsResponse = await http.get(
          Uri.parse('http://127.0.0.1:8000/api/lessons/upcoming_lessons/'),
          headers: headers,
        );
        final lastLessonsResponse = await http.get(
          Uri.parse('http://127.0.0.1:8000/api/lessons/last_lessons/'),
          headers: headers,
        );
        final activePacksResponse = await http.get(
          Uri.parse('http://127.0.0.1:8000/api/lessons/active_packs/'),
          headers: headers,
        );

        if (lessonsResponse.statusCode == 200) {
          setState(() {
            upcomingLessons = json.decode(utf8.decode(lessonsResponse.bodyBytes)); // ✅ UTF-8 decoding
          });
        }
        if (lastLessonsResponse.statusCode == 200) {
          setState(() {
            lastLessons = json.decode(utf8.decode(lastLessonsResponse.bodyBytes)); // ✅ UTF-8 decoding
          });
        }
        if (activePacksResponse.statusCode == 200) {
          setState(() {
            activePacks = json.decode(utf8.decode(activePacksResponse.bodyBytes)); // ✅ UTF-8 decoding
          });
        }
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) {
          switch (index) {
            case 1:
              Navigator.pushNamed(context, '/bookings');
              break;
            case 2:
              Navigator.pushNamed(context, '/payments');
              break;
            case 3:
              Navigator.pushNamed(context, '/profile');
              break;
          }
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Welcome back,', style: GoogleFonts.lato(fontSize: 18, color: Colors.black54)),
                    Stack(
                      children: [
                        Icon(Icons.notifications_none, size: 28),
                        if (notificationsCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: CircleAvatar(
                              radius: 8,
                              backgroundColor: Colors.red,
                              child: Text('$notificationsCount',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          )
                      ],
                    ),
                  ],
                ),
                Text(firstName,
                    style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
                SizedBox(height: 20),
                _buildSectionTitle('Upcoming Lessons'),
                ...upcomingLessons.map((lesson) => _buildLessonCard(lesson)).toList(),
                SizedBox(height: 10),
                _buildSectionTitle('Last Lessons'),
                ...lastLessons.map((lesson) => _buildLessonCard(lesson)).toList(),
                SizedBox(height: 10),
                _buildSectionTitle('Active Packs'),
                ...activePacks.map((pack) => _buildPackCard(pack)).toList(),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLessonCard(dynamic lesson) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.calendar_today, size: 30, color: Colors.black54),
        title: Text(lesson['students_name'], style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        subtitle: Text('${lesson['date']} ${lesson['start_time']}', style: GoogleFonts.lato(fontSize: 14, color: Colors.black54)),
        trailing: Icon(Icons.remove_red_eye, color: Colors.black54),
      ),
    );
  }

  Widget _buildPackCard(dynamic pack) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.calendar_today, size: 30, color: Colors.black54),
        title: Text(pack['students_name'], style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        subtitle: Text('${pack['lessons_remaining']} lessons remaining\n${pack['unscheduled_lessons']} unscheduled lessons',
            style: GoogleFonts.lato(fontSize: 14, color: Colors.black54)),
        trailing: Icon(Icons.remove_red_eye, color: Colors.black54),
      ),
    );
  }
}
