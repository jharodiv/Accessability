// gps_map.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

typedef CameraMoveCallback = void Function(CameraPosition position);
typedef MapCreatedCallback = void Function(GoogleMapController controller);

class GpsMap extends StatelessWidget {
  final Key mapKey;
  final CameraPosition initialCamera;
  final Set<Marker> markers;
  final Set<Circle> circles;
  final Set<Polyline> polylines;
  final MapType mapType;
  final CameraMoveCallback? onCameraMove;
  final MapCreatedCallback? onMapCreated;
  final void Function(LatLng)? onTap;
  final bool myLocationEnabled;
  final Set<Polygon> polygons;

  const GpsMap({
    required this.mapKey,
    required this.initialCamera,
    required this.markers,
    required this.polygons, // <--- new

    required this.circles,
    required this.polylines,
    required this.mapType,
    this.onCameraMove,
    this.onMapCreated,
    this.onTap,
    this.myLocationEnabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      key: mapKey,
      initialCameraPosition: initialCamera,
      onCameraMove: onCameraMove,
      onMapCreated: onMapCreated,
      onTap: onTap,
      polygons: polygons, // <--- pass polygons
      markers: markers,
      circles: circles,
      polylines: polylines,
      mapType: mapType,
      zoomControlsEnabled: false,
      myLocationEnabled: myLocationEnabled,
      zoomGesturesEnabled: true,
      compassEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}
