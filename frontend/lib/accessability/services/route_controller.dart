// lib/services/route_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:accessability/accessability/utils/map_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Callbacks used by the UI to react to route changes.
typedef OnPolylinesChanged = void Function(Set<Polyline> polylines);
typedef OnRouteActiveChanged = void Function(bool active);
typedef OnReroutingChanged = void Function(bool rerouting);
typedef OnDestinationReached = void
    Function(); // NEW: Destination reached callback

class RouteController {
  RouteController({
    required this.mapControllerGetter,
    this.onPolylinesChanged,
    this.onRouteActiveChanged,
    this.onReroutingChanged,
    this.onDestinationReached, // NEW: Destination reached callback
    this.maxRouteDeviationMeters = 50.0,
    this.destinationReachedThresholdMeters =
        10.0, // NEW: Threshold for destination reached
  });

  /// A function returning the current GoogleMapController (may be null).
  final GoogleMapController? Function() mapControllerGetter;

  final OnPolylinesChanged? onPolylinesChanged;
  final OnRouteActiveChanged? onRouteActiveChanged;
  final OnReroutingChanged? onReroutingChanged;
  final OnDestinationReached?
      onDestinationReached; // NEW: Destination reached callback

  // Internal state (kept inside controller)
  List<LatLng> _routePoints = [];
  LatLng? _routeDestination;
  bool _isRouteActive = false;
  bool _isRerouting = false;
  bool _isWheelchair = false;
  Color _routeColor = const Color(0xFF6750A4);
  bool _destinationReachedNotified =
      false; // NEW: Track if notification was shown

  // NEW: Free camera movement control
  bool _shouldFixCamera = true; // Default to true for backward compatibility
  bool _isFollowingUser = false;

  Timer? _routeUpdateTimer;
  Timer? _rerouteCheckTimer;

  /// Tuning: meters considered "off-route".
  double maxRouteDeviationMeters;

  /// NEW: Distance threshold to consider destination reached (in meters)
  double destinationReachedThresholdMeters;

  // Expose read-only state for UI
  List<LatLng> get routePoints => _routePoints;
  LatLng? get routeDestination => _routeDestination;
  bool get isRouteActive => _isRouteActive;
  bool get isRerouting => _isRerouting;
  Color get routeColor => _routeColor;
  bool get isFollowingUser => _isFollowingUser; // NEW: Expose following state

  void dispose() {
    _routeUpdateTimer?.cancel();
    _rerouteCheckTimer?.cancel();
  }

  /// NEW: Check if user has reached destination
  bool _hasReachedDestination(LatLng currentLocation) {
    if (_routeDestination == null) return false;

    final distanceToDestination =
        MapUtils.calculateDistanceKm(currentLocation, _routeDestination!) *
            1000.0; // Convert km to meters

    return distanceToDestination <= destinationReachedThresholdMeters;
  }

  /// NEW: Stop navigation and notify that destination was reached
  void _handleDestinationReached() {
    if (!_destinationReachedNotified) {
      _destinationReachedNotified = true;
      stopFollowingUser();
      onDestinationReached?.call();
    }
  }

