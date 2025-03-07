import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';

class EstablishmentDetailsCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onClose;

  const EstablishmentDetailsCard({
    Key? key,
    required this.place,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Retrieve fields from the Place model (populated via Google Places details)
    final String placeName = place.name;
    final double placeRating = place.rating ?? 0.0;
    final int reviewsCount = place.reviewsCount ?? 0;
    final String locationText = place.address ?? 'No address available';
    final String? imageUrl = place.imageUrl;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row for text-to-speech and close functionality
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  // Implement text-to-speech or speech-to-text here
                },
                child: const Text('Text to Speech, Speech to Text'),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Place name display
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  placeName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Rating and reviews count
          Row(
            children: [
              Text(
                placeRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              _buildStarRow(placeRating),
              const SizedBox(width: 8),
              Text(
                '($reviewsCount)',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Address display
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  locationText,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Display the establishment's image
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 180,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'No Image Available',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          const SizedBox(height: 12),

          // Button to navigate to a full reviews screen or expand more details
          ElevatedButton(
            onPressed: () {
              // e.g. Navigate to a full reviews screen
            },
            child: const Text('View Reviews'),
          ),
        ],
      ),
    );
  }

  // Helper method to build a row of star icons based on the rating
  Widget _buildStarRow(double rating) {
    final int fullStars = rating.floor();
    final bool hasHalfStar = (rating - fullStars) >= 0.5;

    List<Widget> stars = [];
    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(const Icon(Icons.star, color: Colors.amber, size: 16));
      } else if (i == fullStars && hasHalfStar) {
        stars.add(const Icon(Icons.star_half, color: Colors.amber, size: 16));
      } else {
        stars.add(const Icon(Icons.star_border, color: Colors.amber, size: 16));
      }
    }
    return Row(children: stars);
  }
}
