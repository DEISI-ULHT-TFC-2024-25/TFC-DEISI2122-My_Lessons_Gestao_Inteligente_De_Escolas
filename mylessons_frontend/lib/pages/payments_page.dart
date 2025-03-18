import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({Key? key}) : super(key: key);

  @override
  _PaymentsPageState createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  bool _loading = true;
  double _debt = 0;
  List<Map<String, dynamic>> _unpaid = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final headers = await getAuthHeaders();
    try {
      final debtRes = await http.get(Uri.parse('$baseUrl/api/payments/debt/'), headers: headers);
      final unpaidRes = await http.get(Uri.parse('$baseUrl/api/payments/unpaid_items/'), headers: headers);
      final historyRes = await http.get(Uri.parse('$baseUrl/api/payments/history/'), headers: headers);

      if (debtRes.statusCode == 200) {
        _debt = double.tryParse(json.decode(debtRes.body)['current_debt'].toString()) ?? 0;
      }
      if (unpaidRes.statusCode == 200) {
        _unpaid = List<Map<String, dynamic>>.from(json.decode(unpaidRes.body));
      }
      if (historyRes.statusCode == 200) {
        _history = List<Map<String, dynamic>>.from(json.decode(historyRes.body));
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: Colors.orange,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.orange))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildUnpaidCard(),
                    const SizedBox(height: 24),
                    _buildHistoryCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildUnpaidCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unpaid Items', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_debt.toStringAsFixed(2)}€', style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
                ElevatedButton(
                  onPressed: () {/* open payment flow */},
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32))),
                  child: const Text('Pay Debt'),
                ),
              ],
            ),
            const Divider(height: 32),
            if (_unpaid.isEmpty)
              Text('No unpaid items', style: GoogleFonts.lato(color: Colors.black54))
            else
              ..._unpaid.map(_buildRow).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment History', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_history.isEmpty)
              Text('No payment history', style: GoogleFonts.lato(color: Colors.black54))
            else
              ..._history.map(_buildRow).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> item) {
    final date = DateTime.tryParse(item['date'] ?? '') ?? DateTime.now();
    final formatted = '${date.day.toString().padLeft(2,'0')}-${date.month.toString().padLeft(2,'0')}-${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(formatted, style: GoogleFonts.lato())),
          Expanded(child: Text(item['description'] ?? '', style: GoogleFonts.lato())),
          Text('${(item['amount'] ?? 0).toStringAsFixed(2)}€', style: GoogleFonts.lato()),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove_red_eye, color: Colors.orange),
            onPressed: () {/* view details */},
          ),
        ],
      ),
    );
  }
}
