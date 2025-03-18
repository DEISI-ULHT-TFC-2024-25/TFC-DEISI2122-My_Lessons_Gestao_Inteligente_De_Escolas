import 'package:flutter/material.dart';

class PaymentFailPage extends StatelessWidget {
  const PaymentFailPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Failed")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Payment was not successful.",
              style: TextStyle(fontSize: 20, color: Colors.red),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }
}
