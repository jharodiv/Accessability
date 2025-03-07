import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EstablishmentDetailsCard extends StatefulWidget {
  final Place place;
  final VoidCallback? onClose;

  const EstablishmentDetailsCard({
    Key? key,
    required this.place,
    this.onClose,
  }) : super(key: key);

  @override
  _EstablishmentDetailsCardState createState() =>
      _EstablishmentDetailsCardState();
}

class _EstablishmentDetailsCardState extends State<EstablishmentDetailsCard> {
  bool isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final String placeName = widget.place.name;
    final double placeRating = widget.place.rating ?? 0.0;
    final int reviewsCount = widget.place.reviewsCount ?? 0;
    final String locationText = widget.place.address ?? 'No address available';
    final String? imageUrl = widget.place.imageUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Name and Favorite Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  placeName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6750A4),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                color: isFavorite ? Colors.red : const Color(0xFF6750A4),
                onPressed: () {
                  setState(() {
                    isFavorite = !isFavorite;
                  });

                  // Dispatch events as needed
                  context.read<PlaceBloc>().add(AddPlaceEvent(
                        name: widget.place.name,
                        latitude: widget.place.latitude,
                        longitude: widget.place.longitude,
                        category: "Favorites",
                      ));
                },
              ),
            ],
          ),
          // Rating row: numeric rating, stars, review count
          Row(
            children: [
              Text(
                placeRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6750A4),
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
          const SizedBox(height: 4),
          // Location row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on,
                color: Color(0xFF6750A4),
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  locationText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Image or placeholder
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
