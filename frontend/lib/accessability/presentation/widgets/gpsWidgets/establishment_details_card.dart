import 'package:accessability/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_state.dart';
import 'package:accessability/accessability/logic/bloc/user/user_bloc.dart';
import 'package:accessability/accessability/presentation/widgets/bottomSheetWidgets/rating_review_widget.dart';
import 'package:flutter/material.dart';
import 'package:accessability/accessability/data/model/place.dart';
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
  State<EstablishmentDetailsCard> createState() =>
      _EstablishmentDetailsCardState();
}

class _EstablishmentDetailsCardState extends State<EstablishmentDetailsCard> {
  bool _isFavorite = false;
  bool _isCheckingFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  void _checkFavoriteStatus() async {
    if (widget.place.id.isEmpty) return;

    setState(() {
      _isCheckingFavorite = true;
    });

    try {
      // Check if this place exists in favorites
      context
          .read<PlaceBloc>()
          .add(CheckFavoriteStatusEvent(place: widget.place));
    } catch (e) {
      print('Error checking favorite status: $e');
    }

    setState(() {
      _isCheckingFavorite = false;
    });
  }

  void _toggleFavorite() {
    context
        .read<PlaceBloc>()
        .add(ToggleFavoritePlaceEvent(place: widget.place));
  }

  String _streetViewUrl() {
    final key = dotenv.env['GOOGLE_API_KEY'] ?? '';
    return 'https://maps.googleapis.com/maps/api/streetview?size=800x400'
        '&location=${widget.place.latitude},${widget.place.longitude}'
        '&fov=80&heading=70&pitch=0&key=$key';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlaceBloc, PlaceState>(
      listener: (context, state) {
        if (state is PlaceFavoriteStatusChecked) {
          setState(() {
            _isFavorite = state.isFavorite;
          });
        } else if (state is PlacesLoaded) {
          // Update favorite status when places are loaded
          final favoritePlace = state.places.firstWhere(
            (p) => _isSamePlace(p, widget.place),
            orElse: () => widget.place,
          );
          setState(() {
            _isFavorite = favoritePlace.isFavorite;
          });
        } else if (state is PlaceFavoriteToggled) {
          // Update when favorite is toggled
          if (_isSamePlace(state.place, widget.place)) {
            setState(() {
              _isFavorite = state.isFavorite;
            });
          }
        }
      },
      child: _buildCardContent(),
    );
  }

  bool _isSamePlace(Place a, Place b) {
    // Compare by Google Place ID
    if (a.googlePlaceId != null &&
        b.googlePlaceId != null &&
        a.googlePlaceId == b.googlePlaceId) {
      return true;
    }

    // Compare by OSM ID
    if (a.osmId != null && b.osmId != null && a.osmId == b.osmId) {
      return true;
    }

    // Compare by coordinates and name (with tolerance for floating point precision)
    final latDiff = (a.latitude - b.latitude).abs();
    final lngDiff = (a.longitude - b.longitude).abs();
    return latDiff < 0.0001 && lngDiff < 0.0001 && a.name == b.name;
  }

  Widget _buildCardContent() {
    // If PWD location we keep the old RatingReviewWidget approach
    if (widget.isPwdLocation) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
        child: BlocProvider.value(
          value: BlocProvider.of<UserBloc>(context),
          child: RatingReviewWidget(
            locationId: widget.place.id,
            locationName: widget.place.name,
            imageUrl: _streetViewUrl(),
            onClose: widget.onClose,
          ),
        ),
      );
    }

    // Non-PWD layout
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + actions (heart + X button) in one row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              Expanded(
                child: Text(
                  (widget.place.name != null &&
                          widget.place.name!.trim().isNotEmpty)
                      ? widget.place.name!
                      : 'Unnamed Place',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5B2EA6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Heart (favorite) - Now works for all place types
              if (_isCheckingFavorite)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? const Color(0xFF5B2EA6) : Colors.grey,
                  ),
                  onPressed: _toggleFavorite,
                ),

              // Close (X)
              IconButton(
                icon: Icon(Icons.close, color: Colors.grey[700]),
                onPressed: widget.onClose,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Location row (pin icon + address)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Color(0xFF5B2EA6), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.place.address ?? 'Unknown location',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Source indicator (optional)
          if (widget.place.source != 'user') ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.public, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'From ${widget.place.source}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Image at the bottom (full width)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _streetViewUrl(),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                color: Colors.grey[100],
                child: const Center(
                  child: Icon(Icons.image_not_supported,
                      color: Colors.grey, size: 36),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
