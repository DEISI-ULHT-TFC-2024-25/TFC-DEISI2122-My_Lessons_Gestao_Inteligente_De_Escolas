import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:mylessons_frontend/providers/school_provider.dart';
import 'package:mylessons_frontend/widgets/contact_school_widget.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SchoolDetailsContent extends StatefulWidget {
  final Map<String, dynamic> school;
  const SchoolDetailsContent({
    Key? key,
    required this.school,
  }) : super(key: key);

  @override
  _SchoolDetailsContentState createState() => _SchoolDetailsContentState();
}

class _SchoolDetailsContentState extends State<SchoolDetailsContent> {
  // Local reviews added by the user.
  List<Map<String, String>> _localReviews = [];

  void _showAddReviewDialog() {
    final authorController = TextEditingController();
    final ratingController = TextEditingController();
    final reviewController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Review', style: GoogleFonts.lato()),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: authorController,
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    labelStyle: GoogleFonts.lato(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ratingController,
                  decoration: InputDecoration(
                    labelText: 'Rating (1-5)',
                    labelStyle: GoogleFonts.lato(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reviewController,
                  decoration: InputDecoration(
                    labelText: 'Review',
                    labelStyle: GoogleFonts.lato(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: GoogleFonts.lato(color: Colors.orange)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Submit', style: GoogleFonts.lato()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
                setState(() {
                  _localReviews.add({
                    'author': authorController.text,
                    'rating': ratingController.text,
                    'review': reviewController.text,
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

  /// Helper widget for section headers.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.lato(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  /// Last Purchases Tab.
  Widget _buildLastPurchasesTab() {
    final lastPurchases = widget.school['lastPurchases'] as List<dynamic>? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: lastPurchases.isEmpty
          ? Center(child: Text('No purchases available.', style: GoogleFonts.lato()))
          : SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: lastPurchases.length,
                itemBuilder: (context, index) {
                  final purchase = lastPurchases[index] as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(right: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Container(
                      width: 160,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            purchase['packName'] ?? 'Pack',
                            style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('Date: ${purchase['date'] ?? ''}', style: GoogleFonts.lato(fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('Price: ${purchase['price'] ?? ''}', style: GoogleFonts.lato(fontSize: 12)),
                          const Spacer(),
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Rebuy pressed', style: GoogleFonts.lato())),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('Rebuy', style: GoogleFonts.lato()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  /// Services Tab.
  Widget _buildServicesTab() {
    final services = widget.school['services'] as List<dynamic>? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: services.isEmpty
          ? Center(child: Text('No services provided.', style: GoogleFonts.lato()))
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index] as Map<String, dynamic>;
                final imageUrl = (service['photos'] is List &&
                        (service['photos'] as List).isNotEmpty)
                    ? service['photos'][0]
                    : 'https://via.placeholder.com/150';
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey,
                          child: Icon(Icons.error, color: Colors.red),
                        ),
                      ),
                    ),
                    title: Text(service['name'] ?? 'Service',
                        style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      service['description'] ?? 'No description provided.',
                      style: GoogleFonts.lato(fontSize: 12),
                    ),
                    onTap: () {
                      final updatedService = Map<String, dynamic>.from(service);
                      updatedService['school_name'] = widget.school['name'] ?? 'N/A';
                      Provider.of<SchoolProvider>(context, listen: false).selectService(updatedService);

                    },
                  ),
                );
              },
            ),
    );
  }

  /// Reviews Tab.
  Widget _buildReviewsTab() {
    final reviewsFromData = widget.school['reviews'] as List<dynamic>? ?? [];
    final allReviews = List<Map<String, String>>.from(
      reviewsFromData.map((r) => {
            'author': r['author'] ?? '',
            'rating': r['rating']?.toString() ?? '',
            'review': r['review'] ?? '',
            'date': r['date'] ?? '',
          }),
    )..addAll(_localReviews);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          allReviews.isEmpty
              ? Center(child: Text('No reviews provided.', style: GoogleFonts.lato()))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: allReviews.length,
                  itemBuilder: (context, index) {
                    final review = allReviews[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text('${review['author']} (${review['rating']}/5)',
                            style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(review['review']!, style: GoogleFonts.lato()),
                            const SizedBox(height: 4),
                            Text(review['date']!,
                                style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          Center(
            child: ElevatedButton(
              onPressed: _showAddReviewDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Add Review', style: GoogleFonts.lato()),
            ),
          ),
        ],
      ),
    );
  }

  /// Locations Tab.
  Widget _buildLocationsTab() {
    final locations = widget.school['locations'] as List<dynamic>? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: locations.isEmpty
          ? Center(child: Text('No locations provided.', style: GoogleFonts.lato()))
          : Column(
              children: locations
                  .map((loc) => ListTile(
                        leading: Icon(Icons.location_on, color: Colors.orange),
                        title: Text(loc.toString(), style: GoogleFonts.lato()),
                      ))
                  .toList(),
            ),
    );
  }

  /// About Tab.
  Widget _buildAboutTab() {
    final description = widget.school['description']?.toString() ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: description.isEmpty
            ? Text('No description provided.', style: GoogleFonts.lato())
            : Text(description, style: GoogleFonts.lato()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine tabs dynamically.
    final lastPurchases = widget.school['lastPurchases'] as List<dynamic>? ?? [];
    final List<Widget> tabs = [];
    final List<Widget> tabViews = [];
    if (lastPurchases.isNotEmpty) {
      tabs.add(const Tab(text: 'Purchases'));
      tabViews.add(_buildLastPurchasesTab());
    }
    tabs.add(const Tab(text: 'Services'));
    tabViews.add(_buildServicesTab());
    tabs.add(const Tab(text: 'Reviews'));
    tabViews.add(_buildReviewsTab());
    tabs.add(const Tab(text: 'Locations'));
    tabViews.add(_buildLocationsTab());
    tabs.add(const Tab(text: 'Contacts'));
    tabViews.add(ContactSchoolWidget(school: widget.school));
    tabs.add(const Tab(text: 'About'));
    tabViews.add(_buildAboutTab());

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.orange),
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.orange,
            tabs: tabs,
          ),
        ),
        body: TabBarView(
          children: tabViews,
        ),
      ),
    );
  }
}
