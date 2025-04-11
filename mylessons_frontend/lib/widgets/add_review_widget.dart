// add_review_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/review_provider.dart';

class AddReviewWidget extends StatefulWidget {
  const AddReviewWidget({Key? key}) : super(key: key);

  @override
  _AddReviewWidgetState createState() => _AddReviewWidgetState();
}

class _AddReviewWidgetState extends State<AddReviewWidget> {
  double _rating = 0;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  Widget _buildStar(int index) {
    IconData iconData = index < _rating ? Icons.star : Icons.star_border;
    return IconButton(
      icon: Icon(iconData, color: Colors.orange),
      onPressed: () {
        setState(() {
          _rating = index + 1.0;
        });
      },
    );
  }

  void _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please provide a rating", style: GoogleFonts.lato()),
        ),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
    });

    bool success = await Provider.of<ReviewProvider>(context, listen: false)
        .submitReview(
      rating: _rating,
      description: _descriptionController.text.trim(),
    );

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Error submitting review", style: GoogleFonts.lato()),
        ),
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  "Add Review",
                  style: GoogleFonts.lato(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Rate your experience",
                style: GoogleFonts.lato(fontSize: 16),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children:
                    List.generate(5, (index) => _buildStar(index)),
              ),
              const SizedBox(height: 16),
              Text(
                "Your review (optional)",
                style: GoogleFonts.lato(fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Tell us what you think...",
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.0)
                      : Text("Submit",
                          style: GoogleFonts.lato(
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
