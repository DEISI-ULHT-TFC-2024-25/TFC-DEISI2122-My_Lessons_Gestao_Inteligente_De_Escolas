// home_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mylessons_frontend/modals/lesson_details_modal.dart';
import 'package:mylessons_frontend/modals/pack_details_modal.dart';
import 'package:mylessons_frontend/modals/schedule_multiple_lessons_modal.dart';
import 'package:mylessons_frontend/providers/pack_details_provider.dart';
import 'package:mylessons_frontend/widgets/handle_lesson_report.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../modals/profile_completion_modal.dart';
import '../providers/lessons_modal_provider.dart';
import '../services/api_service.dart';
import '../services/profile_service.dart';
import '../widgets/lesson_grouping_widget.dart';
import '../widgets/notification_card_widget.dart';
import 'profile_page.dart';
import 'package:mylessons_frontend/modals/schedule_lesson_modal.dart';
import '../providers/home_page_provider.dart';

class HomePage extends StatefulWidget {
  final List<dynamic> newBookedPacks;
  const HomePage({Key? key, this.newBookedPacks = const []}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // Remove duplicated user/profile variables (now in provider).
  // Retain UI-specific state (filters, tab index, animations, scroll controllers).
  String upcomingSearchQuery = "";
  List<Map<String, String>> upcomingFilters = [];
  String lastLessonsSearchQuery = "";
  List<Map<String, String>> lastLessonsFilters = [];
  String activePacksSearchQuery = "";
  List<Map<String, String>> activePacksFilters = [];
  String lastPacksSearchQuery = "";
  List<Map<String, String>> lastPacksFilters = [];

  int _lessonsActiveTabIndex = 0; // 0: Active lessons, 1: History
  int _packsActiveTabIndex = 0; // 0: Active packs, 1: History

  double _welcomeHeight = 80; // Controls only the welcome message area.
  double _notificationHeight =
      50; // Set this to a value (e.g., 50) that fits your notifications warning.

  late AnimationController _headerAnimationController;
  final ScrollController _lessonsScrollController = ScrollController();
  final ScrollController _packsScrollController = ScrollController();
  bool _showToggleRow = true;
  bool _showHeader = true;

  @override
  void initState() {
    super.initState();
    registerFcmTokenIfNeeded();

    _headerAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    // Animate the welcome message (not the notifications area)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _headerAnimationController.forward().then((_) {
          setState(() {
            // Collapse only the welcome part
            _welcomeHeight = 0;
          });
        });
      }
    });

    _lessonsScrollController.addListener(() {
      if (_lessonsScrollController.offset > 50 && _showToggleRow) {
        setState(() {
          _showToggleRow = false;
        });
      } else if (_lessonsScrollController.offset <= 50 && !_showToggleRow) {
        setState(() {
          _showToggleRow = true;
        });
      }
    });
    _packsScrollController.addListener(() {
      if (_packsScrollController.offset > 50 && _showToggleRow) {
        setState(() {
          _showToggleRow = false;
        });
      } else if (_packsScrollController.offset <= 50 && !_showToggleRow) {
        setState(() {
          _showToggleRow = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _lessonsScrollController.dispose();
    _packsScrollController.dispose();
    super.dispose();
  }

  bool _fcmTokenSent = false;

  Future<void> registerFcmTokenIfNeeded() async {
  if (_fcmTokenSent) return; // ensure it's done only once
  final token = await FirebaseMessaging.instance.getToken();
  final authToken = await getYourSavedAuthToken();

  if (token != null && authToken.isNotEmpty) {
    await sendTokenToBackend(token, authToken);
    _fcmTokenSent = true;
  } else {
    print('⚠️ Not logged in or no FCM token');
  }
}

  /// Modal methods (using provider values as needed).
  void showLessonCardOptions(dynamic lesson) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.orange),
                title: const Text("Schedule Lesson"),
                onTap: () {
                  Navigator.pop(context);
                  if (lesson['type']?.toString().toLowerCase() == 'group') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Scheduling Unavailable"),
                        content: const Text(
                            "To change the schedule of a group lesson, please contact the school."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"),
                          )
                        ],
                      ),
                    );
                  } else {
                    Provider.of<LessonModalProvider>(context, listen: false)
                        .showScheduleLessonModal(context, lesson);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.more_vert, color: Colors.orange),
                title: const Text("View Details"),
                onTap: () {
                  Navigator.pop(context);
                  Provider.of<LessonModalProvider>(context, listen: false)
                      .showLessonDetailsModal(context, lesson);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPackCardOptions(dynamic pack) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.orange),
                title: const Text("Schedule Lessons"),
                onTap: () {
                  Navigator.pop(context);
                  if (pack['type'].toString().toLowerCase() == 'group') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Scheduling Unavailable"),
                        content: const Text(
                            "To change the schedule of a group lesson, please contact the school."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"),
                          )
                        ],
                      ),
                    );
                  } else {
                    _showScheduleMultipleLessonsModal(
                        pack['lessons'], pack["expiration_date"]);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.more_vert, color: Colors.orange),
                title: const Text("View Details"),
                onTap: () {
                  Navigator.pop(context);
                  showPackDetailsModal(pack);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void showPackDetailsModal(dynamic pack) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackDetailsPage(pack: pack),
      ),
    );
  }

  Future<void> _showScheduleMultipleLessonsModal(
    List<dynamic> lessons,
    String expirationDate,
  ) async {
    final timeLimit =
        await fetchSchoolScheduleTimeLimit(lessons.first["school"]);

    // Await the sheet, declaring it returns a bool
    final didSchedule = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ScheduleMultipleLessonsModal(
        lessons: lessons,
        unschedulableLessons:
            Provider.of<HomePageProvider>(context, listen: false)
                .unschedulableLessons,
        expirationDate: expirationDate,
        currentRole:
            Provider.of<HomePageProvider>(context, listen: false).currentRole,
        schoolScheduleTimeLimit: timeLimit,
        onScheduleConfirmed: () async {
          // you can still refresh here if you like
          await Provider.of<HomePageProvider>(context, listen: false)
              .fetchData();
        },
      ),
    );
  }

  Future<void> _showNotificationsModal() async {
    // Hide warning bar…
    setState(() => _notificationHeight = 0);
    await Future.delayed(const Duration(milliseconds: 500));

    // Mark as read…
    final homeProvider = Provider.of<HomePageProvider>(context, listen: false);
    homeProvider.notificationsCount = 0;
    homeProvider.notifyListeners();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, // when opened
          minChildSize: 0.3, // how far down it can collapse
          maxChildSize: 0.9, // up to 90% height
          expand: false,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<List<dynamic>>(
                future: _fetchNotifications(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final notifications = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Notificações",
                        style: GoogleFonts.lato(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: notifications.isEmpty
                            ? Center(
                                child: Text(
                                  "Sem notificações novas.",
                                  style: GoogleFonts.lato(
                                      fontSize: 16, color: Colors.black54),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollCtrl,
                                itemCount: notifications.length,
                                itemBuilder: (context, index) {
                                  return NotificationCard(
                                      notification: notifications[index]);
                                },
                              ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close",
                              style: TextStyle(color: Colors.orange)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<List<dynamic>> _fetchNotifications() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/notifications/unread/'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> notifications =
          jsonDecode(utf8.decode(response.bodyBytes));
      List<int> notificationIds =
          notifications.map<int>((n) => n['id']).toList();
      _markNotificationsAsRead(notificationIds);
      return notifications;
    } else {
      return [];
    }
  }

  Future<void> _markNotificationsAsRead(List<int> notificationIds) =>
      markNotificationsAsRead(notificationIds);

  void _showLessonFilterModal(bool isUpcoming, List<dynamic> lessons) {
    const options = ['Group', 'Private'];
    List<Map<String, String>> tempFilters =
        isUpcoming ? List.from(upcomingFilters) : List.from(lastLessonsFilters);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          bool isSelected(String value) {
            return tempFilters
                .any((f) => f['type'] == 'lessonType' && f['value'] == value);
          }

          return Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExpansionTile(
                    title: const Text('Lesson Type'),
                    children: options.map((opt) {
                      return CheckboxListTile(
                        title: Text(opt),
                        value: isSelected(opt),
                        onChanged: (checked) {
                          setModalState(() {
                            if (checked == true) {
                              tempFilters.insert(
                                  0, {'type': 'lessonType', 'value': opt});
                            } else {
                              tempFilters.removeWhere((f) =>
                                  f['type'] == 'lessonType' &&
                                  f['value'] == opt);
                            }
                          });
                          setState(() {
                            if (isUpcoming) {
                              upcomingFilters = List.from(tempFilters);
                            } else {
                              lastLessonsFilters = List.from(tempFilters);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close',
                          style: TextStyle(color: Colors.black)),
                    ),
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showPackFilterModal(bool isActive, List<dynamic> packs) {
    const options = ['Group', 'Private'];
    List<Map<String, String>> tempFilters =
        isActive ? List.from(activePacksFilters) : List.from(lastPacksFilters);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          bool isSelected(String value) {
            return tempFilters
                .any((f) => f['type'] == 'packType' && f['value'] == value);
          }

          return Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExpansionTile(
                    title: const Text('Pack Type'),
                    children: options.map((opt) {
                      return CheckboxListTile(
                        title: Text(opt),
                        value: isSelected(opt),
                        onChanged: (checked) {
                          setModalState(() {
                            if (checked == true) {
                              tempFilters.insert(
                                  0, {'type': 'packType', 'value': opt});
                            } else {
                              tempFilters.removeWhere((f) =>
                                  f['type'] == 'packType' && f['value'] == opt);
                            }
                          });
                          setState(() {
                            if (isActive) {
                              activePacksFilters = List.from(tempFilters);
                            } else {
                              lastPacksFilters = List.from(tempFilters);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close',
                          style: TextStyle(color: Colors.black)),
                    ),
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  List<dynamic> _filterLessons(
      List<dynamic> lessons, String query, List<Map<String, String>> filters) {
    return lessons.where((lesson) {
      final name = lesson['students_name'].toString();
      final matchesQuery =
          query.isEmpty || name.toLowerCase().contains(query.toLowerCase());
      final appliedTypes = filters
          .where((f) => f['type'] == 'lessonType')
          .map((f) => f['value']!.toLowerCase())
          .toList();
      final lessonType = lesson['type']?.toString().toLowerCase() ?? '';
      final matchesFilter =
          appliedTypes.isEmpty || appliedTypes.contains(lessonType);
      return matchesQuery && matchesFilter;
    }).toList();
  }

  List<dynamic> _filterPacks(
      List<dynamic> packs, String query, List<Map<String, String>> filters) {
    return packs.where((pack) {
      final name = pack['students_name'].toString();
      final matchesQuery =
          query.isEmpty || name.toLowerCase().contains(query.toLowerCase());
      final appliedTypes = filters
          .where((f) => f['type'] == 'packType')
          .map((f) => f['value']!.toLowerCase())
          .toList();
      final packType = pack['type']?.toString().toLowerCase() ?? '';
      final matchesFilter =
          appliedTypes.isEmpty || appliedTypes.contains(packType);
      return matchesQuery && matchesFilter;
    }).toList();
  }

  Widget _buildHeader(HomePageProvider homeProvider) {
    return Column(
      children: [
        // Welcome message area.
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          height: _welcomeHeight, // This part animates from 80 to 0.
          child: SlideTransition(
            position: _headerAnimationController.drive(
              Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1))
                  .chain(CurveTween(curve: const Interval(0.5, 1.0))),
            ),
            child: FadeTransition(
              opacity: _headerAnimationController.drive(
                Tween<double>(begin: 1.0, end: 0.0)
                    .chain(CurveTween(curve: const Interval(0.0, 0.5))),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Welcome back,",
                    style: GoogleFonts.lato(fontSize: 18, color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    homeProvider.firstName,
                    style: GoogleFonts.lato(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Notifications warning area only shows if notifications exist.
        if (homeProvider.notificationsCount > 0)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            // Use _notificationHeight to drive opacity. When the height is 0, opacity is 0.
            opacity: _notificationHeight > 0 ? 1.0 : 0.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              height: _notificationHeight, // e.g., initial value 50.
              child: GestureDetector(
                onTap: _showNotificationsModal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.notifications_none,
                      size: 28,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${homeProvider.notificationsCount} new notifications",
                      style:
                          GoogleFonts.lato(fontSize: 18, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildToggleRowForLessons() {
    return AnimatedOpacity(
      opacity: _showToggleRow ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.search, color: Colors.orange),
                onPressed: () {
                  // Implement search functionality.
                  print("Search pressed in lessons tab");
                },
              ),
            ),
            Center(
              child: ToggleButtons(
                borderRadius: BorderRadius.circular(16),
                isSelected: [
                  _lessonsActiveTabIndex == 0,
                  _lessonsActiveTabIndex == 1,
                ],
                onPressed: (int index) {
                  setState(() {
                    _lessonsActiveTabIndex = index;
                  });
                },
                selectedColor: Colors.white,
                fillColor: Colors.orange,
                color: Colors.orange,
                borderColor: Colors.orange,
                borderWidth: 2.0,
                selectedBorderColor: Colors.orange,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 80),
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_lessonsActiveTabIndex == 0)
                          const Icon(Icons.check,
                              color: Colors.black, size: 16),
                        if (_lessonsActiveTabIndex == 0)
                          const SizedBox(width: 4),
                        const Text(
                          "Active",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_lessonsActiveTabIndex == 1)
                          const Icon(Icons.check,
                              color: Colors.black, size: 16),
                        if (_lessonsActiveTabIndex == 1)
                          const SizedBox(width: 4),
                        const Text(
                          "History",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.orange),
                onPressed: () {
                  if (_lessonsActiveTabIndex == 0) {
                    _showLessonFilterModal(
                        true,
                        Provider.of<HomePageProvider>(context, listen: false)
                            .upcomingLessons);
                  } else {
                    _showLessonFilterModal(
                        false,
                        Provider.of<HomePageProvider>(context, listen: false)
                            .lastLessons);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRowForPacks() {
    return AnimatedOpacity(
      opacity: _showToggleRow ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.search, color: Colors.orange),
                onPressed: () {
                  print("Search pressed in packs tab");
                },
              ),
            ),
            Center(
              child: ToggleButtons(
                borderRadius: BorderRadius.circular(16),
                isSelected: [
                  _packsActiveTabIndex == 0,
                  _packsActiveTabIndex == 1,
                ],
                onPressed: (int index) {
                  setState(() {
                    _packsActiveTabIndex = index;
                  });
                },
                selectedColor: Colors.white,
                fillColor: Colors.orange,
                color: Colors.orange,
                borderColor: Colors.orange,
                borderWidth: 2.0,
                selectedBorderColor: Colors.orange,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 80),
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_packsActiveTabIndex == 0)
                          const Icon(Icons.check,
                              color: Colors.black, size: 16),
                        if (_packsActiveTabIndex == 0) const SizedBox(width: 4),
                        const Text(
                          "Active",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_packsActiveTabIndex == 1)
                          const Icon(Icons.check,
                              color: Colors.black, size: 16),
                        if (_packsActiveTabIndex == 1) const SizedBox(width: 4),
                        const Text(
                          "History",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.orange),
                onPressed: () {
                  if (_packsActiveTabIndex == 0) {
                    _showPackFilterModal(
                        true,
                        Provider.of<HomePageProvider>(context, listen: false)
                            .activePacks);
                  } else {
                    _showPackFilterModal(
                        false,
                        Provider.of<HomePageProvider>(context, listen: false)
                            .lastPacks);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(color: Colors.orange),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 100,
                    color: Colors.grey[50],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPackCard(dynamic pack) {
    final isGroup = pack['type'].toString().toLowerCase() == 'group';
    return InkWell(
      onTap: () => _showPackCardOptions(pack),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 16),
              InkWell(
                onTap: () {
                  if (pack['type'].toString().toLowerCase() == 'group') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Scheduling Unavailable"),
                        content: const Text(
                            "To change the schedule of a group lesson, please contact the school."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"),
                          )
                        ],
                      ),
                    );
                  } else {
                    _showScheduleMultipleLessonsModal(
                        pack['lessons'], pack["expiration_date"]);
                  }
                },
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.calendar_today,
                      size: 28, color: Colors.orange),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack['students_name'],
                      style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pack['lessons_remaining']} lessons remaining\n'
                      '${pack['unscheduled_lessons']} unscheduled lessons\n'
                      '${pack['days_until_expiration']} days until expiration',
                      style:
                          GoogleFonts.lato(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGroup ? Icons.groups : Icons.person,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      showPackDetailsModal(pack);
                    },
                    child: const Icon(Icons.more_vert,
                        size: 28, color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSkeleton() {
    return Column(
      children: List.generate(3, (index) => _buildLoadingCard()),
    );
  }

  Widget _buildAdminStats(HomePageProvider homeProvider) {
    final formattedStart =
        DateFormat('MMM dd, yyyy').format(homeProvider.startDate);
    final formattedEnd =
        DateFormat('MMM dd, yyyy').format(homeProvider.endDate);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "$formattedStart - $formattedEnd",
                      style: GoogleFonts.lato(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.calendar_today, color: Colors.orange),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) {
                          return Container(
                            height: 400,
                            padding: const EdgeInsets.all(16),
                            child: SfDateRangePicker(
                              view: DateRangePickerView.month,
                              selectionMode: DateRangePickerSelectionMode.range,
                              initialSelectedRange: PickerDateRange(
                                  homeProvider.startDate, homeProvider.endDate),
                              showActionButtons: true,
                              onSubmit: (Object? val) {
                                if (val is PickerDateRange) {
                                  homeProvider.startDate = val.startDate!;
                                  homeProvider.endDate =
                                      val.endDate ?? val.startDate!;
                                  homeProvider.fetchAdminMetrics();
                                }
                                Navigator.pop(context);
                              },
                              onCancel: () => Navigator.pop(context),
                              monthViewSettings:
                                  const DateRangePickerMonthViewSettings(
                                firstDayOfWeek: 1,
                                showTrailingAndLeadingDates: true,
                              ),
                              headerStyle: const DateRangePickerHeaderStyle(
                                textAlign: TextAlign.center,
                                textStyle: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                    "Lessons", homeProvider.numberOfBookings.toString(),
                    actionLabel: "View lessons",
                    icon: Icons.menu_book,
                    onAction: null),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: _buildStatCard(
                    "Students", homeProvider.numberOfStudents.toString(),
                    actionLabel: "View students",
                    icon: Icons.people,
                    onAction: null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                    "Instructors", homeProvider.numberOfInstructors.toString(),
                    actionLabel: "View instructors",
                    icon: Icons.person_outline,
                    onAction: null),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: _buildStatCard(
                    "Revenue", homeProvider.totalRevenue.toStringAsFixed(2),
                    actionLabel: "View payments",
                    icon: Icons.payments_outlined,
                    onAction: null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorStats(HomePageProvider homeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
                "Students", homeProvider.numberOfActiveStudents.toString(),
                actionLabel: "View students",
                icon: Icons.people,
                onAction: null),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: _buildStatCard(
                "Balance", homeProvider.currentBalance.toStringAsFixed(2),
                actionLabel: "View payments",
                icon: Icons.payments_outlined,
                onAction: null),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value,
      {String? actionLabel, IconData? icon, VoidCallback? onAction}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 80),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.lato(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          value,
                          style: GoogleFonts.lato(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(icon, color: Colors.orange),
                    onPressed: onAction,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (actionLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                actionLabel,
                style: GoogleFonts.lato(fontSize: 12, color: Colors.orange),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoStats() {
    return const Center(child: Text("No stats available"));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomePageProvider>(
      create: (_) => HomePageProvider(),
      child: Consumer<HomePageProvider>(
        builder: (context, homeProvider, child) {
          // Build Lessons Tab.
          Widget lessonsTab = _lessonsActiveTabIndex == 0
              ? RefreshIndicator(
                  color: Colors.orange,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await homeProvider.fetchData();
                  },
                  child: SingleChildScrollView(
                    controller: _lessonsScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Moved toggle row inside the scrollable content.
                        _buildToggleRowForLessons(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: homeProvider.isLoading
                              ? Column(
                                  children: List.generate(
                                      3, (index) => _buildLoadingCard()),
                                )
                              : Builder(builder: (context) {
                                  // Retrieve the filtered active lessons list.
                                  final activeLessons = _filterLessons(
                                    homeProvider.upcomingLessons,
                                    upcomingSearchQuery,
                                    upcomingFilters,
                                  );

                                  // Map group titles to their background colors.
                                  final Map<String, Color> groupColors = {
                                    'Need Reschedule': Colors.red,
                                    'Today': Colors.orange,
                                    'Upcoming': Colors.grey,
                                  };

                                  // Create groups (assumes each lesson has a "status" field).
                                  final Map<String, List<dynamic>>
                                      groupedLessons = {
                                    'Today': [],
                                    'Need Reschedule': [],
                                    'Upcoming': [],
                                  };

                                  // Group the lessons based on the 'status' field.
                                  for (var lesson in activeLessons) {
                                    String status =
                                        lesson['status'] ?? 'Upcoming';
                                    if (!groupedLessons.containsKey(status)) {
                                      status = 'Upcoming';
                                    }
                                    groupedLessons[status]!.add(lesson);
                                  }

                                  // Build a list of grouped cards.
                                  List<Widget> groupedCards = [];
                                  groupedLessons.forEach((group, lessons) {
                                    if (lessons.isNotEmpty) {
                                      // Build individual lesson card widgets using your existing method.
                                      final lessonWidgets =
                                          lessons.map((lesson) {
                                        return Provider.of<LessonModalProvider>(
                                                context,
                                                listen: false)
                                            .buildLessonCard(
                                          context,
                                          lesson,
                                          Provider.of<PackDetailsProvider>(
                                                  context)
                                              .unschedulableLessons,
                                          isLastLesson: false,
                                        );
                                      }).toList();

                                      groupedCards.add(
                                        buildGroupedLessonCard(group,
                                            groupColors[group]!, lessonWidgets),
                                      );
                                    }
                                  });

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: groupedCards,
                                  );
                                }),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: Colors.orange,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await homeProvider.fetchData();
                  },
                  child: SingleChildScrollView(
                    controller: _lessonsScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Moved toggle row inside the scrollable content.
                        _buildToggleRowForLessons(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: homeProvider.isLoading
                              ? Column(
                                  children: List.generate(
                                      3, (index) => _buildLoadingCard()),
                                )
                              : _filterLessons(
                                          homeProvider.lastLessons,
                                          lastLessonsSearchQuery,
                                          lastLessonsFilters)
                                      .isNotEmpty
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: _filterLessons(
                                              homeProvider.lastLessons,
                                              lastLessonsSearchQuery,
                                              lastLessonsFilters)
                                          .map((lesson) => Provider.of<
                                                      LessonModalProvider>(
                                                  context,
                                                  listen: false)
                                              .buildLessonCard(
                                                  context,
                                                  lesson,
                                                  Provider.of<PackDetailsProvider>(
                                                          context)
                                                      .unschedulableLessons,
                                                  isLastLesson: true))
                                          .toList(),
                                    )
                                  : const Center(
                                      child: Text("No historical lessons")),
                        ),
                      ],
                    ),
                  ),
                );

          // Build Packs Tab.
          Widget packsTab = _packsActiveTabIndex == 0
              ? RefreshIndicator(
                  color: Colors.orange,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await homeProvider.fetchData();
                  },
                  child: SingleChildScrollView(
                    controller: _packsScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Moved toggle row inside the scrollable content.
                        _buildToggleRowForPacks(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: homeProvider.isLoading
                              ? Column(
                                  children: List.generate(
                                      3, (index) => _buildLoadingCard()),
                                )
                              : _filterPacks(
                                          homeProvider.activePacks,
                                          activePacksSearchQuery,
                                          activePacksFilters)
                                      .isNotEmpty
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: _filterPacks(
                                              homeProvider.activePacks,
                                              activePacksSearchQuery,
                                              activePacksFilters)
                                          .map((pack) => _buildPackCard(pack))
                                          .toList(),
                                    )
                                  : const Center(
                                      child: Text("No active packs")),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: Colors.orange,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await homeProvider.fetchData();
                  },
                  child: SingleChildScrollView(
                    controller: _packsScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Moved toggle row inside the scrollable content.
                        _buildToggleRowForPacks(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: homeProvider.isLoading
                              ? Column(
                                  children: List.generate(
                                      3, (index) => _buildLoadingCard()),
                                )
                              : _filterPacks(
                                          homeProvider.lastPacks,
                                          lastPacksSearchQuery,
                                          lastPacksFilters)
                                      .isNotEmpty
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: _filterPacks(
                                              homeProvider.lastPacks,
                                              lastPacksSearchQuery,
                                              lastPacksFilters)
                                          .map((pack) => _buildPackCard(pack))
                                          .toList(),
                                    )
                                  : const Center(
                                      child: Text("No historical packs")),
                        ),
                      ],
                    ),
                  ),
                );

          // Build Stats Tab.
          Widget statsTab = (homeProvider.currentRole == "Admin" ||
                  homeProvider.currentRole == "Instructor")
              ? homeProvider.isLoading
                  ? _buildStatsSkeleton()
                  : (homeProvider.currentRole == "Admin"
                      ? _buildAdminStats(homeProvider)
                      : _buildInstructorStats(homeProvider))
              : _buildNoStats();

          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Column(
                  children: [
                    _buildHeader(homeProvider),
                    Expanded(
                      child: DefaultTabController(
                        length: 3,
                        child: Column(
                          children: [
                            TabBar(
                              labelColor: Colors.orange,
                              unselectedLabelColor: Colors.grey,
                              tabs: const [
                                Tab(text: "Lessons"),
                                Tab(text: "Packs"),
                                Tab(text: "Stats"),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  lessonsTab,
                                  packsTab,
                                  statsTab,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