  /// Create a route from [origin] to [destination] using OSRM (same API as before).
  /// This function sets internal route state and notifies callbacks (polylines).
  Future<void> createRoute(LatLng origin, LatLng destination) async {
    _isRerouting = true;
    _destinationReachedNotified = false; // NEW: Reset reached notification
    onReroutingChanged?.call(true);
    try {
      // Use wheelchair/driving profile to match original toggling behavior.
      final profile = _isWheelchair ? 'wheelchair' : 'driving';

      final url = Uri.parse('https://router.project-osrm.org/route/v1/$profile/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}?overview=full&geometries=geojson');

      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('Routing failed with status ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final coords = data['routes'][0]['geometry']['coordinates'] as List;

      // OSRM returns [lon, lat]
      _routePoints = coords
          .map<LatLng>(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      // compute summary visual polyline
      _routeColor = _isWheelchair ? Colors.green : const Color(0xFF6750A4);
      final poly = Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: _routeColor,
        width: 6,
      );

      _routeDestination = destination;
      _isRouteActive = true;
      onPolylinesChanged?.call({poly});
      onRouteActiveChanged?.call(true);
    } catch (e) {
      // preserve behavior: if routing fails keep UI in a safe state
      rethrow;
    } finally {
      _isRerouting = false;
      onReroutingChanged?.call(false);
    }
  }

  /// NEW: Start periodic camera following and reroute checking with optional camera fixation.
  /// [currentLocationGetter] should return the current LatLng or null.
  /// [shouldFixCamera] controls whether camera follows user or stays free to move.
  void startFollowingUser(
    ValueGetter<LatLng?> currentLocationGetter, {
    bool shouldFixCamera = true, // NEW: Parameter to control camera fixation
    Duration updateInterval = const Duration(seconds: 1),
    Duration rerouteInterval = const Duration(seconds: 10),
  }) {
    stopFollowingUser();

    _shouldFixCamera = shouldFixCamera; // NEW: Store camera preference
    _isFollowingUser = true; // NEW: Track following state

    // Only update camera immediately if we should fix it
    if (_shouldFixCamera) {
      _updateCameraForNavigation(currentLocationGetter);
    }

    _routeUpdateTimer = Timer.periodic(updateInterval, (_) {
      final currentLocation = currentLocationGetter();
      if (currentLocation != null) {
        // NEW: Check if destination reached on each update
        if (_hasReachedDestination(currentLocation)) {
          _handleDestinationReached();
          return; // Stop further updates if destination reached
        }

        // NEW: Only update camera if we should fix it
        if (_shouldFixCamera) {
          _updateCameraForNavigation(currentLocationGetter);
        }
      }
    });

    _rerouteCheckTimer = Timer.periodic(rerouteInterval, (_) {
      final currentLocation = currentLocationGetter();
      if (currentLocation != null && !_hasReachedDestination(currentLocation)) {
        _checkRouteDeviation(currentLocation);
      }
    });
  }

  /// Stop following (cancel timers).
  void stopFollowingUser() {
    _routeUpdateTimer?.cancel();
    _routeUpdateTimer = null;
    _rerouteCheckTimer?.cancel();
    _rerouteCheckTimer = null;
    _isFollowingUser = false; // NEW: Reset following state

    // NEW: Clear route state when stopping
    if (_isRouteActive) {
      _isRouteActive = false;
      _routePoints.clear();
      _routeDestination = null;
      onPolylinesChanged?.call({});
      onRouteActiveChanged?.call(false);
    }
  }

  /// NEW: Toggle camera fixation on/off while keeping navigation active
  void toggleCameraFixation() {
    _shouldFixCamera = !_shouldFixCamera;

    // If turning fixation on and we're following, do an immediate camera update
    if (_shouldFixCamera && _isFollowingUser) {
      final currentLocation = _getCurrentLocation?.call();
      if (currentLocation != null) {
        _updateCameraForNavigation(_getCurrentLocation!);
      }
    }
  }

  /// NEW: Get current camera fixation state
  bool get isCameraFixed => _shouldFixCamera;

  // Store the current location getter for reuse
  ValueGetter<LatLng?>? _getCurrentLocation;

  /// Toggle wheelchair profile used for routing.
  void toggleWheelchairFriendly() {
    _isWheelchair = !_isWheelchair;
  }

  /// Checks whether the user has deviated too far from the route; if so,
  /// re-request route from current location to the stored destination.
  Future<void> _checkRouteDeviation(LatLng currentLocation) async {
    if (_routePoints.isEmpty || _routeDestination == null) return;

    double minDistanceMeters = double.infinity;
    for (final p in _routePoints) {
      // MapUtils returns km; convert to meters (same as original approach).
      final dMeters = MapUtils.calculateDistanceKm(currentLocation, p) * 1000.0;
      if (dMeters < minDistanceMeters) minDistanceMeters = dMeters;
    }

    if (minDistanceMeters > maxRouteDeviationMeters) {
      // immediate re-route from current position
      await createRoute(currentLocation, _routeDestination!);
    }
  }

  /// Camera update logic that mirrors your original algorithm:
  /// - find closest route point
  /// - look ahead ~20 indices
  /// - compute bearing to lookahead
  /// - compute dynamic tilt/zoom based on remaining distance
  /// - offset camera target so user is not centered (user placed lower on screen)
  void _updateCameraForNavigation(ValueGetter<LatLng?> currentLocationGetter) {
    // NEW: Store the location getter for reuse
    _getCurrentLocation = currentLocationGetter;

    final controller = mapControllerGetter();
    final currentLocation = currentLocationGetter();
    if (controller == null ||
        currentLocation == null ||
        _routeDestination == null ||
        _routePoints.isEmpty) return;

    // NEW: Don't update camera if destination reached
    if (_hasReachedDestination(currentLocation)) {
      _handleDestinationReached();
      return;
    }

    // 1) find closest index
    int closestIndex = 0;
    double minD = double.infinity;
    for (int i = 0; i < _routePoints.length; i++) {
      final d = MapUtils.calculateDistanceKm(currentLocation, _routePoints[i]);
      if (d < minD) {
        minD = d;
        closestIndex = i;
      }
    }

    // 2) lookahead index (preserve original lookahead of +20)
    final lookAheadIndex = math.min(closestIndex + 20, _routePoints.length - 1);
    final lookAheadPoint = _routePoints[lookAheadIndex];

    // 3) camera bearing uses bearing from current -> lookahead
    final cameraBearing =
        MapUtils.calculateBearing(currentLocation, lookAheadPoint);

    // 4) dynamic tilt and zoom based on remaining distance (km -> preserve numbers)
    final distanceToDestinationKm =
        MapUtils.calculateDistanceKm(currentLocation, _routeDestination!);
    final dynamicTilt =
        math.min(60.0, math.max(30.0, 60.0 - (distanceToDestinationKm * 0.5)));
    final dynamicZoom =
        math.min(18.0, math.max(16.0, 18.0 - (distanceToDestinationKm * 0.02)));

    // 5) offset so user appears at ~30% from bottom (preserve original)
    const double userScreenPosition = 0.3;
    final offsetLat = (lookAheadPoint.latitude - currentLocation.latitude) *
        userScreenPosition;
    final offsetLng = (lookAheadPoint.longitude - currentLocation.longitude) *
        userScreenPosition;
    final targetPoint = LatLng(currentLocation.latitude + offsetLat,
        currentLocation.longitude + offsetLng);

    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: targetPoint,
      zoom: dynamicZoom,
      tilt: dynamicTilt,
      bearing: cameraBearing,
    )));
  }

  /// Utility: calculates remaining route distance in kilometers (like original).
  double calculateRemainingDistanceKm({LatLng? fromLocation}) {
    if (_routePoints.isEmpty) return 0.0;

    // If fromLocation provided, find nearest index relative to that; otherwise assume index 0.
    int nearestIndex = 0;
    if (fromLocation != null) {
      double minD = double.infinity;
      for (int i = 0; i < _routePoints.length; i++) {
        final d = MapUtils.calculateDistanceKm(fromLocation, _routePoints[i]);
        if (d < minD) {
          minD = d;
          nearestIndex = i;
        }
      }
    }

    double remainingKm = 0.0;
    for (int i = nearestIndex; i < _routePoints.length - 1; i++) {
      remainingKm +=
          MapUtils.calculateDistanceKm(_routePoints[i], _routePoints[i + 1]);
    }
    return remainingKm;
  }
}
