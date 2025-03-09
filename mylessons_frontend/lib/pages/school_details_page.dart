import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SchoolDetailsContent extends StatefulWidget {
  final Map<String, dynamic> school;
  final Function(Map<String, dynamic>) onServiceSelected;
  const SchoolDetailsContent({super.key, required this.school, required this.onServiceSelected});

  @override
  _SchoolDetailsContentState createState() => _SchoolDetailsContentState();
}

class _SchoolDetailsContentState extends State<SchoolDetailsContent> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _purchasesKey = GlobalKey();
  final GlobalKey _servicesKey = GlobalKey();
  final GlobalKey _reviewsKey = GlobalKey();
  final GlobalKey _locationsKey = GlobalKey();
  final GlobalKey _contactsKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  List<Map<String, String>> reviews = [];

  void _showAddReviewDialog() {
    final authorController = TextEditingController();
    final reviewController = TextEditingController();
    final ratingController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Review'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: authorController,
                  decoration: const InputDecoration(labelText: 'Your Name'),
                ),
                TextField(
                  controller: ratingController,
                  decoration: const InputDecoration(labelText: 'Rating (1-5)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: reviewController,
                  decoration: const InputDecoration(labelText: 'Review'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Submit'),
              onPressed: () {
                final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
                setState(() {
                  reviews.add({
                    'author': authorController.text,
                    'review': reviewController.text,
                    'rating': ratingController.text,
                    'date': currentDate,
                  });
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Updated: Expect services to follow the new structure.
    final services = widget.school['services'] as List<dynamic>? ?? [];
    final reviews = widget.school['reviews'] as List<dynamic>? ?? [];
    final lastPurchases = widget.school['lastPurchases'] as List<dynamic>? ?? [];
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lastPurchases.isNotEmpty) ...[
                Container(
                  key: _purchasesKey,
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last Purchases',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: lastPurchases.length,
                          itemBuilder: (context, index) {
                            final purchase = lastPurchases[index] as Map<String, dynamic>;
                            return Card(
                              margin: const EdgeInsets.only(right: 12),
                              child: Container(
                                width: 160,
                                padding: const EdgeInsets.all(8),
                                height: 140,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      purchase['packName'] ?? 'Pack',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Date: ${purchase['date'] ?? ''}', style: const TextStyle(fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text('Price: ${purchase['price'] ?? ''}', style: const TextStyle(fontSize: 12)),
                                    const SizedBox(height: 8),
                                    Center(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Rebuy pressed')),
                                          );
                                        },
                                        child: const Text('Rebuy'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Container(
                key: _servicesKey,
                margin: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Services',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    services.isEmpty
                        ? const Center(child: Text('No services provided.'))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: services.length,
                            itemBuilder: (context, index) {
                              final service = services[index] as Map<String, dynamic>;
                              // Use the first photo from the "photos" list; if empty, fallback to a placeholder.
                              final imageUrl = (service['photos'] is List && (service['photos'] as List).isNotEmpty)
                                  ? service['photos'][0]
                                  : 'https://via.placeholder.com/150';
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  leading: SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey,
                                            child: const Icon(Icons.error),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  title: Text(service['name'] ?? 'Service'),
                                  subtitle: Text(service['description'] ?? 'No description provided.'),
                                  onTap: () {
                                    // Pass the service to the onServiceSelected callback,
                                    // but inject the school name as well.
                                    final updatedService = Map<String, dynamic>.from(service);
                                    updatedService['school_name'] = widget.school['name'] ?? 'N/A';
                                    widget.onServiceSelected(updatedService);
                                  },
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
              Container(
                key: _reviewsKey,
                margin: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reviews',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    reviews.isEmpty
                        ? const Center(child: Text('No reviews provided.'))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: reviews.length,
                            itemBuilder: (context, index) {
                              final review = reviews[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  title: Text('${review['author']} (${review['rating']}/5)'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(review['review']!),
                                      const SizedBox(height: 4),
                                      Text(
                                        review['date']!,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    Center(
                      child: ElevatedButton(
                        onPressed: _showAddReviewDialog,
                        child: const Text('Add Review'),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                key: _locationsKey,
                margin: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Locations',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    (widget.school['locations'] as List<String>).isEmpty
                        ? const Text('No locations provided.')
                        : Column(
                            children: (widget.school['locations'] as List<String>)
                                .map((location) => ListTile(
                                      leading: const Icon(Icons.location_on),
                                      title: Text(location),
                                    ))
                                .toList(),
                          ),
                  ],
                ),
              ),
              Container(
                key: _contactsKey,
                margin: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Contacts',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Center(child: Text('Contact details go here.')),
                  ],
                ),
              ),
              Container(
                key: _aboutKey,
                margin: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: widget.school['description'].toString().isEmpty
                          ? const Text('No description provided.')
                          : Text(widget.school['description']),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 8,
          top: MediaQuery.of(context).size.height / 4,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'services',
                onPressed: () => _scrollToSection(_servicesKey),
                tooltip: 'Services',
                child: const Icon(Icons.shopping_cart),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'reviews',
                onPressed: () => _scrollToSection(_reviewsKey),
                tooltip: 'Reviews',
                child: const Icon(Icons.rate_review),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'locations',
                onPressed: () => _scrollToSection(_locationsKey),
                tooltip: 'Locations',
                child: const Icon(Icons.location_on),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'contacts',
                onPressed: () => _scrollToSection(_contactsKey),
                tooltip: 'Contacts',
                child: const Icon(Icons.contact_phone),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'about',
                onPressed: () => _scrollToSection(_aboutKey),
                tooltip: 'About',
                child: const Icon(Icons.info),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
