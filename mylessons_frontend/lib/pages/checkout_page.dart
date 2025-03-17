import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';

/// Helper function to get the currency symbol.
String getCurrencySymbol(String currencyCode) {
  return NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
}

class CheckoutPage extends StatefulWidget {
  final VoidCallback onBack; // Callback to return to the main view.
  const CheckoutPage({super.key, required this.onBack});

  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  List<Map<String, dynamic>> get cartItems => CartService().items;

  // Derives the currency symbol from the first cart item.
  String get cartCurrencySymbol {
    if (cartItems.isEmpty) return '';
    final firstItem = cartItems.first;
    final checkoutDetails =
        firstItem['service']['checkout_details'] as Map<String, dynamic>? ?? {};
    final currencyCode = checkoutDetails['currency'] ?? 'N/A';
    return getCurrencySymbol(currencyCode);
  }

  // Calculate the total using the numeric price from each item.
  double get totalPrice {
    double total = 0;
    for (var item in cartItems) {
      final checkoutDetails =
          item['service']['checkout_details'] as Map<String, dynamic>? ?? {};
      final rawPrice = checkoutDetails['price'];
      if (rawPrice != null) {
        total += rawPrice is double
            ? rawPrice
            : double.tryParse(rawPrice.toString()) ?? 0;
      }
    }
    return total;
  }

  void _removeItem(int index) {
    setState(() {
      CartService().removeAt(index);
    });
  }

  Future<void> _handleConfirmBooking() async {
    final cartItems = CartService().items;
    // Filter only pack services.
    final packItems = cartItems.where((item) {
      final service = item['service'] as Map<String, dynamic>;
      return service['type'] is Map && service['type'].containsKey('pack');
    }).toList();

    if (packItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No pack services found in your cart.")),
      );
      return;
    }

    // Save a copy of the checkout items (so we can show their card in the scheduling modal).
    final List<Map<String, dynamic>> checkoutPackItems =
        List<Map<String, dynamic>>.from(packItems);

    setState(() {
      _isLoading = true;
    });

    // Build a booking payload for each pack.
    List<Map<String, dynamic>> bookings = [];
    for (var packItem in packItems) {
      final checkoutDetails =
          packItem['service']['checkout_details'] as Map<String, dynamic>;

      // Determine timeLimit from checkoutDetails['time_limit'].
      final dynamic rawTimeLimit = checkoutDetails['time_limit'] ?? "0";
      final int timeLimitDays = rawTimeLimit is int
          ? rawTimeLimit
          : int.tryParse(rawTimeLimit.toString()) ?? 0;
      // Calculate expiration date.
      final expirationDate = DateTime.now().add(Duration(days: timeLimitDays));
      final formattedExpirationDate =
          expirationDate.toIso8601String().split("T")[0];

      final bookingPayload = {
        "students": packItem['students'] ?? [],
        "school": checkoutDetails['school_name'] ?? 'default_school_id',
        "expiration_date": formattedExpirationDate,
        "number_of_classes": checkoutDetails['classes'],
        "duration_in_minutes": checkoutDetails['duration'],
        "instructors": packItem['service']['instructors'] ?? [],
        "price": checkoutDetails['price'],
        "payment": "cash",
        "discount_id": null,
        "type": checkoutDetails['type'] is Map &&
                checkoutDetails['type'].containsKey('pack')
            ? checkoutDetails['type']['pack']
            : checkoutDetails['type'] ?? "private",
      };

      bookings.add(bookingPayload);
    }

