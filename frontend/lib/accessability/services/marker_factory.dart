// lib/services/marker_factory.dart
import 'package:accessability/accessability/data/model/place.dart' show Place;
import 'package:accessability/accessability/presentation/widgets/reusableWidgets/favorite_map_marker.dart'
    show FavoriteMapMarker;
import 'package:accessability/accessability/utils/badge_icon.dart'
    show BadgeIcon;
import 'package:accessability/accessability/utils/map_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Small factory to centralize marker/bitmap creation and caching.
/// Mirrors the generation logic you used in-screen, including options for
/// icon sizes, colors, and fallback behavior.
class MarkerFactory {
  MarkerFactory._(); // static-only

  static final Map<String, BitmapDescriptor> _favCache = {};
  static final Map<String, BitmapDescriptor> _badgeCache = {};

  /// Generate (or return cached) favorite/place marker bitmap.
  /// `cacheKey` should be unique per place + parameters (same pattern you had previously).
  static Future<BitmapDescriptor> ensureFavoriteBitmap({
    required BuildContext ctx,
    required String cacheKey,
    required Color placeColor,
    double outerSize = 88,
    double innerSize = 45,
    double pixelRatio = 1.0,
    double outerOpacity = 0.45,
  }) async {
    if (_favCache.containsKey(cacheKey)) return _favCache[cacheKey]!;

    try {
      final desc = await FavoriteMapMarker.toBitmapDescriptor(
        ctx,
        cacheKey: cacheKey,
        pixelRatio: pixelRatio <= 0 ? 1.0 : pixelRatio,
        size: outerSize,
        outerColor: placeColor,
        outerStrokeColor: placeColor,
        outerOpacity: outerOpacity,
        innerBgColor: Colors.white,
        iconColor: placeColor,
        icon: Icons.place,
        iconSize: innerSize * 0.60,
      );

      if (desc != null) {
        _favCache[cacheKey] = desc;
        return desc;
      }
    } catch (e) {
      debugPrint('MarkerFactory.ensureFavoriteBitmap error: $e');
    }

    final fallback =
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    _favCache[cacheKey] = fallback;
    return fallback;
  }

  /// Create and/or cache a category badge (used by the nearby fetch logic).
  static Future<BitmapDescriptor> createBadgeForPlaceType({
    required BuildContext ctx,
    required String placeType,
    int size = 64,
  }) async {
    final cacheKey = 'badge_$placeType';
    if (_badgeCache.containsKey(cacheKey)) return _badgeCache[cacheKey]!;

    final IconData iconData = _iconForPlaceType(placeType);
    final Color accent = MapUtils.colorForPlaceType(placeType);

    try {
      final badge = await BadgeIcon.createBadgeWithIcon(
        ctx: ctx,
        size: size,
        outerRingColor: Colors.white,
        iconBgColor: accent,
        innerRatio: 0.86,
        iconRatio: 0.90,
        icon: iconData,
      );
      _badgeCache[cacheKey] = badge;
      return badge;
    } catch (e) {
      debugPrint('MarkerFactory.createBadgeForPlaceType error: $e');
      final fallback = BitmapDescriptor.defaultMarker;
      _badgeCache[cacheKey] = fallback;
      return fallback;
    }
  }

  /// Convenience: create a Marker for a Place (keeps the same infoWindow/onTap contract).
  /// Note: this method does not add the marker to the map; it just returns it.
  static Future<Marker> createPlaceMarker({
    required BuildContext ctx,
    required Place place,
    required Future<BitmapDescriptor> Function() iconProvider,
    required void Function() onInfoTap,
    void Function()? onTap,
  }) async {
    BitmapDescriptor icon;
    try {
      icon = await iconProvider();
    } catch (e) {
      icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }

    return Marker(
      markerId: MarkerId('place_${place.id}'),
      position: LatLng(place.latitude, place.longitude),
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      zIndex: 300,
      infoWindow: InfoWindow(
        title: place.name,
        snippet:
            '${'category'.tr()}: ${place.category ?? ''}\nTap for 3D navigation',
        onTap: onInfoTap,
      ),
      onTap: onTap,
    );
  }

  static IconData _iconForPlaceType(String type) {
    final t = type.toLowerCase();
    if (t.contains('bus')) return Icons.directions_bus;
    if (t.contains('restaurant') || t.contains('restawran'))
      return Icons.restaurant;
    if (t.contains('grocery') || t.contains('grocer'))
      return Icons.local_grocery_store;
    if (t.contains('hotel')) return Icons.hotel;
    return Icons.place;
  }

  static void clearCaches() {
    _favCache.clear();
    _badgeCache.clear();
  }
}
