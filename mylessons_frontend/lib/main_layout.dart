// main_layout.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/payments_page.dart';
import 'pages/schools_page.dart';
import 'pages/instructor_availability_page.dart';
import 'pages/checkout_page.dart';
import 'services/cart_service.dart';
import 'services/api_service.dart'; // for getAuthHeaders() and baseUrl

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isCheckout = false;
  String _currentRole = "";
  bool _isLoadingRole = true;
  
  late List<Widget> _pages;
  late List<BottomNavigationBarItem> _navBarItems;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    try {
      final headers = await getAuthHeaders();
      final roleResponse = await http.get(
        Uri.parse('$baseUrl/api/users/current_role/'),
        headers: headers,
      );
      if (roleResponse.statusCode == 200) {
        final roleData = json.decode(utf8.decode(roleResponse.bodyBytes));
        // assuming the API returns a JSON with a "current_role" key.
        _currentRole = roleData['current_role'] ?? "";
      } else {
        _currentRole = "";
      }
    } catch (e) {
      _currentRole = "";
      print("Error fetching user role: $e");
    }
    _buildPagesAndNavItems();
    setState(() {
      _isLoadingRole = false;
    });
  }

  void _buildPagesAndNavItems() {
    if (_currentRole == "Instructor") {
      _pages = [
        const HomePage(),
        const AvailabilityPage(),
        const PaymentsPage(),
        const ProfilePage(),
      ];
      _navBarItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.av_timer), label: 'Availability'),
        BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ];
    } else {
      _pages = [
        const HomePage(),
        const SchoolsPage(),
        const PaymentsPage(),
        const ProfilePage(),
      ];
      _navBarItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Schools'),
        BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      _isCheckout = false; // leave checkout mode when a nav item is tapped
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: _isCheckout
          ? CheckoutPage(
              onBack: () {
                setState(() {
                  _isCheckout = false;
                });
              },
            )
          : IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Persistent Cart Button is shown only when NOT in checkout mode.
          if (!_isCheckout)
            ValueListenableBuilder<int>(
              valueListenable: CartService().cartCount,
              builder: (context, count, child) {
                if (count > 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isCheckout = true;
                        });
                      },
                      child: Text("Checkout Cart – $count item(s)"),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            selectedItemColor: Colors.orange,
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            items: _navBarItems,
          ),
        ],
      ),
    );
  }
}
