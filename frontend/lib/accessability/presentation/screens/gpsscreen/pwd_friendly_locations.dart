import 'package:flutter/material.dart';
import 'package:Accessability/accessability/data/model/pwd_friendly_location.dart';
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

final List<PwdFriendlyLocation> pwdFriendlyLocations = [
  PwdFriendlyLocation(
    name: "Dagupan City Hall",
    latitude: 16.04361106008402,
    longitude: 120.33531522527143,
    details: "Wheelchair ramps, accessible restrooms, and reserved parking.",
  ),
  PwdFriendlyLocation(
    name: "Nepo Mall Dagupan",
    latitude: 16.051224004022384,
    longitude: 120.34170650545146,
    details: "Elevators, ramps, and PWD-friendly restrooms.",
  ),
  PwdFriendlyLocation(
    name: "Dagupan Public Market",
    latitude: 16.043166316470707,
    longitude: 120.33608116388851,
    details: "Wheelchair-friendly pathways and accessible stalls.",
  ),
  PwdFriendlyLocation(
    name: "PHINMA University of Pangasinan",
    latitude: 16.047254394614715,
    longitude: 120.34250043932526,
    details: "Wheelchair accessible entrances and parking lots.",
  ),
];
