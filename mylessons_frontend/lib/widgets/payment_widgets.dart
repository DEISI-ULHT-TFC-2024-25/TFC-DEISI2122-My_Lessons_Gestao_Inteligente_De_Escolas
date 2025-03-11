import 'package:flutter/material.dart';
import '../modals/payment_modal.dart';

Widget buildPaymentDetailsWidget(dynamic details) {
  if (details is Map<String, dynamic>) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${e.key}: ",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Expanded(child: Text(e.value.toString())),
            ],
          ),
        );
      }).toList(),
    );
  } else if (details is List) {
    return Text(details.join(", "));
  } else {
    return Text(details?.toString() ?? "N/A");
  }
}

/// Updated buildPaymentTypesWidget with optional parameters for editing.
/// When these optional parameters are provided, an edit icon is added to each card.
Widget buildPaymentTypesWidget(
  Map<String, dynamic> paymentTypes, {
  BuildContext? context,
  Map<String, dynamic>? schoolDetails,
  TextEditingController? schoolNameController,
  Future<void> Function()? refreshSchoolDetails,
  String? userId,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: paymentTypes.entries.map((entry) {
      // Build a map of preselected options.
      Map<String, dynamic> preselectedOptions = {};
      preselectedOptions["role"] = entry.key;
      if (entry.key.toLowerCase() == "admin") {
        preselectedOptions["paymentMode"] = "fixed";
        if (entry.value is Map && entry.value.containsKey("fixed monthly rate")) {
          preselectedOptions["fixedMonthlyRate"] = entry.value["fixed monthly rate"];
        }
      } else if (entry.value is Map) {
        preselectedOptions["paymentMode"] = "lesson";
        if (entry.value.containsKey("private")) {
          preselectedOptions["lessonType"] = "private";
          if (entry.value["private"] is Map) {
            var details = entry.value["private"];
            if (details.containsKey("commission")) {
              preselectedOptions["commission"] = details["commission"];
            }
            if (details.containsKey("fixed")) {
              preselectedOptions["fixedPricingList"] = details["fixed"];
            }
          }
        } else if (entry.value.containsKey("group")) {
          preselectedOptions["lessonType"] = "group";
          if (entry.value["group"] is Map) {
            var details = entry.value["group"];
            if (details.containsKey("commission")) {
              preselectedOptions["commission"] = details["commission"];
            }
            if (details.containsKey("fixed")) {
              preselectedOptions["fixedPricingList"] = details["fixed"];
            }
          }
        }
      }

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: _buildPaymentTypeContent(entry.key, entry.value, 0),
            ),
            // Only display the edit icon if all optional parameters are provided.
            if (context != null &&
                schoolDetails != null &&
                schoolNameController != null &&
                refreshSchoolDetails != null)
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange,),
                  onPressed: () {
                    showPaymentTypeModal(
                      context,
                      schoolDetails,
                      schoolNameController,
                      refreshSchoolDetails,
                      userId: userId,
                      preselectedOptions: preselectedOptions,
                    );
                  },
                ),
              ),
          ],
        ),
      );
    }).toList(),
  );
}

/// Formats the fixed price details in a single line.
String formatFixedPriceDetails(Map<String, dynamic> fixed) {
  final duration = fixed["duration"];
  final minStudents = fixed["min_students"];
  final maxStudents = fixed["max_students"];
  final price = fixed["price"];
  final priceFormatted =
      (price is num) ? price.toStringAsFixed(2) : price?.toString() ?? "";
  return "$duration min - $minStudents to $maxStudents students - $priceFormatted";
}

/// Recursively builds the widget for a payment type entry with indentation.
Widget _buildPaymentTypeContent(String key, dynamic value, int indentLevel) {
  final indent = EdgeInsets.only(left: indentLevel * 16.0);

  if (key.toLowerCase() == 'fixed') {
    if (value is List) {
      return Padding(
        padding: indent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: value.map<Widget>((pricing) {
            if (pricing is Map<String, dynamic>) {
              return Text(
                formatFixedPriceDetails(pricing),
                style: const TextStyle(fontSize: 14),
              );
            } else {
              return const SizedBox.shrink();
            }
          }).toList(),
        ),
      );
    } else if (value is Map<String, dynamic>) {
      return Padding(
        padding: indent,
        child: Text(
          formatFixedPriceDetails(value),
          style: const TextStyle(fontSize: 14),
        ),
      );
    }
  }

  if (value is Map<String, dynamic>) {
    final orderedKeys = _sortKeys(value.keys);
    return Padding(
      padding: indent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...orderedKeys.map(
            (k) => Column(
              children: [
                _buildPaymentTypeContent(k, value[k], indentLevel + 1),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  } else {
    String displayValue = value.toString();
    if (key.toLowerCase() == 'commission') {
      displayValue = "$displayValue %";
    } else if (key.toLowerCase() == 'duration') {
      displayValue = "$displayValue min";
    } else if (key.toLowerCase() == 'price' && value is num) {
      displayValue = value.toStringAsFixed(2);
    }
    return Padding(
      padding: indent,
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: "$key: ",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black),
            ),
            TextSpan(
              text: displayValue,
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sorts the keys so that certain fields come in a specific order.
List<String> _sortKeys(Iterable<String> keys) {
  const priority = ["duration", "min_students", "max_students", "price"];

  List<String> sortedKeys = List.from(keys);
  sortedKeys.sort((a, b) {
    final indexA = priority.indexOf(a);
    final indexB = priority.indexOf(b);
    if (indexA == -1 && indexB == -1) {
      return a.compareTo(b);
    } else if (indexA == -1) {
      return 1;
    } else if (indexB == -1) {
      return -1;
    } else {
      return indexA.compareTo(indexB);
    }
  });
  return sortedKeys;
}
