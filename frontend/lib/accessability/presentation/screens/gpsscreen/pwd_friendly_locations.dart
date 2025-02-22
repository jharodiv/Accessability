// pwd_friendly_locations.dart

import 'package:flutter/material.dart';
import 'package:frontend/accessability/data/model/pwd_friendly_location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PwdFriendlyLocations extends StatelessWidget {
  final List<PwdFriendlyLocation> locations;
  final Function(MarkerId) onMarkerTapped;

  const PwdFriendlyLocations({
    super.key,
    required this.locations,
    required this.onMarkerTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: locations.map((location) {
        return ListTile(
          title: Text(location.name),
          subtitle: Text(location.details),
          onTap: () {
            onMarkerTapped(MarkerId("pwd_${location.name}"));
          },
        );
      }).toList(),
    );
  }
}
