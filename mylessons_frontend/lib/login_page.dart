import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
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
                    Text('Welcome back,',
                        style: GoogleFonts.lato(fontSize: 18, color: Colors.black54)),
                    Stack(
                      children: [
                        Icon(Icons.notifications_none, size: 28),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: CircleAvatar(
                            radius: 8,
                            backgroundColor: Colors.red,
                            child: Text('2',
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
                Text('Bernardo',
                    style: GoogleFonts.lato(
                        fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
                SizedBox(height: 20),
                _buildSectionTitle('Upcoming Lessons'),
                _buildLessonCard('Alex and Mia', '4/8', '9 Jan', '4:30 PM'),
                _buildLessonCard('Alex and Mia', '4/8', '9 Jan', '4:30 PM'),
                _buildLessonCard('Alex and Mia', '4/8', '9 Jan', '4:30 PM'),
                SizedBox(height: 10),
                _buildSectionTitle('Last Lessons'),
                _buildLessonCard('Alex and Mia', '4/8', '9 Jan', '4:30 PM'),
                SizedBox(height: 10),
                _buildSectionTitle('Active Packs'),
                _buildPackCard('Alex and Mia', 4, 50),
                _buildPackCard('Manuel', 4, 50),
                SizedBox(height: 20),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'How Can We Help?',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
          Icon(Icons.arrow_forward),
        ],
      ),
    );
  }

  Widget _buildLessonCard(String name, String progress, String date, String time) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.calendar_today, size: 30, color: Colors.black54),
        title: Text(name, style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            Text('$progress   $date   $time',
                style: GoogleFonts.lato(fontSize: 14, color: Colors.black54)),
          ],
        ),
        trailing: Icon(Icons.remove_red_eye, color: Colors.black54),
      ),
    );
  }

  Widget _buildPackCard(String name, int remainingLessons, int daysRemaining) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.calendar_today, size: 30, color: Colors.black54),
        title: Text(name, style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$remainingLessons lessons remaining',
                style: GoogleFonts.lato(fontSize: 14, color: Colors.black54)),
            Text('4 unscheduled lessons   expiring in $daysRemaining days',
                style: GoogleFonts.lato(fontSize: 14, color: Colors.black54)),
          ],
        ),
        trailing: Icon(Icons.remove_red_eye, color: Colors.black54),
      ),
    );
  }
}
