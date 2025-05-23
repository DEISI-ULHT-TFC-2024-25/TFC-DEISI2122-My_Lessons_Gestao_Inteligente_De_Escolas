import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // Exports getAuthHeaders() and baseUrl

/// Show add payment modal, passing the dynamic pack object directly
Future<T?> showAddPaymentModal<T>(
  BuildContext context, {
  required Map<String, dynamic> pack,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      final maxHeight = MediaQuery.of(context).size.height * 0.9;
      return SizedBox(
        height: maxHeight,
        child: AddPaymentModal(
          pack: pack,
        ),
      );
    },
  );
}

class AddPaymentModal extends StatefulWidget {
  final Map<String, dynamic> pack;

  const AddPaymentModal({
    Key? key,
    required this.pack,
  }) : super(key: key);

  @override
  _AddPaymentModalState createState() => _AddPaymentModalState();
}

class _AddPaymentModalState extends State<AddPaymentModal> {
  final TextEditingController _amountController = TextEditingController();
  late List<Map<String, dynamic>> _parents;
  int? _selectedParentId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Convert string IDs to ints if needed
    _parents = List<Map<String, dynamic>>.from(widget.pack['parents'] as List)
        .map((p) => {
              'id': p['id'] is String ? int.parse(p['id']) : p['id'],
              'name': p['name'],
            })
        .toList();
  }

  Future<void> _savePayment() async {
    final value = _amountController.text.trim();
    if (value.isEmpty || _selectedParentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter amount and select a parent')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final headers = await getAuthHeaders();

      final packIdRaw = widget.pack['pack_id'];
      final packId = packIdRaw is String ? int.parse(packIdRaw) : packIdRaw;

      final payload = {
        'user': _selectedParentId,
        'pack_ids': [packId],
        'pack_amounts': {
          packId.toString(): value,
        },
      };

      debugPrint('→ POST to create_debt_payment_record');
      debugPrint('   URL: $baseUrl/api/payments/create_debt_payment_record/');
      debugPrint('   headers: $headers');
      debugPrint('   body: ${jsonEncode(payload)}');

      final res = await http.post(
        Uri.parse('$baseUrl/api/payments/create_debt_payment_record/'),
        headers: headers,
        body: jsonEncode(payload),
      );

      debugPrint('← status ${res.statusCode}, body ${res.body}');

      if (res.statusCode == 201) {
        Navigator.of(context).pop(true);
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['error'] ?? 'Unknown error');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.numberWithOptions(
                                      decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Amount',
                                    prefixIcon: Icon(Icons.attach_money),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  value: _selectedParentId,
                                  items: _parents
                                      .map((p) => DropdownMenuItem<int>(
                                            value: p['id'] as int,
                                            child: Text(p['name'] as String),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedParentId = v),
                                  decoration: const InputDecoration(
                                    labelText: 'Select Parent',
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.center,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // TODO: implement associate parent flow
                                    },
                                    child: const Text('Associate Parent'),
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
          // Save button pinned to bottom
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _isLoading ? null : _savePayment,
                child: const Text(
                  'Save Payment',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
