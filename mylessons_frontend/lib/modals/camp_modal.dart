import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../providers/school_data_provider.dart';
import 'activity_modal.dart';

/// Call this from any page to open the Activities selection sheet,
/// and get back the selected activity IDs as a List<int>.
Future<List<Map<String, dynamic>>?> showActivitiesModal(BuildContext context) {
  return showModalBottomSheet<List<Map<String, dynamic>>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => const ActivitiesModal(),
  );
}

/// Model representing an Activity instance from API
class ActivityItem {
  final int id;
  final String name;
  final String date;
  final String startTime;
  final String endTime;
  final String locationName;

  ActivityItem({
    required this.id,
    required this.name,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.locationName,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>?;
    return ActivityItem(
      id: json['id'] as int,
      name: json['name'] as String,
      date: json['date'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String? ?? '',
      // safely pick location_name or nested location.name or default to ''
      locationName: (json['location_name'] as String?) ??
          (loc != null ? loc['name'] as String? : null) ??
          '',
    );
  }

  /// Serializes the ActivityItem into a JSON-like map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'location_name': locationName,
    };
  }
}

class ActivitiesModal extends StatefulWidget {
  const ActivitiesModal({Key? key}) : super(key: key);

  @override
  _ActivitiesModalState createState() => _ActivitiesModalState();
}

class _ActivitiesModalState extends State<ActivitiesModal> {
  List<ActivityItem> _activities = [];
  Map<int, bool> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _deleteActivity(ActivityItem a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Activity'),
        content: Text(
            'Are you sure you want to delete "${a.name}" on ${_formatDate(a.date)} '
            'from ${a.startTime} to ${a.endTime}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      final headers = await getAuthHeaders();
      final resp = await http.delete(
        Uri.parse('$baseUrl/api/events/activities/${a.id}/'),
        headers: headers,
      );
      if (resp.statusCode == 204) {
        setState(() {
          _activities.removeWhere((el) => el.id == a.id);
          _selected.remove(a.id);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${resp.statusCode}')),
        );
      }
    }
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return '${date.day.toString().padLeft(2, '0')} '
        '${_monthName(date.month)} ${date.year}';
  }

  String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return names[month - 1];
  }

  void _saveActivities() {
    // Now pop full maps instead of IDs
    final selectedItems = _activities
        .where((a) => _selected[a.id] == true)
        .map((a) => a.toJson())
        .toList();
    Navigator.of(context).pop(selectedItems);
  }

  Future<void> _fetchActivities() async {
    print('⏳ Fetching activities…');
    final headers = await getAuthHeaders();
    final provider = context.read<SchoolDataProvider>();
    final schoolId = provider.schoolDetails!['school_id'] as int;
    print('🔑 schoolId = $schoolId');
    final uri = Uri.parse('$baseUrl/api/events/activities/');
    print('GET $uri');

    final resp = await http.get(uri, headers: headers);
    print('📬 status ${resp.statusCode}: ${resp.body}');

    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body) as List;
      print('📦 raw data length = ${data.length}');

      final activities = data
          .where((j) {
            final include = j['school'] == schoolId;
            print(' • id=${j['id']} school=${j['school']} → include=$include');
            return include;
          })
          .map((j) => ActivityItem.fromJson(j))
          .toList();

      print('✅ filtered activities = ${activities.length}');
      setState(() {
        _activities = activities;
        _selected = {for (var a in activities) a.id: false};
        _loading = false;
      });
    } else {
      print('⚠️ failed to load activities');
      setState(() {
        _activities = [];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load activities: ${resp.statusCode}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(thickness: 4, indent: 100, endIndent: 100),
              ),

              // ─── BODY ─────────────────────────────────────
              Expanded(
                child: Builder(
                  builder: (_) {
                    if (_loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (_activities.isEmpty) {
                      return const Center(child: Text('No activities found.'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _activities.length,
                      itemBuilder: (context, index) {
                        final a = _activities[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _selected[a.id] ?? false,
                                  onChanged: (val) {
                                    setState(() {
                                      _selected[a.id] = val ?? false;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(a.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_formatDate(a.date)} from ${a.startTime} to ${a.endTime}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        a.locationName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    await showActivityModal(context,
                                        activity: a);
                                    await _fetchActivities();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteActivity(a),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // ─── FOOTER ────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await showActivityModal(context);
                        await _fetchActivities();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Activity'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _saveActivities,
                      child: const Text('Save Activities'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
