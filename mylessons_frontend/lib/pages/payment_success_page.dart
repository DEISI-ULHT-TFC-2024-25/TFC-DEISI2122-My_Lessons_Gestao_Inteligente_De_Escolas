import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'home_page.dart';

class PaymentSuccessPage extends StatefulWidget {
  const PaymentSuccessPage({Key? key}) : super(key: key);

  @override
  _PaymentSuccessPageState createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  final CartService _cartService = CartService();
  List<dynamic> bookedPacks = [];

  @override
  void initState() {
    super.initState();
    _processSuccess();
  }

  /// Process the successful payment by creating a Payment record for debt
  /// and then booking the packs.
  Future<void> _processSuccess() async {
    await _createDebtPaymentRecord();
    await _bookPacks();
  }

  /// Creates a Payment record for debt.
  /// It extracts the pack IDs from the cart items (for pack services),
  /// sends them to your backend endpoint so that a Payment object can be
  /// created with payment.user = request.user and the related packs.
  Future<void> _createDebtPaymentRecord() async {
    // Filter cart items that represent pack services.
    List<dynamic> packIds = _cartService.items.where((item) {
      if (item.containsKey('service') &&
          item['service'] is Map<String, dynamic>) {
        final service = item['service'];
        if (service.containsKey('type') &&
            service['type'] is Map<String, dynamic> &&
            service['type'].containsKey('pack')) {
          return true;
        }
      }
      return false;
    }).map((item) => item['id']).toList();

    Map<String, dynamic> payload = {
      "pack_ids": packIds,
    };

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/payments/create_debt_payment_record/"),
        headers: await getAuthHeaders(),
        body: json.encode(payload),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Debt Payment record created successfully: ${response.body}");
      } else {
        debugPrint(
            "Failed to create debt payment record: ${response.statusCode}, ${response.body}");
      }
    } catch (e) {
      debugPrint("Error creating debt payment record: $e");
    }
  }

  /// Books the packs using your existing booking endpoint.
  Future<void> _bookPacks() async {
    // Build payload only for items that represent a pack.
    List<Map<String, dynamic>> packsPayload = _cartService.items.where((item) {
      // Check if the cart item has a 'service' with a 'type' map containing the key 'pack'.
      if (item.containsKey('service') &&
          item['service'] is Map<String, dynamic>) {
        final service = item['service'];
        if (service.containsKey('type') &&
            service['type'] is Map<String, dynamic> &&
            service['type'].containsKey('pack')) {
          return true;
        }
      }
      return false;
    }).map((item) {
      final service = item['service'] as Map<String, dynamic>;
      final checkoutDetails = service.containsKey('checkout_details') &&
              service['checkout_details'] is Map<String, dynamic>
          ? service['checkout_details'] as Map<String, dynamic>
          : {};

      return {
        "students": item['students'],
        "school": service['school_name'] ?? "Test School",
        "expiration_date": DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String()
            .split('T')
            .first,
        "number_of_classes": checkoutDetails['classes'] ?? 0,
        "duration_in_minutes": checkoutDetails['duration'] ?? 0,
        "instructors": [],
        "price": item['price'],
        "payment": item['price'],
        "discount_id": null,
        "type": service['type'],
        // Flag to indicate that this booking comes from the success page.
        "user_paid": true,
      };
    }).toList();

    Map<String, dynamic> payload = {"packs": packsPayload};

    try {
      debugPrint("Cart service items:\n${_cartService.items}\n");
      debugPrint("Booking packs with payload:\n$payload\n");

      final response = await http.post(
        Uri.parse("$baseUrl/api/users/book_pack/"),
        headers: await getAuthHeaders(),
        body: json.encode(payload),
      );

      if (response.statusCode == 201) {
        _cartService.clear();
        debugPrint("Pack booking successful: ${response.body}");
        final decodedResponse = json.decode(response.body);
        setState(() {
          bookedPacks = decodedResponse["booked_packs"];
        });
      } else {
        debugPrint(
            "Failed to book packs. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error booking packs: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Successful")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Thank you for your payment!",
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/main',
                  (route) => false,
                  arguments: {'newBookedPacks': bookedPacks},
                );
              },
              child: const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
