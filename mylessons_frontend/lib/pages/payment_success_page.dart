import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mylessons_frontend/services/api_service.dart';
import 'package:mylessons_frontend/services/cart_service.dart';
import 'package:http/http.dart' as http;

class PaymentSuccessPage extends StatefulWidget {
  final String? sessionId;
  const PaymentSuccessPage({Key? key, this.sessionId}) : super(key: key);

  @override
  _PaymentSuccessPageState createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  bool _verified = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verifyPayment();
  }

  Future<void> _verifyPayment() async {
    if (widget.sessionId == null) {
      setState(() {
        _isLoading = false;
        _error = "No session ID provided.";
      });
      return;
    }

    try {
      // Replace $baseUrl with your actual base URL.
      final url = Uri.parse('$baseUrl/api/payments/verify_payment?session_id=${widget.sessionId}');
      final headers = await getAuthHeaders();
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['verified'] == true) {
          setState(() {
            _verified = true;
          });
          // Clear the cart only after successful verification.
          CartService().clear();
        } else {
          setState(() {
            _error = "Payment not verified.";
          });
        }
      } else {
        setState(() {
          _error = "Error verifying payment. Status code: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error verifying payment: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Successful")),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _verified
                      ? const Text(
                          "Your payment has been confirmed!",
                          style: TextStyle(fontSize: 20),
                        )
                      : Text(
                          _error ?? "Payment confirmation pending.",
                          style: const TextStyle(fontSize: 20, color: Colors.red),
                        ),
                  if (widget.sessionId != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("Session ID: ${widget.sessionId}"),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to the main screen (or home).
                      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
                    },
                    child: const Text("Continue"),
                  ),
                ],
              ),
      ),
    );
  }
}
