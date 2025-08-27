import 'package:accessability/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:accessability/accessability/logic/bloc/user/user_bloc.dart';
import 'package:accessability/accessability/presentation/widgets/bottomSheetWidgets/rating_review_widget.dart';
import 'package:flutter/material.dart';
import 'package:accessability/accessability/data/model/place.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' show pi, sin, cos, sqrt, atan2;

// establishment_details_card.dart
class EstablishmentDetailsCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onClose;
  final bool isPwdLocation; // Add this flag

  const EstablishmentDetailsCard({
    Key? key,
    required this.place,
    this.onClose,
    this.isPwdLocation = false, // Default to false
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and close button
          Row(
            children: [
              Expanded(
                child: Text(
                  place.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6750A4),
                  ),
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: onClose,
                ),
            ],
          ),

          // Rating display for PWD locations
          if (isPwdLocation && place.averageRating != null)
            SizedBox(height: 12),
          // Street View Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              'https://maps.googleapis.com/maps/api/streetview?size=400x400'
              '&location=${place.latitude},${place.longitude}'
              '&fov=80&heading=70&pitch=0&key=${dotenv.env['GOOGLE_API_KEY']}',
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                color: Colors.grey[200],
                child: Center(child: Icon(Icons.image_not_supported)),
              ),
            ),
          ),

          // Rating and Reviews for PWD locations
          if (isPwdLocation)
            BlocProvider.value(
              value: BlocProvider.of<UserBloc>(context),
              child: RatingReviewWidget(
                locationId: place.id,
                locationName: place.name,
              ),
            )
        ],
      ),
    );
  }
}
