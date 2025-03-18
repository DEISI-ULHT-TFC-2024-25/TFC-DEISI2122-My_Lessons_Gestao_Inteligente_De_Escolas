import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'payment_success_page.dart';
import 'payment_fail_page.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({Key? key}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = false;
  String? _clientSecret;
  double totalPrice = 0.0;
  double discount = 0.0; // Adjust if needed

  @override
  void initState() {
    super.initState();
    // Get real cart data from CartService.
    final cartItems = CartService().items;
    totalPrice = 0.0;
    for (var item in cartItems) {
      final price = item['price'];
      if (price != null) {
        totalPrice += (price is double ? price : double.tryParse(price.toString()) ?? 0.0);
      }
    }
    _createPaymentIntent();
  }

  /// Calls the backend to create a PaymentIntent.
  Future<void> _createPaymentIntent() async {
    setState(() {
      _loading = true;
    });
    try {
      final cartItems = CartService().items;
      final Map<String, dynamic> payload = {
        "cart": cartItems,
        "discount": discount,
      };

      final url = Uri.parse('$baseUrl/api/payments/create_payment_intent/');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _clientSecret = data["clientSecret"];
        // Initialize PaymentSheet using the client secret.
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: _clientSecret!,
            merchantDisplayName: 'MyLessons',
          ),
        );
      } else {
        debugPrint("Error creating PaymentIntent: ${response.body}");
      }
    } catch (e) {
      debugPrint("Exception in _createPaymentIntent: $e");
    }
    setState(() {
      _loading = false;
    });
  }

  /// Presents the PaymentSheet to the user.
  Future<void> _presentPaymentSheet() async {
    try {
      await Stripe.instance.presentPaymentSheet();
      // Payment succeeded: clear the cart and navigate to PaymentSuccessPage.
      CartService().clear();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
      );
    } catch (e) {
      debugPrint("PaymentSheet error: $e");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PaymentFailPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Payment"),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Total: €${totalPrice.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _clientSecret != null ? _presentPaymentSheet : null,
                    child: const Text("Pay Now"),
                  ),
                ],
              ),
      ),
    );
  }
}
