import 'package:flutter/material.dart';
import 'package:mylessons_frontend/pages/school_details_page.dart';

import '../providers/school_provider.dart';
import 'package:mylessons_frontend/pages/service_details_page.dart';

class SchoolCard extends StatelessWidget {
  final Map<String, dynamic> school;
  final SchoolProvider provider;

  const SchoolCard({
    Key? key,
    required this.school,
    required this.provider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        provider.selectSchool(school);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Card(
          // no custom shape – use default
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: image and school details.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        school['image'],
                        width: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 40,
                            width: 40,
                            color: Colors.grey,
                            child: const Icon(Icons.error, size: 20),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            school['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              // rating number itself (won’t really overflow, but good to cap it)
                              Text(
                                school['rating'].toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              // make the reviews text flexible so it can squeeze or ellipsize
                              Flexible(
                                child: Text(
                                  '(${school['reviews'] ?? 0} reviews)',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (school['isFavorite'] == true)
                      const Icon(Icons.favorite, color: Colors.red),
                  ],
                ),
                const SizedBox(height: 12),
                // Service chips.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        (school['services'] as List<dynamic>? ?? []).map((svc) {
                      final service = svc as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () {
                          // exactly the same chip behavior
                          provider.selectSchool(school);
                          final updatedService =
                              Map<String, dynamic>.from(service);
                          updatedService['school_name'] =
                              school['name'] ?? 'N/A';
                          provider.selectService(updatedService);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(32.0),
                          ),
                          child: Text(
                            service['name'] ?? 'Service',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
