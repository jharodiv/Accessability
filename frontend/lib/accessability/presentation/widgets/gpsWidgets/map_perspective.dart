// lib/models/map_perspective.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum MapPerspective { classic, aerial, terrain, street, perspective }

/// Small utility helpers so callers (like GpsScreen) can stay thin.
class MapPerspectiveUtils {
  /// MapType for a perspective
  static MapType mapTypeFor(MapPerspective p) {
    switch (p) {
      case MapPerspective.classic:
        return MapType.normal;
      case MapPerspective.aerial:
        return MapType.satellite;
      case MapPerspective.terrain:
        return MapType.terrain;
      case MapPerspective.street:
        return MapType.hybrid;
      case MapPerspective.perspective:
        return MapType.normal;
    }
  }

  /// CameraPosition for a perspective given a center LatLng.
  /// Keeps the same zoom/tilt/bearing values used in your original code.
  static CameraPosition cameraPositionFor(
    MapPerspective p,
    LatLng center, {
    double classicZoom = 14.4746,
    double streetZoom = 18.0,
    double perspectiveZoom = 18.0,
    double perspectiveTilt = 60.0,
    double perspectiveBearing = 45.0,
  }) {
    switch (p) {
      case MapPerspective.classic:
        return CameraPosition(target: center, zoom: classicZoom);
      case MapPerspective.aerial:
        return CameraPosition(target: center, zoom: classicZoom);
      case MapPerspective.terrain:
        return CameraPosition(target: center, zoom: classicZoom);
      case MapPerspective.street:
        return CameraPosition(target: center, zoom: streetZoom);
      case MapPerspective.perspective:
        return CameraPosition(
          target: center,
          zoom: perspectiveZoom,
          tilt: perspectiveTilt,
          bearing: perspectiveBearing,
        );
    }
  }
}
