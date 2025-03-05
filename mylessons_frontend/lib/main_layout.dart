// main_layout.dart
import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/schools_page.dart';
import 'pages/payments_page.dart';
import 'pages/checkout_page.dart'; // This will be our checkout view widget.
import 'services/cart_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isCheckout = false; // Flag to indicate whether checkout is active.

  // List of pages corresponding to the navbar items.
  final List<Widget> _pages = [
    const HomePage(),
    const SchoolsPage(),
    const PaymentsPage(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      _isCheckout = false; // If user taps a nav item, leave checkout mode.
    });
  }

  @override
  Widget build(BuildContext context) {
    // The body shows either the selected page or the checkout view.
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
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
            type: BottomNavigationBarType.fixed, // Ensures labels are always visible.
            currentIndex: _currentIndex,
            selectedItemColor: Colors.orange,
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.school), label: 'Schools'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.payment), label: 'Payments'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ],
      ),
    );
  }
}
