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
  // static Future<BitmapDescriptor> ensureFavoriteBitmap({
  //   required BuildContext ctx,
  //   required String cacheKey,
  //   Color? placeColor, // optional now
  //   double outerSize = 88,
  //   double innerSize = 45,
  //   double pixelRatio = 1.0,
  //   double outerOpacity = 1.0,
  // }) async {
  //   // Build a composite key so different colors/sizes won't collide in the cache
  //   final resolvedColor = placeColor ?? const Color(0xFF7C4DFF);
  //   final compositeKey =
  //       '${cacheKey}_${resolvedColor.value}_os${outerSize.toInt()}_is${innerSize.toInt()}_pr${pixelRatio.toStringAsFixed(2)}';
  //   final Color accent = MapUtils.colorForPlaceType(placeType);

  //   if (_favCache.containsKey(compositeKey)) return _favCache[compositeKey]!;

  //   try {
  //     // Use BadgeIcon (keeps BadgeIcon untouched). We'll set:
  //     // - outerRingColor = resolvedColor (purple),
  //     // - innerBgColor = white (pointer/background white),
  //     // - iconBgColor = resolvedColor (not strictly needed by your BadgeIcon impl,
  //     //   but keeps intent clear), and
  //     // - icon = Icons.place with the glyph colored purple by BadgeIcon (if BadgeIcon supports icon color).
  //     final bmp = await BadgeIcon.createBadgeWithIcon(
  //       ctx: ctx,
  //       size: outerSize.toInt(),
  //       outerRingColor: Colors.white,
  //       iconBgColor: accent,
  //       icon: Icons.place,
  //       innerRatio: 0.56,
  //       iconRatio: 0.52,
  //     );

  //     _favCache[compositeKey] = bmp;
  //     return bmp;
  //   } catch (e, st) {
  //     debugPrint('MarkerFactory.ensureFavoriteBitmap error: $e\n$st');
  //     final fallback =
  //         BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
  //     _favCache[compositeKey] = fallback;
  //     return fallback;
  //   }
  // }

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

  /// Convenience: create a Marker for a Place.
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

  /// Decide which icon to use for each place type.
  static IconData _iconForPlaceType(String type) {
    final t = type.toLowerCase();

    if (t.contains('bus')) return Icons.directions_bus;

    if (t.contains('restaurant') || t.contains('restawran')) {
      return Icons.restaurant;
    }

    if (t.contains('grocery') || t.contains('grocer')) {
      return Icons.local_grocery_store;
    }

    if (t.contains('hotel')) return Icons.hotel;

    // 🛍️ Shopping
    if (t.contains('shop') ||
        t.contains('store') ||
        t.contains('pamimili') ||
        t.contains('shopping')) {
      return Icons.storefront;
    }

    // 🏥 Hospital
    if (t.contains('hospital') ||
        t.contains('ospital') ||
        t.contains('ospit')) {
      return Icons.local_hospital;
    }

    return Icons.place; // fallback
  }

  static void clearCaches() {
    _favCache.clear();
    _badgeCache.clear();
  }
}
