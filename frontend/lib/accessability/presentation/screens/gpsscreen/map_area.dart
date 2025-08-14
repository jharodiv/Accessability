// map_area.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

typedef OnCameraMoveCallback = void Function(CameraPosition);
typedef OnMapCreatedCallback = void Function(GoogleMapController controller);

class MapArea extends StatelessWidget {
  final Key? key;
  final CameraPosition initialCamera;
  final Set<Marker> markers;
  final Set<Circle> circles;
  final Set<Polyline> polylines;
  final Set<Polygon> polygons;
  final OnCameraMoveCallback? onCameraMove;
  final OnMapCreatedCallback? onMapCreated;
  final void Function(LatLng)? onTap;
  final MapType mapType;
  final bool myLocationEnabled;
  final bool zoomGesturesEnabled;

  const MapArea({
    this.key,
    required this.initialCamera,
    required this.markers,
    required this.circles,
    required this.polylines,
    required this.polygons,
    this.onCameraMove,
    this.onMapCreated,
    this.onTap,
    this.mapType = MapType.normal,
    this.myLocationEnabled = true,
    this.zoomGesturesEnabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      key: key,
      initialCameraPosition: initialCamera,
      markers: markers,
      circles: circles,
      polylines: polylines,
      polygons: polygons,
      mapType: mapType,
      myLocationEnabled: myLocationEnabled,
      zoomGesturesEnabled: zoomGesturesEnabled,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      onCameraMove: onCameraMove,
      onMapCreated: onMapCreated,
      onTap: onTap,
    );
  }
}
