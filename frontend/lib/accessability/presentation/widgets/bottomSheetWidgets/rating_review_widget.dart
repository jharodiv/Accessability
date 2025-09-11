import 'package:easy_localization/easy_localization.dart';
import 'package:accessability/accessability/presentation/widgets/shimmer/shimmer_review.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:accessability/accessability/data/model/review.dart';
import 'package:accessability/accessability/logic/bloc/user/user_bloc.dart';
import 'package:accessability/accessability/logic/bloc/user/user_state.dart';

class RatingReviewWidget extends StatefulWidget {
  final String locationId;
  final String locationName;
  final String? imageUrl; // optional
  final VoidCallback? onClose; // optional

  const RatingReviewWidget({
    Key? key,
    required this.locationId,
    required this.locationName,
    this.imageUrl,
    this.onClose,
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
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
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() => _isLoading = false);
    }
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  List<Review> _parseReviewsSafely(dynamic reviewsData) {
    if (reviewsData == null || reviewsData is! List) return [];
    final List<Review> reviews = [];
    for (final r in reviewsData) {
      try {
        if (r is Map<String, dynamic>) reviews.add(Review.fromMap(r));
      } catch (e) {
        print('parse review error: $e');
      }
    }
    reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return reviews;
  }

  Future<void> _submitReview() async {
    if (_currentRating == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('please_select_rating').tr()));
      return;
    }
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final userState = context.read<UserBloc>().state;
    String username;
    String? profilePicture;

    if (userState is UserLoaded) {
      username = userState.user.username;
      profilePicture = userState.user.profilePicture;
    } else {
      username = user.displayName ?? user.email!.split('@').first;
      profilePicture = user.photoURL;
    }

    final newReview = Review(
      userId: user.uid,
      userName: username.isNotEmpty ? username : 'Anonymous',
      userProfilePicture: profilePicture,
      rating: _currentRating,
      comment: _reviewController.text.trim(),
      timestamp: DateTime.now(),
    );

    try {
      final locationRef =
          _firestore.collection('pwd_locations').doc(widget.locationId);
      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(locationRef);
        List<Map<String, dynamic>> reviews = [];
        double currentAvg = 0;
        int currentTotal = 0;
        if (doc.exists) {
          final d = doc.data()!;
          reviews = List<Map<String, dynamic>>.from(d['reviews'] ?? []);
          currentAvg = _parseDouble(d['averageRating'] ?? 0);
          currentTotal = _parseInt(d['totalRatings'] ?? 0);
        }
        reviews.add(newReview.toMap());
        final newTotal = currentTotal + 1;
        final newAvg =
            ((currentAvg * currentTotal) + _currentRating) / newTotal;
        tx.set(
            locationRef,
            {
              'reviews': reviews,
              'averageRating': newAvg,
              'totalRatings': newTotal,
              'lastUpdated': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });

      _reviewController.clear();
      _currentRating = 0;
      await _loadReviews();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('review_submitted').tr()));
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_submitting').tr(args: [e.toString()])));
    }
  }

  Map<int, int> _breakdown() {
    final counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (var r in _reviews) {
      final s = r.rating.round().clamp(1, 5);
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Widget _starRow(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(i < rating ? Icons.star : Icons.star_border,
            color: Colors.amber, size: size);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final purple = Color(0xFF6A3ED6);
    final theme = Theme.of(context);

    // unified color palette for consistency
    final Color primaryText = Colors.black87;
    final Color secondaryText = Colors.grey.shade800;
    final Color mutedText = Colors.grey.shade600;

    // read user state for avatar display (watch so UI updates if state changes)
    final userState = context.watch<UserBloc>().state;
    String displayName = '';
    String? displayPicture;
    if (userState is UserLoaded) {
      displayName = userState.user.username ?? '';
      displayPicture = userState.user.profilePicture;
    } else {
      final cu = _auth.currentUser;
      displayName = cu?.displayName ?? cu?.email?.split('@').first ?? '';
      displayPicture = cu?.photoURL;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // If an imageUrl was provided, show the image at the top inside the sheet with overlay X
        if (widget.imageUrl != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.network(
                  widget.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 180,
                    color: Colors.grey[100],
                    child: Center(
                        child: Icon(Icons.image_not_supported,
                            color: Colors.grey[400])),
                  ),
                ),
              ),
              if (widget.onClose != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: ClipOval(
                    child: Material(
                      color: Colors.white.withOpacity(0.85),
                      child: InkWell(
                        onTap: widget.onClose,
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Icon(Icons.close,
                              size: 20, color: Colors.grey[800]),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
        ],

        // LOCATION NAME above the Reviews title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Text(
            widget.locationName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: primaryText,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(height: 10),

// Accent + divider to separate name from section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Row(
            children: [
              // short accent bar
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: purple,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(width: 12),
            ],
          ),
        ),
        SizedBox(height: 10),

// Reviews heading with subtle meta (count) at the far right
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'reviews'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),

        // Main white block containing summary, breakdown and limited reviews (flat white look)
        Container(
          width: double.infinity,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top rating number + stars
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(_averageRating.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: primaryText)),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _starRow(_averageRating, size: 18),
                        SizedBox(height: 6),
                        Text('$_totalRatings ${'reviews'.tr()}',
                            style: TextStyle(color: secondaryText)),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _outlineChip(Icons.cleaning_services, 'cleanliness'.tr(),
                        secondaryText),
                    _outlineChip(Icons.shield, 'safety'.tr(), secondaryText),
                    _outlineChip(
                        Icons.location_on, 'location'.tr(), secondaryText),
                  ],
                ),
                SizedBox(height: 12),

                _isLoading
                    ? SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator()))
                    : _buildBreakdownBars(purple, primaryText, mutedText),
                SizedBox(height: 12),

                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: mutedText),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text('ratings_collected'.tr(),
                            style: TextStyle(color: mutedText, fontSize: 13))),
                  ],
                ),
                SizedBox(height: 12),

                // Show up to 3 reviews
                if (_isLoading)
                  SizedBox.shrink()
                else if (_reviews.isEmpty)
                  Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('no_reviews_yet'.tr(),
                          style: TextStyle(color: mutedText)))
                else ...[
                  Column(
                      children: _reviews
                          .take(3)
                          .map((r) => _compactReviewRow(
                              r, primaryText, secondaryText, mutedText))
                          .toList()),
                  if (_reviews.length > 3) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => _openAllReviewsSheet(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black87, // force black color
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 12),
                          textStyle: const TextStyle(
                            decoration: TextDecoration.none,
                            fontWeight: FontWeight
                                .w700, // stronger weight to differentiate
                          ),
                        ),
                        child: Text(
                          'more_reviews'.tr(),
                          style: const TextStyle(
                              color: Colors.black87), // explicit color
                        ),
                      ),
                    ),
                  ],

