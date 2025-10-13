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

  /// Create and/or cache a category badge (used by the nearby fetch logic).
  static Future<BitmapDescriptor> createBadgeForPlaceType({
    required BuildContext ctx,
    required String placeType,
    int size = 64,
  }) async {
    final cacheKey = 'badge_${placeType.toLowerCase()}_$size';
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

  /// Create a larger, more prominent badge for important places like hospitals
  static Future<BitmapDescriptor> createProminentBadgeForPlaceType({
    required BuildContext ctx,
    required String placeType,
    int size = 72, // Slightly larger for important places
  }) async {
    final cacheKey = 'prominent_badge_${placeType.toLowerCase()}_$size';
    if (_badgeCache.containsKey(cacheKey)) return _badgeCache[cacheKey]!;

    final IconData iconData = _iconForPlaceType(placeType);
    final Color accent = MapUtils.colorForPlaceType(placeType);

    try {
      final badge = await BadgeIcon.createBadgeWithIcon(
        ctx: ctx,
        size: size,
        outerRingColor: Colors.white,
        iconBgColor: accent,
        innerRatio: 0.88, // Slightly larger inner circle
        iconRatio: 0.92, // Slightly larger icon
        icon: iconData,
      );
      _badgeCache[cacheKey] = badge;
      return badge;
    } catch (e) {
      debugPrint('MarkerFactory.createProminentBadgeForPlaceType error: $e');
      // Fall back to regular badge
      return createBadgeForPlaceType(
          ctx: ctx, placeType: placeType, size: size);
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

    // 🏥 Hospital - HIGH PRIORITY - check this first
    if (t.contains('hospital') ||
        t.contains('ospital') ||
        t.contains('medical') ||
        t.contains('clinic') ||
        t.contains('health')) {
      return Icons.local_hospital;
    }

    // 🚑 Emergency services
    if (t.contains('emergency') || t.contains('ambulance')) {
      return Icons.emergency;
    }

    // 🚌 Transportation
    if (t.contains('bus')) return Icons.directions_bus;

    // 🍕 Food
    if (t.contains('restaurant') || t.contains('restawran')) {
      return Icons.restaurant;
    }

    // 🛒 Groceries
    if (t.contains('grocery') || t.contains('grocer')) {
      return Icons.local_grocery_store;
    }

    // 🏨 Accommodation
    if (t.contains('hotel') || t.contains('motel')) return Icons.hotel;

    // 🛍️ Shopping
    if (t.contains('shop') ||
        t.contains('store') ||
        t.contains('pamimili') ||
        t.contains('shopping') ||
        t.contains('mall')) {
      return Icons.storefront;
    }

    // ⛽ Fuel
    if (t.contains('fuel') || t.contains('gas') || t.contains('petrol')) {
      return Icons.local_gas_station;
    }

    // 🏦 Banking
    if (t.contains('bank') || t.contains('atm')) {
      return Icons.account_balance;
    }

    // 🎓 Education
    if (t.contains('school') ||
        t.contains('university') ||
        t.contains('college')) {
      return Icons.school;
    }

    // 🏛️ Government
    if (t.contains('government') || t.contains('municipal')) {
      return Icons.account_balance;
    }

    return Icons.place; // fallback
  }

  /// Check if a place type should use prominent styling
  static bool isProminentPlaceType(String type) {
    final t = type.toLowerCase();
    return t.contains('hospital') ||
        t.contains('emergency') ||
        t.contains('medical') ||
        t.contains('police') ||
        t.contains('fire');
  }

  /// Get appropriate badge size for a place type
  static int getBadgeSizeForPlaceType(String type) {
    return isProminentPlaceType(type) ? 72 : 64;
  }

  static void clearCaches() {
    _favCache.clear();
    _badgeCache.clear();
  }
}
