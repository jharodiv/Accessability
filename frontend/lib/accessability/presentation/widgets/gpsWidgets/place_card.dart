import 'package:flutter/material.dart';
import 'package:accessability/accessability/data/model/place.dart';
import 'package:accessability/accessability/utils/map_utils.dart';

typedef PlaceCardTap = void Function(Place place);

class PlaceCard extends StatelessWidget {
  final Place place;
  final PlaceCardTap? onTap;
  final PlaceCardTap? onRouteTap;
  final Color? accentColor; // pass your PWD color when used in that context
  final double fillOpacity;

  const PlaceCard({
    Key? key,
    required this.place,
    this.onTap,
    this.onRouteTap,
    this.accentColor,
    this.fillOpacity = 0.5, // 50% as you requested
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color color =
        accentColor ?? MapUtils.colorForPlaceType(place.category);
    final String subtitle = place.address ?? '';

    return InkWell(
      onTap: () => onTap?.call(place),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            // left icon (circle colored like PWD circle)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(fillOpacity),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.location_on,
                  size: 26,
                  color: color,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // text block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // name
                  Text(
                    place.name ?? 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),

                  const SizedBox(height: 4),

                  // subtitle/address + optional rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (place.averageRating != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.star,
                                  size: 14, color: Colors.amber[700]),
                              const SizedBox(width: 4),
                              Text(
                                (place.averageRating!).toStringAsFixed(1),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // route button
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => onRouteTap?.call(place),
                  icon: Icon(Icons.directions),
                  tooltip: 'Route',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