    final body = jsonEncode({"packs": bookings});
    final url = Uri.parse('$baseUrl/api/users/book_pack/');
    final headers = await getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All packs booked successfully! Please pay by cash upon service."),
          ),
        );

        // Decode the JSON response body.
        final Map<String, dynamic> responseData = json.decode(response.body);
        // Extract the booked packs list.
        final List<dynamic> bookedPacks = responseData['booked_packs'];

        // Filter only private packs (where "type" is not "group")
        final List<dynamic> privatePacks = bookedPacks.where((packItem) {
          final type = packItem['type'];
          return type.toLowerCase() != 'group';
        }).toList();

        // Pair each private pack with its corresponding checkout item.
        // (Assuming the order of packItems is maintained.)
        List<Map<String, dynamic>> packsToSchedule = [];
        for (int i = 0; i < privatePacks.length; i++) {
          packsToSchedule.add({
            "bookedPack": privatePacks[i],
            "checkoutItem": checkoutPackItems[i],
          });
        }

        // Sequentially schedule the first lesson of each private pack.
        await _schedulePrivatePacks(packsToSchedule);

        // Finally clear the cart and redirect to home.
        CartService().clear();
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Booking failed: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _schedulePrivateLesson(int lessonId, DateTime newDate, String newTime) =>
      schedulePrivateLesson(lessonId, newDate, newTime);

  Future<List<String>> _fetchAvailableTimes(int lessonId, DateTime date, int increment) =>
      fetchAvailableTimes(lessonId, date, increment);

  Future<void> _showScheduleLessonModal(dynamic lesson, Map<String, dynamic> checkoutItem) async {
    final int lessonId = lesson['id'] ?? lesson['lesson_id'];
    DateTime? selectedDate;
    int increment = 60;
    List<String> availableTimes = [];
    bool isLoading = false;

    // Fetch the school's schedule time limit (in hours) from the API.
    int schoolScheduleTimeLimit = await fetchSchoolScheduleTimeLimit(lesson["school"]);
    debugPrint("school schedule limit: $schoolScheduleTimeLimit");

    return await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        // Use sheetContext for Navigator calls later.
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with title and checkout card.
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Schedule The First Lesson",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildCheckoutCard(checkoutItem),
                          const Divider(),
                        ],
                      ),
                    ),
                    // Date picker widget.
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      child: SfDateRangePicker(
                        view: DateRangePickerView.month,
                        selectionMode: DateRangePickerSelectionMode.single,
                        showActionButtons: true,
                        // Set the initialDisplayDate and minDate to now + schoolScheduleTimeLimit (in hours).
                        initialDisplayDate: DateTime.now().add(
                          Duration(hours: schoolScheduleTimeLimit),
                        ),
                        minDate: DateTime.now().add(
                          Duration(hours: schoolScheduleTimeLimit),
                        ),
                        maxDate: lesson['expiration_date'] != "None"
                            ? DateTime.parse(lesson['expiration_date'])
                            : null,
                        onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                          if (args.value is DateTime) {
                            setModalState(() {
                              selectedDate = args.value;
                              availableTimes = [];
                              isLoading = true;
                            });
                            _fetchAvailableTimes(lessonId, selectedDate!, increment)
                                .then((times) {
                              setModalState(() {
                                availableTimes = times;
                                isLoading = false;
                              });
                            });
                          }
                        },
                        monthViewSettings: const DateRangePickerMonthViewSettings(
                          firstDayOfWeek: 1,
                          showTrailingAndLeadingDates: true,
                        ),
                        headerStyle: const DateRangePickerHeaderStyle(
                          textAlign: TextAlign.center,
                          textStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Dropdown for time increment selection.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          const Text("Increment: "),
                          DropdownButton<int>(
                            value: increment,
                            items: [15, 30, 60].map((value) {
                              return DropdownMenuItem<int>(
                                value: value,
                                child: Text("$value minutes"),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              if (newValue != null) {
                                setModalState(() {
                                  increment = newValue;
                                  if (selectedDate != null) {
                                    isLoading = true;
                                    availableTimes = [];
                                  }
                                });
                                if (selectedDate != null) {
                                  _fetchAvailableTimes(lessonId, selectedDate!, increment)
                                      .then((times) {
                                    setModalState(() {
                                      availableTimes = times;
                                      isLoading = false;
                                    });
                                  });
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    if (isLoading) const CircularProgressIndicator(),
                    if (!isLoading && availableTimes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: availableTimes.length,
                          itemBuilder: (context, index) {
                            String timeStr = availableTimes[index];
                            return InkWell(
                              onTap: () {
                                // Use sheetContext when showing the dialog.
                                showDialog(
                                  context: sheetContext,
                                  builder: (BuildContext dialogContext) {
                                    return AlertDialog(
                                      title: const Text("Confirm Reschedule"),
                                      content: Text(
                                        "Reschedule lesson to ${DateFormat('d MMM yyyy').format(selectedDate!).toLowerCase()} at $timeStr?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(dialogContext).pop(),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(dialogContext).pop(); // Close the dialog.
                                            _schedulePrivateLesson(lessonId, selectedDate!, timeStr)
                                                .then((errorMessage) {
                                              if (errorMessage == null) {
                                                // Use sheetContext to pop the bottom sheet.
                                                Navigator.of(sheetContext).pop();
                                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                                  const SnackBar(
                                                    content: Text("Lesson successfully rescheduled"),
                                                  ),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                                  SnackBar(
                                                    content: Text(errorMessage),
                                                  ),
                                                );
                                              }
                                            });
                                          },
                                          child: const Text("Confirm"),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _schedulePrivatePacks(List<Map<String, dynamic>> packsToSchedule) async {
    if (packsToSchedule.isEmpty) return;
    final currentPack = packsToSchedule.first;
    // We assume that currentPack['bookedPack']['lessons'] is a list.
    // Pass both the first lesson and the checkout item to the scheduling modal.
    await _showScheduleLessonModal(currentPack["bookedPack"]["lessons"][0], currentPack["checkoutItem"]);
    // Remove the current pack and recursively schedule the next one.
    packsToSchedule.removeAt(0);
    await _schedulePrivatePacks(packsToSchedule);
  }

  bool _isLoading = false;

  /// Initiates Stripe Checkout.
  /// This function calls your backend to create a Stripe Checkout session using your cart data.
  Future<void> _initiateStripeCheckout() async {
    try {
      // Transform your cart items into the expected payload structure.
      List<Map<String, dynamic>> stripeCart = CartService().items.map((item) {
        final checkoutDetails =
            item['service']['checkout_details'] as Map<String, dynamic>? ?? {};
        return {
          "type": checkoutDetails['type'] is Map
              ? checkoutDetails['type']['pack']
              : checkoutDetails['type'] ?? "private",
          "number_of_classes": checkoutDetails['classes'],
          "duration_in_minutes": checkoutDetails['duration'],
          "price": checkoutDetails['price'],
          "student_ids_list": item['students'] ?? [],
          "school_name": checkoutDetails['school_name'] ?? "",
        };
      }).toList();

      // Build the JSON payload. Adjust discount value if needed.
      final body = jsonEncode({
        "cart": stripeCart,
        "discount": 0,
      });

      // Use $baseUrl for your backend endpoint.
      final url = Uri.parse('$baseUrl/api/payments/create_checkout_session/');
      // Await the auth headers.
      final headers = await getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final checkoutUrl = jsonResponse['url'];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Redirecting to Stripe Checkout...")),
        );
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          throw 'Could not launch checkout session URL';
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error initiating Stripe Checkout: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Stripe checkout error: $e")),
      );
    }
  }

  Widget _buildCheckoutCard(Map<String, dynamic> checkoutItem) {
    final service = checkoutItem['service'] as Map<String, dynamic>? ?? {};
    final checkoutDetails = service['checkout_details'] as Map<String, dynamic>? ?? {};

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${checkoutDetails['service_name'] ?? 'N/A'} - ${checkoutDetails['school_name'] ?? 'N/A'}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Text("Duration: ${checkoutDetails['duration'] ?? 'N/A'} minutes"),
            Text("Number of Classes: ${checkoutDetails['classes'] ?? 'N/A'}"),
            Text("Number of Students: ${checkoutDetails['number_of_students'] ?? 'N/A'}"),
            const SizedBox(height: 4),
            if (checkoutDetails['student_names'] is List)
              ...List<String>.from(checkoutDetails['student_names'])
                  .map((name) => Text("    - $name")),
            const SizedBox(height: 4),
            Text("Time Limit: ${checkoutDetails['time_limit'] ?? 'N/A'} days"),
            Text("Price: ${checkoutDetails['formatted_price'] ?? 'N/A'}"),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// Build a details card using the checkout_details from the service.
  /// The [index] is used to remove the item when the delete icon is tapped.
  Widget _buildDetailsCard(Map<String, dynamic> cartItem, int index) {
    final service = cartItem['service'] as Map<String, dynamic>? ?? {};
    final checkoutDetails = service['checkout_details'] as Map<String, dynamic>? ?? {};

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        margin: const EdgeInsets.all(8.0),
        child: Stack(
          children: [
            // Card content.
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${checkoutDetails['service_name'] ?? 'N/A'} - ${checkoutDetails['school_name'] ?? 'N/A'}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Text("Duration: ${checkoutDetails['duration'] ?? 'N/A'} minutes"),
                  Text("Number of Classes: ${checkoutDetails['classes'] ?? 'N/A'}"),
                  Text("Number of Students: ${checkoutDetails['number_of_students'] ?? 'N/A'}"),
                  const SizedBox(height: 4),
                  if (checkoutDetails['student_names'] is List)
                    ...List<String>.from(checkoutDetails['student_names'])
                        .map((name) => Text("    - $name")),
                  const SizedBox(height: 4),
                  Text("Time Limit: ${checkoutDetails['time_limit'] ?? 'N/A'} days"),
                  Text("Price: ${checkoutDetails['formatted_price'] ?? 'N/A'}"),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            // Delete icon positioned at bottom right inside the card.
            Positioned(
              bottom: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _removeItem(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Checkout Confirmation"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: cartItems.isEmpty
                ? const Center(child: Text("Your cart is empty"))
                : ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      return _buildDetailsCard(cartItems[index], index);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  "Total: $cartCurrencySymbol${totalPrice.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // Payment options buttons.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cash Payment Button calls the integrated booking method.
                    ElevatedButton(
                      onPressed: _handleConfirmBooking,
                      child: const Text("Pay by Cash"),
                    ),
                    // Stripe Checkout Button.
                    ElevatedButton(
                      onPressed: _initiateStripeCheckout,
                      child: const Text("Pay Now"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
