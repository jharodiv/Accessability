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
  final ValueChanged<CameraPosition>? onCameraMove; // <-- add this
  final VoidCallback? onCameraIdle; // <-- optional
  final ValueChanged<GoogleMapController>? onMapCreated; // keep as ValueChanged

  final void Function(LatLng)? onTap;
  final bool myLocationEnabled;
  final Set<Polygon> polygons;

  const GpsMap({
    required this.mapKey,
    required this.initialCamera,
    required this.markers,
    required this.polygons, // <--- new
    this.onCameraMove,
    required this.onMapCreated,
    required this.circles,
    required this.polylines,
    required this.mapType,
    this.onTap,
    this.myLocationEnabled = true,
    super.key,
    this.onCameraIdle,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      key: mapKey,
      initialCameraPosition: initialCamera,
      onTap: onTap,
      polygons: polygons, // <--- pass polygons
      onCameraMove: (pos) {
        if (onCameraMove != null) onCameraMove!(pos);
      },
      onCameraIdle: () {
        if (onCameraIdle != null) onCameraIdle!();
      },
      markers: markers,
      onMapCreated: (controller) {
        if (onMapCreated != null) onMapCreated!(controller);
      },
      circles: circles,
      myLocationButtonEnabled: false, // <<-- hide the circular button

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
