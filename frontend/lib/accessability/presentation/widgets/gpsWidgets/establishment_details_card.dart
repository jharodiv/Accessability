import 'package:accessability/accessability/logic/bloc/user/user_bloc.dart';
import 'package:accessability/accessability/presentation/widgets/bottomSheetWidgets/rating_review_widget.dart';
import 'package:flutter/material.dart';
import 'package:accessability/accessability/data/model/place.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EstablishmentDetailsCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onClose;
  final bool isPwdLocation;

  const EstablishmentDetailsCard({
    Key? key,
    required this.place,
    this.onClose,
    this.isPwdLocation = false,
  }) : super(key: key);

  String _streetViewUrl() {
    final key = dotenv.env['GOOGLE_API_KEY'] ?? '';
    return 'https://maps.googleapis.com/maps/api/streetview?size=800x400'
        '&location=${place.latitude},${place.longitude}'
        '&fov=80&heading=70&pitch=0&key=$key';
  }

  @override
  Widget build(BuildContext context) {
    // Outer padding for the sheet
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title row (keeps place title always visible)
          Row(
            children: [
              // only show name for non-PWD locations (PWD shows the name inside the reviews sheet)
              if (!isPwdLocation)
                Expanded(
                  child: Text(
                    place.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5B2EA6),
                    ),
                  ),
                ),

              // only show the header close button for non-PWD locations (PWD uses the overlay close on the image)
              if (!isPwdLocation && onClose != null)
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[700]),
                  onPressed: onClose,
                ),
            ],
          ),
          SizedBox(height: 10),

          // Behavior:
          // - For PWD location: do NOT render the top image here; pass the street view URL into the RatingReviewWidget
          //   so the image gets displayed inside the white sheet along with reviews (single sheet).
          // - For non-PWD: show image above the sheet as before.
          if (!isPwdLocation) ...[
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
                  child: Center(
                      child: Icon(Icons.image_not_supported,
                          color: Colors.grey[400])),
                ),
              ),
            ),
            SizedBox(height: 12),
          ] else
            SizedBox.shrink(),

          // White sheet container that holds the RatingReviewWidget OR fallback details
          // NOTE: kept minimal white look (no background mint, no strong shadows)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              // no heavy border or shadow to keep it 'single sheet' look
            ),
            padding: EdgeInsets.all(0), // the rating widget is self-padded
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPwdLocation)
                  // Pass imageUrl + onClose so RatingReviewWidget can display image inside the sheet with overlay close
                  BlocProvider.value(
                    value: BlocProvider.of<UserBloc>(context),
                    child: RatingReviewWidget(
                      locationId: place.id,
                      locationName: place.name,
                      imageUrl: _streetViewUrl(),
                      onClose: onClose,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Details',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        SizedBox(height: 6),
                        Text(place.address ?? '',
                            style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
