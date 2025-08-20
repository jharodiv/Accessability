import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/data/model/review.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_state.dart';

class RatingReviewWidget extends StatefulWidget {
  final String locationId;
  final String locationName;

  const RatingReviewWidget({
    Key? key,
    required this.locationId,
    required this.locationName,
  }) : super(key: key);

  @override
  _RatingReviewWidgetState createState() => _RatingReviewWidgetState();
}

class _RatingReviewWidgetState extends State<RatingReviewWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _reviewController = TextEditingController();
  double _currentRating = 0;
  List<Review> _reviews = [];
  double _averageRating = 0;
  int _totalRatings = 0;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final doc = await _firestore
        .collection('pwd_locations')
        .doc(widget.locationId)
        .get();
    if (doc.exists) {
      final data = doc.data();
      setState(() {
        _averageRating = _parseDouble(data?['averageRating'] ?? 0);
        _totalRatings = _parseInt(data?['totalRatings'] ?? 0);
        _reviews = _parseReviewsSafely(data?['reviews']);
      });
    }
  }

  // Helper methods for safe parsing
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  List<Review> _parseReviewsSafely(dynamic reviewsData) {
    if (reviewsData == null || reviewsData is! List) return [];

    final List<Review> reviews = [];
    for (final reviewData in reviewsData) {
      try {
        if (reviewData is Map<String, dynamic>) {
          final review = Review.fromMap(reviewData);
          reviews.add(review);
        }
      } catch (e) {
        print('Error parsing review: $e');
      }
    }
    return reviews;
  }

  Future<void> _submitReview() async {
    if (_currentRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    // Get user data from UserBloc
    final userState = context.read<UserBloc>().state;
    String username;
    String? profilePicture;

    if (userState is UserLoaded) {
      username = userState.user.username;
      profilePicture = userState.user.profilePicture;
    } else {
      // Fallback to Firebase Auth data
      username = user.displayName ?? user.email!.split('@').first;
      profilePicture = user.photoURL;
    }

    final newReview = Review(
      userId: user.uid,
      userName: username.isNotEmpty ? username : 'Anonymous User',
      userProfilePicture: profilePicture,
      rating: _currentRating,
      comment: _reviewController.text.trim(),
      timestamp: DateTime.now(),
    );

    try {
      final locationRef =
          _firestore.collection('pwd_locations').doc(widget.locationId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(locationRef);

        List<Map<String, dynamic>> reviews = [];
        double currentAverage = 0;
        int currentTotal = 0;

        if (doc.exists) {
          final data = doc.data()!;
          reviews = List<Map<String, dynamic>>.from(data['reviews'] ?? []);
          currentAverage = _parseDouble(data['averageRating'] ?? 0);
          currentTotal = _parseInt(data['totalRatings'] ?? 0);
        }

        // Add new review
        reviews.add(newReview.toMap());

        // Calculate new average
        final newTotal = currentTotal + 1;
        final newAverage =
            ((currentAverage * currentTotal) + _currentRating) / newTotal;

        transaction.set(
            locationRef,
            {
              'reviews': reviews,
              'averageRating': newAverage,
              'totalRatings': newTotal,
              'lastUpdated': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });

      _reviewController.clear();
      _currentRating = 0;
      await _loadReviews();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review submitted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting review: ${e.toString()}')),
      );
    }
  }

  Widget _buildRatingStars(double rating, {double size = 24}) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserBloc, UserState>(
      listener: (context, state) {
        // Reload reviews when user data changes
        if (state is UserLoaded) {
          _loadReviews();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Rating
          Row(
            children: [
              _buildRatingStars(_averageRating, size: 32),
              SizedBox(width: 8),
              Text(
                '${_averageRating.toStringAsFixed(1)} ($_totalRatings reviews)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Add Review Section
          Text('Add your review:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),

          // Star Rating
          Row(
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _currentRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 30,
                ),
                onPressed: () {
                  setState(() {
                    _currentRating = index + 1.0;
                  });
                },
              );
            }),
          ),

          // Review Text Field
          TextField(
            controller: _reviewController,
            decoration: InputDecoration(
              hintText: 'Write your feedback...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          SizedBox(height: 8),

          // Submit Button
          ElevatedButton(
            onPressed: _submitReview,
            child: Text('Submit Review'),
          ),
          SizedBox(height: 16),

          // Reviews List
          Text('Reviews:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),

          _reviews.isEmpty
              ? Text('No reviews yet. Be the first to review!')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _reviews.length,
                  itemBuilder: (context, index) {
                    final review = _reviews[index];
                    return _buildReviewItem(review);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(Review review) {
    // Handle empty user names
    final String displayName =
        review.userName.isEmpty ? 'Anonymous User' : review.userName;

    // Handle empty profile pictures
    final bool hasProfilePicture = review.userProfilePicture != null &&
        review.userProfilePicture!.isNotEmpty;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: hasProfilePicture
                      ? NetworkImage(review.userProfilePicture!)
                      : null,
                  child: !hasProfilePicture
                      ? Text(displayName.isNotEmpty ? displayName[0] : 'U')
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      _buildRatingStars(review.rating, size: 16),
                    ],
                  ),
                ),
                Text(
                  _formatDate(review.timestamp),
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(review.comment),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
