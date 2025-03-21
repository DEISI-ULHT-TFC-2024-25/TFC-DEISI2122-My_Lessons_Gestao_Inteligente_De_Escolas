import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart'; // import connectivity_plus
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/payments_page.dart';
import 'pages/schools_page.dart';
import 'pages/instructor_availability_page.dart';
import 'pages/checkout_page.dart';
import 'services/cart_service.dart';
import 'services/api_service.dart'; // for getAuthHeaders() and baseUrl

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final List<dynamic> newBookedPacks;

  const MainScreen(
      {Key? key, this.newBookedPacks = const [], this.initialIndex = 0})
      : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isCheckout = false;
  String _currentRole = "";
  bool _isLoadingRole = true;

  // Create a navigator key for each bottom nav tab.
  final List<GlobalKey<NavigatorState>> _navigatorKeys =
      List.generate(4, (_) => GlobalKey<NavigatorState>());

  // Create a unique key for each page to force rebuilds.
  List<UniqueKey> _pageKeys = List.generate(4, (_) => UniqueKey());

  late List<Widget> _pages;
  late List<BottomNavigationBarItem> _navBarItems;

  // Connectivity subscription and status flag.
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _fetchUserRole();

    // Wait until after the first frame to ensure ScaffoldMessenger is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen((result) {
        bool offline = result == ConnectivityResult.none;
        if (offline && !_isOffline) {
          // Show a persistent Snackbar if going offline.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("No internet connection"),
              // Set a very long duration so it stays visible.
              duration: const Duration(days: 1),
              behavior: SnackBarBehavior.fixed,
            ),
          );
        } else if (!offline && _isOffline) {
          // Hide the Snackbar when internet is restored.
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
        _isOffline = offline;
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
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
        KeyedSubtree(
          key: _pageKeys[0],
          child: Navigator(
            key: _navigatorKeys[0],
            onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) =>
                    HomePage(newBookedPacks: widget.newBookedPacks)),
          ),
        ),
        KeyedSubtree(
          key: _pageKeys[1],
          child: Navigator(
            key: _navigatorKeys[1],
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const AvailabilityPage()),
          ),
        ),
        KeyedSubtree(
          key: _pageKeys[2],
          child: Navigator(
            key: _navigatorKeys[2],
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const PaymentsPage()),
          ),
        ),
        KeyedSubtree(
          key: _pageKeys[3],
          child: Navigator(
            key: _navigatorKeys[3],
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const ProfilePage()),
          ),
        ),
      ];
      _navBarItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.av_timer), label: 'Availability'),
        BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ];
    } else {
      _pages = [
        KeyedSubtree(
          key: _pageKeys[0],
          child: Navigator(
            key: _navigatorKeys[0],
            onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) =>
                    HomePage(newBookedPacks: widget.newBookedPacks)),
          ),
        ),
        KeyedSubtree(
          key: _pageKeys[1],
          child: Navigator(
            key: _navigatorKeys[1],
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const SchoolsPage()),
          ),
        ),
        KeyedSubtree(
          key: _pageKeys[2],
          child: Navigator(
            key: _navigatorKeys[2],
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const PaymentsPage()),
          ),
        ),
        KeyedSubtree(
          key: _pageKeys[3],
          child: Navigator(
            key: _navigatorKeys[3],
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const ProfilePage()),
          ),
        ),
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
    // If the same bottom nav item is tapped:
    if (index == _currentIndex) {
      // Pop the navigator to the first route.
      _navigatorKeys[index]
          .currentState
          ?.popUntil((route) => route.isFirst);
      // Force a rebuild of that tab by generating a new unique key.
      setState(() {
        _pageKeys[index] = UniqueKey();
        // Also rebuild the page using the same _buildPagesAndNavItems logic.
        _buildPagesAndNavItems();
      });
    } else {
      setState(() {
        _currentIndex = index;
        _isCheckout = false; // exit checkout mode when a nav item is tapped
      });
    }
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
          // Persistent Cart Button (shown only when not in checkout)
          if (!_isCheckout)
            ValueListenableBuilder<int>(
              valueListenable: CartService().cartCount,
              builder: (context, count, child) {
                if (count > 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 4),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isCheckout = true;
                        });
                      },
                      icon: const Icon(
                        Icons.shopping_cart,
                        color: Colors.white,
                      ),
                      label: Text(
                        "Checkout Cart – $count ${count == 1 ? 'item' : 'items'}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
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
