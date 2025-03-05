import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Converts a currency code (e.g. "EUR", "USD") to its typical symbol (€, $).
/// Requires the "intl" package in your pubspec.yaml.
String getCurrencySymbol(String currencyCode) {
  return NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
}

class ServicePricingTable extends StatelessWidget {
  final Map<String, dynamic> service;

  const ServicePricingTable({
    Key? key,
    required this.service,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pricingOptions =
        service['details']?['pricing_options'] as List<dynamic>? ?? [];

    // If there's no pricing, just return a message.
    if (pricingOptions.isEmpty) {
      return const Text('No pricing options available.');
    }

    // Extract distinct durations, people counts, and class counts from the data.
    // Sort them to have a predictable order in the table.
    final durations = pricingOptions
        .map((opt) => opt['duration'] as int)
        .toSet()
        .toList()
      ..sort();
    final peopleList = pricingOptions
        .map((opt) => opt['people'] as int)
        .toSet()
        .toList()
      ..sort();
    final classesList = pricingOptions
        .map((opt) => opt['classes'] as int)
        .toSet()
        .toList()
      ..sort();

    // We'll build a single Table with:
    // - One header row
    // - For each duration: a "section heading" row, plus data rows for each classes value.

    // Currency symbol from service (e.g. "€")
    final currencySymbol = getCurrencySymbol(service['currency'] ?? 'EUR');

    // Build up all table rows in a list.
    final List<TableRow> allRows = [];

    // 1) Build the main header row (Package | 1 Person | 2 People | ... | Time Limit)
    allRows.add(_buildHeaderRow(peopleList));

    // 2) For each duration, add a "section heading" row plus data rows.
    for (final duration in durations) {
      // Add a heading row for this duration
      final headingText = _durationToHeading(duration);
      allRows.add(_buildSectionHeadingRow(headingText, peopleList.length));

      // For each classes value, build a data row
      for (final cls in classesList) {
        // We'll create a row that has:
        // - The label for # of classes (e.g. "1 Class", "2 Classes", etc.)
        // - The columns for each people count (looking up price/time limit)
        // - The last column for time limit
        allRows.add(_buildDataRow(
          duration: duration,
          classesCount: cls,
          peopleList: peopleList,
          pricingOptions: pricingOptions,
          currencySymbol: currencySymbol,
        ));
      }
    }

    // Return the scrollable table
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),  // "Package" column
          // We'll give each people column a flexible width,
          // plus one last column for "Time Limit."
        },
        border: TableBorder.all(color: Colors.grey.shade300, width: 1),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: allRows,
      ),
    );
  }

  /// Converts a duration in minutes to a heading label.
  /// For example, 30 -> "30 Minute Classes", 60 -> "1 Hour Classes".
  /// Feel free to customize this logic as you wish.
  String _durationToHeading(int duration) {
    if (duration == 30) return '30 Minute Classes';
    if (duration == 60) return '1 Hour Classes';
    if (duration == 90) return '1.5 Hour Classes';
    // fallback
    return '$duration Minute Classes';
  }

  /// Builds the main header row with columns:
  /// [ "Package", for each person -> "X Person(s)", "Time Limit" ]
  TableRow _buildHeaderRow(List<int> peopleList) {
    final cells = <Widget>[];

    // First cell: "Package"
    cells.add(_headerCell('Package'));

    // Middle columns: one for each distinct "people" value
    for (final p in peopleList) {
      cells.add(_headerCell('$p Person${p > 1 ? 's' : ''}'));
    }

    // Last column: "Time Limit"
    cells.add(_headerCell('Time Limit'));

    return TableRow(
      decoration: const BoxDecoration(color: Colors.red),
      children: cells,
    );
  }

  /// Builds a row that acts as a section heading (e.g. "1 Hour Classes").
  /// We place the text in the first cell, and then empty cells for the other columns.
  TableRow _buildSectionHeadingRow(String heading, int peopleCount) {
    // total columns = 1 (package) + peopleCount + 1 (time limit)
    final totalCols = 1 + peopleCount + 1;

    // First cell has the heading text in a red accent row
    final cells = <Widget>[
      _sectionCell(heading),
    ];

    // The rest are empty
    for (int i = 0; i < totalCols - 1; i++) {
      cells.add(_emptyCell());
    }

    return TableRow(
      decoration: BoxDecoration(color: Colors.red.shade100),
      children: cells,
    );
  }

  /// Builds one data row for a given combination of (duration, classesCount),
  /// filling columns for each people value and time limit at the end.
  TableRow _buildDataRow({
    required int duration,
    required int classesCount,
    required List<int> peopleList,
    required List<dynamic> pricingOptions,
    required String currencySymbol,
  }) {
    // 1) First cell: "X Classes"
    final cells = <Widget>[
      _dataCell(_classesLabel(classesCount), isBold: true),
    ];

    // 2) Middle columns: for each people value, find if there's a match in pricingOptions
    //    that has the same (duration, people, classes).
    //    If found, show price + currency, otherwise "x".
    //    We'll also store the time limit if found, so we can display it at the end.
    String? timeLimitToShow;
    for (final p in peopleList) {
      final match = pricingOptions.firstWhere(
        (opt) =>
            opt['duration'] == duration &&
            opt['people'] == p &&
            opt['classes'] == classesCount,
        orElse: () => null,
      );
      if (match == null) {
        cells.add(_dataCell('x'));
      } else {
        final price = match['price']?.toStringAsFixed(2) ?? 'x';
        cells.add(_dataCell('$price $currencySymbol'));
        // We'll store time limit if present, but it might differ per combination
        if (match['time_limit'] != null) {
          timeLimitToShow = '${match['time_limit']} days';
        }
      }
    }

    // 3) Last column: time limit (or "x" if none found)
    cells.add(_dataCell(timeLimitToShow ?? 'x'));

    return TableRow(
      decoration: const BoxDecoration(color: Colors.white),
      children: cells,
    );
  }

  /// Returns "1 Class" or "2 Classes" etc.
  String _classesLabel(int c) {
    return c == 1 ? '1 Class' : '$c Classes';
  }

  /// Helper: Build a cell for the table header row (white text on red background).
  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Helper: Build a cell for a section heading row (e.g. "1 Hour Classes").
  Widget _sectionCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Helper: Returns an empty cell for the section heading row's leftover columns.
  Widget _emptyCell() {
    return const SizedBox.shrink();
  }

  /// Helper: Builds a data cell for normal rows.
  Widget _dataCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