// add a clear separator between the reviews list and add-review area
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    child: Divider(
                      color: Colors.grey.shade300,
                      thickness: 1,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),

        SizedBox(height: 14),

        // Add review area (no card) - blends into page, shows user's profile picture if available
        // --- REPLACE the previous "Add review area" block with this (no Card, no Container border; blends into page) ---
        // --- REPLACE the current add-review block with this improved, compact "minimal card" ---
// Paste this widget where your previous add-review Padding/Card was.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                )
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header: avatar + title + small rating chip
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          (displayPicture == null || displayPicture.isEmpty)
                              ? purple.withOpacity(0.12)
                              : Colors.transparent,
                      backgroundImage:
                          (displayPicture != null && displayPicture.isNotEmpty)
                              ? NetworkImage(displayPicture)
                              : null,
                      child: (displayPicture == null || displayPicture.isEmpty)
                          ? (displayName.isNotEmpty
                              ? Text(displayName[0].toUpperCase(),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: purple))
                              : Icon(Icons.person, color: purple, size: 18))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('add_your_review'.tr(),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: primaryText,
                              )),
                          const SizedBox(height: 2),
                          Text('share_experience_short'.tr(),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: mutedText, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (_currentRating > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: purple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 6),
                            Text(_currentRating.toStringAsFixed(1),
                                style: TextStyle(
                                    color: primaryText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // compact star row (smaller, tighter spacing)
                Row(
                  children: List.generate(5, (i) {
                    final idx = i + 1;
                    final isSelected = idx <= _currentRating;
                    return GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () =>
                              setState(() => _currentRating = idx.toDouble()),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        margin: const EdgeInsets.only(right: 8),
                        padding: EdgeInsets.all(isSelected ? 6 : 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Colors.amber.withOpacity(0.12)
                              : Colors.transparent,
                        ),
                        child: Icon(
                          isSelected ? Icons.star : Icons.star_border,
                          color:
                              isSelected ? Colors.amber : Colors.grey.shade400,
                          size: isSelected ? 26 : 24,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 12),

                // text field with clear visible border and rounded corners (improved UX)
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 80, maxHeight: 160),
                  child: TextField(
                    controller: _reviewController,
                    enabled: !_isLoading,
                    maxLines: 5,
                    maxLength: 300,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: primaryText),
                    decoration: InputDecoration(
                      hintText: 'write_feedback_hint'.tr(),
                      hintStyle: TextStyle(color: mutedText),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: purple, width: 1.8),
                      ),
                      counterText: '',
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // counter row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Row(
                    children: [
                      Text('${_reviewController.text.length}/300',
                          style: TextStyle(fontSize: 12, color: mutedText)),
                      const Spacer(),
                      Text(
                        'chars_left'.tr(args: [
                          (300 - _reviewController.text.length)
                              .clamp(0, 300)
                              .toString()
                        ]),
                        style: TextStyle(fontSize: 12, color: mutedText),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // actions: submit (primary pill) + clear (flat black text)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_isLoading || _currentRating == 0)
                            ? null
                            : () async {
                                if (_currentRating == 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('please_select_rating')
                                              .tr()));
                                  return;
                                }
                                await _submitReview();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purple,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white)))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send, size: 16),
                                  const SizedBox(width: 8),
                                  Text('submit'.tr(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Clear button as plain text (black)
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() {
                                _reviewController.clear();
                                _currentRating = 0;
                              }),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        foregroundColor: Colors.black87,
                      ),
                      child: Text('clear'.tr(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // helper tip - subtle
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 14, color: purple),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('keep_review_short_tip'.tr(),
                            style: TextStyle(fontSize: 12, color: mutedText))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactReviewRow(
      Review review, Color primaryText, Color secondaryText, Color mutedText) {
    final displayName = review.userName.isEmpty ? 'Anonymous' : review.userName;
    final hasPic = review.userProfilePicture != null &&
        review.userProfilePicture!.isNotEmpty;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage:
                hasPic ? NetworkImage(review.userProfilePicture!) : null,
            child: !hasPic
                ? Text(displayName[0].toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: primaryText))
                : null,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(displayName,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: primaryText))),
                  Text(_formatDate(review.timestamp),
                      style: TextStyle(color: mutedText, fontSize: 12)),
                ]),
                SizedBox(height: 6),
                _starRow(review.rating, size: 14),
                SizedBox(height: 8),
                Text(review.comment, style: TextStyle(color: secondaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlineChip(IconData icon, String text, Color textColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        SizedBox(width: 8),
        Text(text, style: TextStyle(color: textColor)),
      ]),
    );
  }

  Widget _buildBreakdownBars(Color purple, Color primaryText, Color mutedText) {
    final counts = _breakdown();
    final maxCount = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b);
    return Column(
      children: [5, 4, 3, 2, 1].map((star) {
        final c = counts[star] ?? 0;
        final fraction = maxCount == 0 ? 0.0 : (c / maxCount);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              SizedBox(
                  width: 24,
                  child: Text('$star',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: primaryText))),
              SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(purple),
                ),
              ),
              SizedBox(width: 12),
              SizedBox(
                  width: 20,
                  child: Text('$c',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: mutedText))),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _openAllReviewsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
              child: Column(
                children: [
                  Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4))),
                  SizedBox(height: 10),
                  Text('all_reviews'.tr(),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  SizedBox(height: 8),
                  Expanded(
                    child: _reviews.isEmpty
                        ? Center(
                            child: Text('no_reviews_yet'.tr(),
                                style: TextStyle(color: Colors.grey.shade700)))
                        : ListView.builder(
                            controller: controller,
                            itemCount: _reviews.length,
                            itemBuilder: (_, i) {
                              final r = _reviews[i];
                              return _compactReviewRow(r, Colors.black87,
                                  Colors.grey.shade800, Colors.grey.shade600);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
