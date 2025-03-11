import 'package:flutter/material.dart';
import '../services/payment_service.dart';

Widget buildFlexibleAccordion(String key, dynamic value) {
  if (key == "pricing_options" && value is List) {
    List<Widget> children = value.map<Widget>((item) {
      if (item is Map) {
        return ListTile(title: Text(formatPricingOption(item)));
      } else {
        return ListTile(title: Text(item.toString()));
      }
    }).toList();
    return ExpansionTile(
      title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: children,
    );
  }
  if (value is Map) {
    List<Widget> children = value.entries
        .map((entry) => buildFlexibleAccordion(entry.key, entry.value))
        .toList();
    return ExpansionTile(
      title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: children,
    );
  }
  if (value is List) {
    if (value.isEmpty) {
      return ListTile(title: Text(key), subtitle: const Text("Empty list"));
    }
    bool allPrimitive = value.every((item) => item is! Map && item is! List);
    if (allPrimitive) {
      List<Widget> children =
          value.map((item) => ListTile(title: Text(item.toString()))).toList();
      return ExpansionTile(
        title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: children,
      );
    }
    List<Widget> children = value.map<Widget>((item) {
      if (item is Map && item.containsKey("name")) {
        return buildFlexibleAccordion(item["name"].toString(), item);
      } else {
        return buildFlexibleAccordion("Item", item);
      }
    }).toList();
    return ExpansionTile(
      title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: children,
    );
  }
  return ListTile(title: Text(key), subtitle: Text(value.toString()));
}

Widget buildFlexibleStructure(dynamic data) {
  if (data is Map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries
          .map((e) => buildFlexibleAccordion(e.key, e.value))
          .toList(),
    );
  } else if (data is List) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.map((e) {
        if (e is Map && e.containsKey("name")) {
          return buildFlexibleAccordion(e["name"].toString(), e);
        } else {
          return buildFlexibleAccordion("Item", e);
        }
      }).toList(),
    );
  }
  return Text(data.toString());
}
