import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_bloc.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/rating_review_widget.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/data/model/place.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EstablishmentDetailsCard extends StatefulWidget {
  final Place place;
  final VoidCallback? onClose;
  final bool isPwdLocation;

  const EstablishmentDetailsCard({
    Key? key,
    required this.place,
    this.onClose,
    this.isPwdLocation = false,
  }) : super(key: key);

  @override
  _EstablishmentDetailsCardState createState() =>
      _EstablishmentDetailsCardState();
}

class _EstablishmentDetailsCardState extends State<EstablishmentDetailsCard> {
  bool isFavorite = false;

  // Only use fields that are defined on your Place class.
  // Adjust these functions if your Place exposes different names.
  String _safeName(Place p) {
    if (p.name != null && p.name!.trim().isNotEmpty) return p.name!.trim();
    if (p.address != null && p.address!.trim().isNotEmpty)
      return p.address!.trim();
    if (p.latitude != null && p.longitude != null) {
      return '${p.latitude}, ${p.longitude}';
    }
    return 'Unknown place';
  }

  double _safeRating(Place p) {
    // Try the canonical rating first, then attempt common alternate fields dynamically.
    dynamic val;
    try {
      val = (p as dynamic).rating ??
          (p as dynamic).averageRating ??
          (p as dynamic).ratingValue ??
          (p as dynamic).score;
    } catch (_) {
      val = null;
    }

    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) {
      // Try a direct parse; if that fails try to extract the first numeric fragment.
      final parsed = double.tryParse(val);
      if (parsed != null) return parsed;
      final match = RegExp(r'[\d]+(\.[\d]+)?').stringMatch(val);
      return double.tryParse(match ?? '') ?? 0.0;
    }

    // Last resort: if Place exposes `rating` as a typed field (covered above), otherwise 0.0
    try {
      final r = p.rating;
      if (r is double) return r;
      if (r is int) return (r as int).toDouble();
    } catch (_) {}
    return 0.0;
  }

  int _safeReviewsCount(Place p) {
    // 1) Try dynamic alternate fields first (from different Place shapes)
    dynamic val;
    try {
      val = (p as dynamic).reviewsCount ??
          (p as dynamic).reviewCount ??
          (p as dynamic).reviews;
    } catch (_) {
      val = null;
    }

    if (val != null) {
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is num) return val.toInt();
      if (val is String) {
        final match = RegExp(r'\d+').stringMatch(val);
        return int.tryParse(match ?? '') ?? 0;
      }
      return 0;
    }

    // 2) Fallback to canonical field on Place (check null before toInt)
    try {
      final dynamic rc = p.reviewsCount;
      if (rc == null) return 0;
      if (rc is int) return rc;
      if (rc is double) return rc.toInt();
      if (rc is num) return rc.toInt();
      if (rc is String) {
        final match = RegExp(r'\d+').stringMatch(rc);
        return int.tryParse(match ?? '') ?? 0;
      }
    } catch (_) {
      // ignore and return 0
    }

    return 0;
  }

  String? _safeImageUrl(Place p) {
    // prefer explicit imageUrl if present
    try {
      final img = p.imageUrl;
      if (img != null && img.trim().isNotEmpty) return img.trim();
    } catch (_) {}

    // fallback to common alternate fields dynamically
    try {
      final alt = (p as dynamic).photoUrl ?? (p as dynamic).thumbnailUrl;
      if (alt != null && (alt as String).trim().isNotEmpty)
        return (alt as String).trim();
    } catch (_) {}

    // fallback: Google Street View image (requires GOOGLE_API_KEY in .env and dotenv.load() run at app start)
    try {
      if (p.latitude != null && p.longitude != null) {
        final key = dotenv.env['GOOGLE_API_KEY'];
        if (key != null && key.isNotEmpty) {
          return Uri.encodeFull(
            'https://maps.googleapis.com/maps/api/streetview'
            '?size=800x400&location=${p.latitude},${p.longitude}&fov=80&heading=70&pitch=0&key=$key',
          );
        }
      }
    } catch (_) {}

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Helpful debug log while developing — remove later
    debugPrint('Place object: ${widget.place}');

    final placeName = _safeName(widget.place);
    final placeRating = _safeRating(widget.place);
    final reviewsCount = _safeReviewsCount(widget.place);
    final locationText = (widget.place.address ?? '').trim();
    final imageUrl = _safeImageUrl(widget.place);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  placeName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6750A4),
                  ),
                ),
              ),
              if (widget.isPwdLocation)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6750A4).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PWD Friendly',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6750A4),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              IconButton(
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                color: isFavorite ? Colors.red : const Color(0xFF6750A4),
                onPressed: () {
                  setState(() => isFavorite = !isFavorite);
                  // keep dispatch behavior — make sure PlaceBloc expects this event shape
                  context.read<PlaceBloc>().add(AddPlaceEvent(
                        name: widget.place.name ?? placeName,
                        latitude: widget.place.latitude,
                        longitude: widget.place.longitude,
                        category: "Favorites",
                      ));
                },
              ),
              if (widget.onClose != null)
                IconButton(
                    icon: const Icon(Icons.close), onPressed: widget.onClose),
            ],
          ),

          const SizedBox(height: 8),

          // rating row
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
              const SizedBox(width: 6),
              _buildStarRow(placeRating),
              const SizedBox(width: 8),
              Text('($reviewsCount)', style: const TextStyle(fontSize: 14)),
            ],
          ),

          const SizedBox(height: 8),

          // address row
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF6750A4), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locationText.isNotEmpty
                      ? locationText
                      : 'No address available',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // image or placeholder (imageUrl can be actual photo or StreetView fallback)
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: const Text('No Image Available',
                      style: TextStyle(color: Colors.black54)),
                ),
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
              child: const Text('No Image Available',
                  style: TextStyle(color: Colors.black54)),
            ),

          const SizedBox(height: 12),

          // PWD reviews widget (old behavior)
          if (widget.isPwdLocation)
            BlocProvider.value(
              value: BlocProvider.of<UserBloc>(context),
              child: RatingReviewWidget(
                  locationId: widget.place.id, locationName: placeName),
            ),
        ],
      ),
    );
  }

  Widget _buildStarRow(double rating) {
    final fullStars = rating.floor();
    final hasHalf = (rating - fullStars) >= 0.5;
    final stars = <Widget>[];
    for (var i = 0; i < 5; i++) {
      if (i < fullStars)
        stars.add(const Icon(Icons.star, color: Colors.amber, size: 16));
      else if (i == fullStars && hasHalf)
        stars.add(const Icon(Icons.star_half, color: Colors.amber, size: 16));
      else
        stars.add(const Icon(Icons.star_border, color: Colors.amber, size: 16));
    }
    return Row(children: stars);
  }
}
