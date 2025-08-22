import 'dart:async';
import 'dart:convert'; // For JSON decoding.
import 'dart:math';
import 'package:AccessAbility/accessability/data/model/place.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_state.dart'
    as place_state;
import 'package:AccessAbility/accessability/presentation/widgets/gpsWidgets/fov_overlay_widget.dart';
import 'package:AccessAbility/accessability/utils/badge_icon.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
// Import your own packages (update the paths as needed)
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_event.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/pwd_friendly_locations.dart';
import 'package:AccessAbility/accessability/presentation/widgets/accessability_footer.dart';
import 'package:AccessAbility/accessability/presentation/widgets/google_helper/openstreetmap_helper.dart';
import 'package:AccessAbility/accessability/presentation/widgets/google_helper/map_view_screen.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/top_widgets.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_state.dart'
    as user_state;
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/marker_handler.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/nearby_places_handler.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/tutorial_widget.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/location_widgets.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/favorite_widget.dart';
import 'package:AccessAbility/accessability/presentation/widgets/safetyAssistWidgets/safety_assist_widget.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_state.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:AccessAbility/accessability/data/model/place.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GpsScreen extends StatefulWidget {
  const GpsScreen({super.key});

  @override
  _GpsScreenState createState() => _GpsScreenState();
}

class _GpsScreenState extends State<GpsScreen> {
  late LocationHandler _locationHandler;
  final MarkerHandler _markerHandler = MarkerHandler();
  final NearbyPlacesHandler _nearbyPlacesHandler = NearbyPlacesHandler();
  final Map<String, BitmapDescriptor> _badgeIconCache = {};
  late TutorialWidget _tutorialWidget;
  final GlobalKey inboxKey = GlobalKey();
  final GlobalKey settingsKey = GlobalKey();
  final GlobalKey youKey = GlobalKey();
  final GlobalKey locationKey = GlobalKey();
  final GlobalKey securityKey = GlobalKey();
  final GlobalKey<TopwidgetsState> _topWidgetsKey = GlobalKey();
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  bool _isLocationFetched = false;
  late Key _mapKey = UniqueKey();
  String _activeSpaceId = '';
  bool _isLoading = false;
  Place? _selectedPlace;
  double _routeBearing = 0.0;
  double _routeTilt = 60.0;
  double _routeZoom = 18.0;
  bool _isRouteActive = false;
  Timer? _routeUpdateTimer;
  LatLng? _routeDestination;
  List<LatLng> _routePoints = [];
  double _currentZoom = 14.0; // track current zoom
  final double _pwdBaseRadiusMeters =
      30.0; // base radius for pwd locations — tweak as needed
  final Color _pwdCircleColor = const Color(0xFF7C4DFF);
  double _navigationPanelOffset = 0.0;
  Set<Polygon> _fovPolygons = {};

  MapType _currentMapType = MapType.normal;
  MapPerspective? _pendingPerspective; // New field

  // Variables for polylines.a
  Set<Polyline> _polylines = {};

  final String _googleAPIKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
  final double _initialNavigationPanelBottom = 0.20;
  double _pwdRadiusMultiplier = 1.0;
  double _currentZoomPrev = 14.0;
  late final ValueNotifier<double> _mapZoomNotifier =
      ValueNotifier<double>(_currentZoom);
  Timer? _zoomDebounceTimer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    print("Using API Key: $_googleAPIKey");

    _mapKey = UniqueKey();

    // Fetch user data and places.
    context.read<UserBloc>().add(FetchUserData());
    context.read<PlaceBloc>().add(GetAllPlacesEvent());

    // Initialize the tutorial widget.
    _tutorialWidget = TutorialWidget(
      inboxKey: inboxKey,
      settingsKey: settingsKey,
      youKey: youKey,
      locationKey: locationKey,
      securityKey: securityKey,
      onTutorialComplete: _onTutorialComplete,
    );

    // Initialize LocationHandler.
    _locationHandler = LocationHandler(
      onMarkersUpdated: (markers) {
        // Merge new markers with existing markers (excluding user markers)
        final existingMarkers = _markers
            .where((marker) => !marker.markerId.value.startsWith('user_'))
            .toSet();
        final updatedMarkers = existingMarkers.union(markers);
        setState(() {
          _markers = updatedMarkers;
        });
      },
    );

    // Get user location and initialize marker and camera.
    _locationHandler.getUserLocation().then((_) {
      setState(() {
        _isLocationFetched = true;
      });
      _locationHandler.initializeUserMarker();
      if (_locationHandler.currentLocation != null &&
          _locationHandler.mapController != null) {
        _locationHandler.mapController!.animateCamera(
          CameraUpdate.newLatLng(_locationHandler.currentLocation!),
        );
      }
      // Apply a pending perspective if it was passed before location was ready.
      if (_pendingPerspective != null) {
        applyMapPerspective(_pendingPerspective!);
        _pendingPerspective = null;
      }
    });

    _getPwdLocationsAndCreateMarkers();

    // Show the tutorial if onboarding has not been completed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authBloc = context.read<AuthBloc>();
      final hasCompletedOnboarding = authBloc.state is AuthenticatedLogin
          ? (authBloc.state as AuthenticatedLogin).hasCompletedOnboarding
          : false;
      if (!hasCompletedOnboarding) {
        _tutorialWidget.showTutorial(context);
      }
    });
  }

  bool _latLngEqual(LatLng a, LatLng b, {double eps = 1e-6}) {
    return (a.latitude - b.latitude).abs() <= eps &&
        (a.longitude - b.longitude).abs() <= eps;
  }

  bool _pointsEqual(List<LatLng> a, List<LatLng> b, {double eps = 1e-6}) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_latLngEqual(a[i], b[i], eps: eps)) return false;
    }
    return true;
  }

  bool _polygonsGeometryEqual(Set<Polygon> a, Set<Polygon> b) {
    if (a.length != b.length) return false;
    final Map<String, Polygon> ma = {for (var p in a) p.polygonId.value: p};
    final Map<String, Polygon> mb = {for (var p in b) p.polygonId.value: p};
    if (!ma.keys.toSet().containsAll(mb.keys.toSet())) return false;
    for (final id in ma.keys) {
      final pa = ma[id]!;
      final pb = mb[id]!;
      if (!_pointsEqual(pa.points, pb.points)) return false;
      // optionally compare style if you care about it:
      if (pa.fillColor != pb.fillColor || pa.strokeWidth != pb.strokeWidth)
        return false;
    }
    return true;
  }

  /// Call this to change PWD circle size and immediately rebuild circles
  void setPwdRadiusMultiplier(double multiplier) async {
    try {
      final locations = await getPwdFriendlyLocations();
      setState(() {
        _pwdRadiusMultiplier = multiplier.clamp(0.2, 3.0);
        _circles = createPwdfriendlyRouteCircles(locations);
      });
    } catch (e) {
      print('Error updating circles: $e');
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  double _radiusForZoom(double zoom, double baseMeters) {
    // Heuristic: when zoomed out, make radius bigger so it remains visible.
    // Increased the clamp upper bound so extreme zoom-outs scale more.
    final num factor =
        pow(2, 13.0 - zoom).clamp(0.25, 12.0); // <-- 12.0 (was 6.0)
    return max(8.0, baseMeters * factor);
  }

  /// Create circles for the given pwd-friendly locations list.
  /// Expects objects in `pwdFriendlyLocations` to have `latitude`, `longitude`, and optional `radiusMeters`.
  Set<Circle> createPwdfriendlyRouteCircles(List<dynamic> pwdLocations) {
    final Set<Circle> circles = {};

    // helper to keep stroke width reasonable across zoom levels
    int _strokeWidthForZoom(double zoom) {
      // a bit bolder at high zoom so the circle is visible
      final int w = ((zoom - 12) * 0.6).round();
      return w.clamp(1, 8);
    }

    // Minimum radius on screen (in pixels) we want the circle to appear as.
    // Increase this to make circles larger when zoomed in.
    const double minPixelRadius = 16.0;

    // Preferred pixel radius — attempt to keep circles approximately this size when possible
    const double preferredPixelRadius = 28.0;

    for (final loc in pwdLocations) {
      final double lat = _parseDouble(loc['latitude']);
      final double lng = _parseDouble(loc['longitude']);
      final double baseRadius = _pwdBaseRadiusMeters; // keep your base

      // meters-per-pixel at this latitude (web mercator)
      final double latRad = lat * (pi / 180.0);
      final double metersPerPixel =
          156543.03392 * cos(latRad) / pow(2.0, _currentZoom);

      // zoom-adaptive meters (your existing heuristic)
      final double zoomAdaptiveMeters =
          _radiusForZoom(_currentZoom, baseRadius) * _pwdRadiusMultiplier;

      // Convert desired on-screen sizes into meters (so we can take the max)
      final double preferredMeters = preferredPixelRadius * metersPerPixel;
      final double minMetersFloor = minPixelRadius * metersPerPixel;

      // Final radius: keep the larger of (zoom heuristic) or preferred on-screen meters
      double finalRadiusMeters = max(zoomAdaptiveMeters, preferredMeters);

      // Always ensure a conservative absolute floor (avoid too tiny radii)
      const double absoluteMinMeters = 4.0; // tiny absolute floor to avoid zero
      finalRadiusMeters =
          max(finalRadiusMeters, max(minMetersFloor, absoluteMinMeters));

      final int strokeWidth = _strokeWidthForZoom(_currentZoom);

      // Optional debug — uncomment if you want runtime logs of sizes:
      // print('PWD circle @($lat,$lng) zoom=$_currentZoom metersPerPx=${metersPerPixel.toStringAsFixed(4)} finalRadius=${finalRadiusMeters.toStringAsFixed(2)} stroke=$strokeWidth');

      final circle = Circle(
        circleId: CircleId('pwd_circle_${lat}_${lng}'),
        center: LatLng(lat, lng),
        radius: finalRadiusMeters,
        fillColor: _pwdCircleColor.withOpacity(0.16),
        strokeColor: _pwdCircleColor.withOpacity(0.95),
        strokeWidth: strokeWidth,
        // Increase zIndex so circle renders above lower-z-index things (markers may still appear above in some implementations).
        zIndex: 200,
        visible: true,
        consumeTapEvents: true,
        onTap: () {
          if (_locationHandler.mapController != null) {
            final targetZoom = max(15.0, min(18.0, _currentZoom + 1.6));
            _locationHandler.mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(lat, lng), targetZoom),
            );
          }
        },
      );

      circles.add(circle);
    }
    return circles;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is MapPerspective) {
      // Save the perspective for later.
      _pendingPerspective = args;
      if (_isLocationFetched && _locationHandler.mapController != null) {
        applyMapPerspective(_pendingPerspective!);
        _pendingPerspective = null;
      }
    }
  }

  @override
  void dispose() {
    _locationHandler.disposeHandler();
    _zoomDebounceTimer?.cancel();
    _mapZoomNotifier.dispose();
    _locationHandler.disposeHandler();
    super.dispose();
    super.dispose();
  }

  void _updateMapLocation(Place place) {
    print(
        "Updating map location to: ${place.name} at (${place.latitude}, ${place.longitude})");
    if (_locationHandler.mapController != null) {
      _locationHandler.mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(place.latitude, place.longitude),
            zoom: 16, // Adjust zoom level as needed.
          ),
        ),
      );
    }
  }

  Future<void> _getPwdLocationsAndCreateMarkers() async {
    try {
      final locations = await getPwdFriendlyLocations();

      _markerHandler
          .createMarkers(locations, _locationHandler.currentLocation)
          .then((markers) {
        final pwdMarkers = markers.map((marker) {
          if (marker.markerId.value.startsWith('pwd_')) {
            // Find the corresponding location data
            final location = locations.firstWhere(
              (loc) => marker.markerId.value == 'pwd_${loc["name"]}',
              orElse: () => {},
            );

            return Marker(
              markerId: marker.markerId,
              position: marker.position,
              icon: marker.icon,
              zIndex: 100, // lower than the circle's 200
              infoWindow: InfoWindow(
                title: marker.infoWindow.title,
                snippet: 'Tap to show details and rate',
              ),
              onTap: () async {
                // Fetch the complete place data from Firebase including ratings
                try {
                  final doc = await _firestore
                      .collection('pwd_locations')
                      .doc(location["id"])
                      .get();
                  if (doc.exists) {
                    // Convert string values to double
                    final double latitude = _parseDouble(doc['latitude']);
                    final double longitude = _parseDouble(doc['longitude']);

                    final pwdPlace = Place(
                      id: doc.id,
                      userId: '',
                      name: doc['name'],
                      category: 'PWD Friendly',
                      latitude: latitude,
                      longitude: longitude,
                      timestamp: DateTime.now(),
                      address: doc['details'],
                      averageRating: _parseDouble(doc['averageRating']),
                      totalRatings: doc['totalRatings'] is int
                          ? doc['totalRatings'] as int
                          : int.tryParse(
                                  doc['totalRatings']?.toString() ?? '0') ??
                              0,
                      reviews: doc['reviews'] != null
                          ? List<Map<String, dynamic>>.from(doc['reviews'])
                          : null,
                    );

                    setState(() {
                      _selectedPlace = pwdPlace;
                    });
                  }
                } catch (e) {
                  print('Error fetching place details: $e');
                }
              },
            );
          }
          return marker;
        }).toSet();

        setState(() {
          _markers.addAll(pwdMarkers);
        });
      });
    } catch (e) {
      print('Error fetching PWD locations: $e');
    }
  }

  // Callback when the tutorial is completed.
  void _onTutorialComplete() {
    _locationHandler.getUserLocation().then((_) {
      setState(() {
        _isLocationFetched = true;
      });
      if (_locationHandler.currentLocation != null &&
          _locationHandler.mapController != null) {
        _locationHandler.mapController!.animateCamera(
          CameraUpdate.newLatLng(_locationHandler.currentLocation!),
        );
      }
      _locationHandler.initializeUserMarker();
    });

    // Use Firebase data instead of static list
    _getPwdLocationsAndCreateMarkers();
  }

  void _handleSpaceIdChanged(String spaceId) {
    setState(() {
      _activeSpaceId = spaceId;
      _isLoading = true;
    });
  }

  /// Fetch nearby places and rebuild markers with an onTap callback
  /// that draws a route from the user's location.
  Future<void> _fetchNearbyPlaces(String placeType) async {
    if (_locationHandler.currentLocation == null) {
      print("Current location is null - cannot fetch places");
      return;
    }

    print("Fetching nearby $placeType places...");

    // return camera to user location briefly
    if (_locationHandler.mapController != null) {
      await _locationHandler.mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _locationHandler.currentLocation!,
            zoom: 14.5,
          ),
        ),
      );
    }

    try {
      final result = await _nearbyPlacesHandler.fetchNearbyPlaces(
        placeType,
        _locationHandler.currentLocation!,
      );

      print("Received result from NearbyPlacesHandler: ${result != null}");

      if (result != null && result.isNotEmpty) {
        print("Processing ${result['markers']?.length ?? 0} markers...");

        // Preserve special markers
        final existingMarkers = _markers
            .where((marker) =>
                marker.markerId.value.startsWith("pwd_") ||
                marker.markerId.value.startsWith("user_") ||
                marker.markerId.value.startsWith("place_"))
            .toSet();

        final Set<Marker> newMarkers = {};

        // mapping placeType -> icon & color (tweak to your taste)
        IconData _iconForPlaceType(String type) {
          final t = type.toLowerCase();
          if (t.contains('bus')) return Icons.directions_bus;
          if (t.contains('restaurant') || t.contains('restawran'))
            return Icons.restaurant;
          if (t.contains('grocery') || t.contains('grocer'))
            return Icons.local_grocery_store;
          if (t.contains('hotel')) return Icons.hotel;
          return Icons.place;
        }

        Color _colorForPlaceType(String type) {
          final t = type.toLowerCase();
          if (t.contains('bus')) return Colors.blue;
          if (t.contains('restaurant') || t.contains('restawran'))
            return Colors.red;
          if (t.contains('grocery') || t.contains('grocer'))
            return Colors.green;
          if (t.contains('hotel')) return Colors.teal;
          return const Color(0xFF6750A4);
        }

        // Prepare/cache badge for this category
        final cacheKey = 'badge_$placeType';
        BitmapDescriptor badgeIcon;
        if (_badgeIconCache.containsKey(cacheKey)) {
          badgeIcon = _badgeIconCache[cacheKey]!;
        } else {
          // create composite badge: white outer, colored inner, white icon
          final iconData = _iconForPlaceType(placeType);
          final accentColor = _colorForPlaceType(placeType);
          badgeIcon = await BadgeIcon.createBadgeWithIcon(
            ctx: context,
            size: 50,
            outerRingColor: Colors.white,
            innerBgColor: Colors.transparent,
            iconBgColor: accentColor, // your purple
            innerRatio: 0.86,
            iconBgRatio: 0.34,
            iconRatio: 0.95,
            icon: iconData,
          );
          _badgeIconCache[cacheKey] = badgeIcon;
        }

        // Build new markers from handler result
        if (result['markers'] != null) {
          final markersSet = result['markers'] is Set
              ? result['markers'] as Set<Marker>
              : Set<Marker>.from(result['markers']);

          for (final marker in markersSet) {
            print("Adding marker: ${marker.markerId} at ${marker.position}");

            final Marker newMarker = Marker(
              markerId: marker.markerId,
              position: marker.position,
              icon: badgeIcon, // <- use our composite badge
              infoWindow: InfoWindow(
                title: marker.infoWindow.title,
                snippet: 'Tap to show route',
                onTap: () {
                  if (_locationHandler.currentLocation != null) {
                    _createRoute(
                        _locationHandler.currentLocation!, marker.position);
                  }
                },
              ),
              onTap: () async {
                // same detail behavior
                final openStreetMapHelper = OpenStreetMapHelper();
                try {
                  final detailedPlace =
                      await openStreetMapHelper.fetchPlaceDetails(
                    marker.position.latitude,
                    marker.position.longitude,
                    marker.infoWindow.title ?? 'Unknown Place',
                  );
                  setState(() {
                    _selectedPlace = detailedPlace;
                  });
                } catch (e) {
                  print("Error fetching place details: $e");
                }
              },
              anchor: const Offset(0.5, 0.7),
            );

            newMarkers.add(newMarker);
          }
        }

// Circles (if any) — rescale each incoming circle to remain visible across zooms
        // Circles (if any) — rescale each incoming circle to remain visible across zooms
        Set<Circle> newCircles = {};
        if (result['circles'] != null) {
          final raw = result['circles'] is Set<Circle>
              ? result['circles'] as Set<Circle>
              : Set<Circle>.from(result['circles']);

          int _strokeWidthForZoom(double zoom) {
            final int w = ((zoom - 12) * 0.5).round();
            return w.clamp(1, 5);
          }

          newCircles = raw.map((c) {
            // use the circle's radius as "base" if provided, otherwise fallback to _pwdBaseRadiusMeters
            double baseRadius = (c.radius != null && c.radius > 0)
                ? c.radius
                : _pwdBaseRadiusMeters;

            // clamp any extremely large base radii coming from the provider
            const double maxIncomingBaseMeters =
                80.0; // tweak: 50..120 to taste
            baseRadius = baseRadius.clamp(8.0, maxIncomingBaseMeters);

            // compute an adjusted radius in meters that compensates for zoom level
            // meters-per-pixel at circle latitude:
            final double latRad = c.center.latitude * (pi / 180.0);
            final double metersPerPixel =
                156543.03392 * cos(latRad) / pow(2.0, _currentZoom);

            // minimum on-screen radius in pixels (smaller so circle appears smaller)
            const double minPixelRadius =
                12.0; // was 24.0 — lower to make visual smaller

            final double zoomAdaptiveMeters =
                _radiusForZoom(_currentZoom, baseRadius) * _pwdRadiusMultiplier;

            final double minMetersFloor = minPixelRadius * metersPerPixel;

            // final shrink to control overall visual size
            const double shrinkFactor =
                0.55; // 0.3..1.0 -> smaller values = smaller circles

            final double adjustedRadius =
                max(zoomAdaptiveMeters, minMetersFloor) * shrinkFactor;

            final int strokeW = _strokeWidthForZoom(_currentZoom);

            return Circle(
              circleId: c.circleId,
              center: c.center,
              radius: adjustedRadius,
              fillColor: _pwdCircleColor.withOpacity(0.16),
              strokeColor: _pwdCircleColor.withOpacity(0.95),
              strokeWidth: strokeW,
              zIndex: c.zIndex ?? 30,
              visible: c.visible,
              consumeTapEvents: true,
              onTap: () {
                if (_locationHandler.mapController != null) {
                  final targetZoom = max(15.0, min(18.0, _currentZoom + 1.6));
                  _locationHandler.mapController!.animateCamera(
                      CameraUpdate.newLatLngZoom(c.center, targetZoom));
                }
              },
            );
          }).toSet();
        }

        setState(() {
          _markers = existingMarkers.union(newMarkers);
          _circles = newCircles;
          _polylines.clear();
        });

        print("Total markers after update: ${_markers.length}");
        print("Total circles after update: ${_circles.length}");

        // Keep your previous camera behavior
        if (_markers.isNotEmpty && _locationHandler.mapController != null) {
          _locationHandler.mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _locationHandler.currentLocation!,
                zoom: 14.5,
              ),
            ),
          );
        }
      } else {
        print("No results found for $placeType");
        setState(() {
          _circles.clear();
        });
      }
    } catch (e) {
      print("Error fetching nearby places: $e");
      if (e is TypeError) print("Type error details: ${e.toString()}");
    }
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // km
    double lat1 = start.latitude * (pi / 180);
    double lon1 = start.longitude * (pi / 180);
    double lat2 = end.latitude * (pi / 180);
    double lon2 = end.longitude * (pi / 180);

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Create a route using Google Routes API from [origin] to [destination]
  /// and display it on the map.
  Future<void> _createRoute(LatLng origin, LatLng destination) async {
    try {
      setState(() {
        _isRouteActive = true;
        _routeDestination = destination;
      });

      // First show overview of the entire route
      if (_locationHandler.mapController != null) {
        final bounds = _locationHandler.getLatLngBounds([origin, destination]);
        await _locationHandler.mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );

        // After showing overview, zoom in to start navigation
        await Future.delayed(Duration(seconds: 1));
        _startFollowingUser();
      }

      final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}?overview=full&geometries=geojson');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final geometry = data['routes'][0]['geometry']['coordinates'];

        // Store route points for following
        _routePoints = geometry
            .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
            .toList();

        // Calculate distance and duration
        final distance =
            (data['routes'][0]['distance'] / 1000).toStringAsFixed(1);
        final duration =
            (data['routes'][0]['duration'] / 60).toStringAsFixed(0);

        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: _routePoints,
              color: const Color(0xFF6750A4),
              width: 6,
            ),
          };
        });

        _updateMarkerWithRouteInfo(destination, distance, duration);
      }
    } catch (e) {
      print('Routing failed: $e');
      _stopFollowingUser();
      setState(() {
        _isRouteActive = false;
      });
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (pi / 180);
    final startLng = start.longitude * (pi / 180);
    final endLat = end.latitude * (pi / 180);
    final endLng = end.longitude * (pi / 180);

    final y = sin(endLng - startLng) * cos(endLat);
    final x = cos(startLat) * sin(endLat) -
        sin(startLat) * cos(endLat) * cos(endLng - startLng);
    final bearing = atan2(y, x);

    return (bearing * (180 / pi) + 360) % 360;
  }

  void _startFollowingUser() {
    // Cancel any existing timer
    _stopFollowingUser();

    // Update immediately
    _updateCameraForNavigation();

    // Set up periodic updates
    _routeUpdateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateCameraForNavigation();
    });
  }

  void _updateCameraForNavigation() {
    if (_locationHandler.currentLocation == null ||
        _routeDestination == null ||
        _locationHandler.mapController == null ||
        _routePoints.isEmpty) {
      return;
    }

    final currentLocation = _locationHandler.currentLocation!;

    // 1. Calculate bearing to destination
    _routeBearing = _calculateBearing(currentLocation, _routeDestination!);

    // 2. Find the closest point on the route to the user
    int closestIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < _routePoints.length; i++) {
      final distance = _calculateDistance(currentLocation, _routePoints[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    // 3. Look ahead on the route (about 50 meters ahead of the closest point)
    int lookAheadIndex = min(closestIndex + 20, _routePoints.length - 1);
    LatLng lookAheadPoint = _routePoints[lookAheadIndex];

    // 4. Calculate the bearing from user's current position to the look-ahead point
    double cameraBearing = _calculateBearing(currentLocation, lookAheadPoint);

    // 5. Calculate the tilt based on distance to destination
    double distanceToDestination =
        _calculateDistance(currentLocation, _routeDestination!);
    double dynamicTilt =
        min(60.0, max(30.0, 60.0 - (distanceToDestination * 0.5)));

    // 6. Calculate zoom level based on speed (if available) or distance
    double dynamicZoom =
        min(18.0, max(16.0, 18.0 - (distanceToDestination * 0.02)));

    // 7. Calculate target point (slightly ahead of user)
    double interpolationFactor = 0.3; // How much to look ahead (0.0 to 1.0)
    LatLng targetPoint = LatLng(
      currentLocation.latitude * (1 - interpolationFactor) +
          lookAheadPoint.latitude * interpolationFactor,
      currentLocation.longitude * (1 - interpolationFactor) +
          lookAheadPoint.longitude * interpolationFactor,
    );

    // 8. Update camera position smoothly
    _locationHandler.mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: targetPoint,
          zoom: dynamicZoom,
          tilt: dynamicTilt,
          bearing: cameraBearing,
        ),
      ),
    );

    // Update class variables for external access
    setState(() {
      _routeTilt = dynamicTilt;
      _routeZoom = dynamicZoom;
      _routeBearing = cameraBearing;
    });
  }

  void _stopFollowingUser() {
    _routeUpdateTimer?.cancel();
    _routeUpdateTimer = null;
  }

  void _resetCameraToNormal() {
    _stopFollowingUser();

    if (_locationHandler.mapController != null &&
        _locationHandler.currentLocation != null) {
      _locationHandler.mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _locationHandler.currentLocation!,
            zoom: 14.5,
            tilt: 0,
            bearing: 0,
          ),
        ),
      );
      setState(() {
        _isRouteActive = false;
        _polylines.clear();
        _routeDestination = null;
        _routePoints.clear();
      });
    }
  }

  void _updateMarkerWithRouteInfo(
      LatLng position, String distance, String duration) {
    final marker = _markers.firstWhere(
      (m) => m.position == position,
      orElse: () => throw Exception('Marker not found'),
    );

    setState(() {
      _markers.remove(marker);
      _markers.add(marker.copyWith(
        infoWindowParam: InfoWindow(
          title: marker.infoWindow.title,
          snippet: '$distance km • $duration mins',
        ),
      ));
    });
  }

  void _onMemberPressed(LatLng location, String userId) {
    if (_locationHandler.mapController != null) {
      _locationHandler.mapController!.animateCamera(
        CameraUpdate.newLatLng(location),
      );
      _locationHandler.selectedUserId = userId;
      _locationHandler.listenForLocationUpdates();
    }
  }

  void _onMySpaceSelected() {
    setState(() {
      _locationHandler.activeSpaceId = '';
    });
    _locationHandler.updateActiveSpaceId('');
  }

  // Apply a chosen perspective by updating both the map type and camera position.
  void applyMapPerspective(MapPerspective perspective) {
    CameraPosition newPosition;
    MapType newMapType;
    final currentLatLng =
        _locationHandler.currentLocation ?? const LatLng(16.0430, 120.3333);

    switch (perspective) {
      case MapPerspective.classic:
        newMapType = MapType.normal;
        newPosition = CameraPosition(target: currentLatLng, zoom: 14.4746);
        break;
      case MapPerspective.aerial:
        newMapType = MapType.satellite;
        newPosition = CameraPosition(target: currentLatLng, zoom: 14.4746);
        break;
      case MapPerspective.terrain:
        newMapType = MapType.terrain;
        newPosition = CameraPosition(target: currentLatLng, zoom: 14.4746);
        break;
      case MapPerspective.street:
        newMapType = MapType.hybrid;
        newPosition = CameraPosition(target: currentLatLng, zoom: 18);
        break;
      case MapPerspective.perspective:
        newMapType = MapType.normal;
        newPosition = CameraPosition(
            target: currentLatLng, zoom: 18, tilt: 60, bearing: 45);
        break;
    }
    setState(() {
      _currentMapType = newMapType;
    });
    if (_locationHandler.mapController != null) {
      _locationHandler.mapController!.animateCamera(
        CameraUpdate.newCameraPosition(newPosition),
      );
    }
  }

  // Opens the map settings screen.
  Future<void> _openMapSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapViewScreen()),
    );

    print("Returned from MapViewScreen: $result");

    if (result != null && result is Map<String, dynamic>) {
      final perspective = result['perspective'] as MapPerspective;
      print("Applying perspective: $perspective");
      applyMapPerspective(perspective);
    }
  }

  Future<void> _getPwdLocationsAndUpdateCircles() async {
    try {
      final locations = await getPwdFriendlyLocations();
      if (mounted) {
        setState(() {
          _circles = createPwdfriendlyRouteCircles(locations);
        });
      }
    } catch (e) {
      print('Error updating circles with Firebase data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    _mapKey = ValueKey(isDarkMode);
    final screenHeight = MediaQuery.of(context).size.height;
    final Set<Polygon> basePolys = {};

    return BlocListener<PlaceBloc, place_state.PlaceState>(
      listener: (context, state) {
        if (state is place_state.PlacesLoaded) {
          Set<Marker> placeMarkers = {};
          for (Place place in state.places) {
            Marker marker = Marker(
              markerId: MarkerId('place_${place.id}'),
              position: LatLng(place.latitude, place.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(256.43),
              infoWindow: InfoWindow(
                title: place.name,
                snippet:
                    '${'category'.tr()}: ${place.category}\nTap for 3D navigation',
                onTap: () {
                  if (_locationHandler.currentLocation != null) {
                    _createRoute(
                      _locationHandler.currentLocation!,
                      LatLng(place.latitude, place.longitude),
                    );
                  }
                },
              ),
              onTap: () async {
                try {
                  final openStreetMapHelper = OpenStreetMapHelper();
                  final detailedPlace =
                      await openStreetMapHelper.fetchPlaceDetails(
                    place.latitude,
                    place.longitude,
                    place.name,
                  );
                  setState(() {
                    _selectedPlace = detailedPlace;
                  });
                } catch (e) {
                  print('Error fetching place details: $e');
                }
              },
            );
            placeMarkers.add(marker);
          }
          setState(() {
            _markers.removeWhere(
                (marker) => marker.markerId.value.startsWith('place_'));
            _markers.addAll(placeMarkers);
          });
        } else if (state is place_state.PlaceOperationError) {
          print("Error loading places: ${state.message}");
        }
      },
      child: BlocBuilder<UserBloc, user_state.UserState>(
        builder: (context, userState) {
          if (userState is user_state.UserInitial ||
              userState is user_state.UserLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (userState is user_state.UserError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${'error'.tr()}: ${userState.message}'),
                  ElevatedButton(
                    onPressed: () {
                      context.read<UserBloc>().add(FetchUserData());
                    },
                    child: Text('retry'.tr()),
                  ),
                ],
              ),
            );
          } else if (userState is user_state.UserLoaded) {
            return WillPopScope(
              onWillPop: () => _locationHandler.onWillPop(context),
              child: Scaffold(
                body: Stack(
                  children: [
                    GoogleMap(
                      key: _mapKey,
                      initialCameraPosition: CameraPosition(
                        target: _locationHandler.currentLocation ??
                            const LatLng(16.0430, 120.3333),
                        zoom: 14,
                      ),
                      onCameraMove: (CameraPosition pos) {
                        final newZoom = pos.zoom;

                        // Always keep a cheap local copy for other logic
                        _currentZoom = newZoom;

                        // Update the notifier (cheap, no widget rebuild)
                        _mapZoomNotifier.value = newZoom;

                        // Only recompute circles (heavy) when zoom changed sufficiently,
                        // and debounce so we don't recompute mid-gesture on every frame.
                        const double zoomThreshold =
                            0.16; // increased threshold to avoid tiny updates
                        if ((newZoom - _currentZoomPrev).abs() >
                            zoomThreshold) {
                          _currentZoomPrev = newZoom;

                          // debounce the heavy circle recompute by 180-250ms (tunable)
                          _zoomDebounceTimer?.cancel();
                          _zoomDebounceTimer =
                              Timer(const Duration(milliseconds: 200), () {
                            if (mounted) {
                              setState(() {
                                // recompute circles only after pinch stops / slows down
                                _getPwdLocationsAndUpdateCircles();
                              });
                            }
                          });
                        }
                      },
                      zoomControlsEnabled: false,
                      zoomGesturesEnabled: true,
                      myLocationButtonEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      myLocationEnabled: true,
                      mapType: _currentMapType,
                      markers: _markers,
                      circles: _circles,
                      polylines: _polylines,
                      onMapCreated: (controller) {
                        _locationHandler.onMapCreated(controller, isDarkMode);
                        if (_isLocationFetched &&
                            _locationHandler.currentLocation != null) {
                          controller.animateCamera(
                            CameraUpdate.newLatLng(
                              _locationHandler.currentLocation!,
                            ),
                          );
                        }
                        if (_pendingPerspective != null) {
                          applyMapPerspective(_pendingPerspective!);
                          _pendingPerspective = null;
                        }
                      },
                      polygons: basePolys.union(_fovPolygons),
                      onTap: (LatLng position) {
                        setState(() {
                          _selectedPlace = null;
                        });
                      },
                    ),
                    FovOverlay(
                      getCurrentLocation: () =>
                          _locationHandler.currentLocation,
                      locationStream: _locationHandler.locationStream,
                      getMapZoom: () => _mapZoomNotifier.value,
                      onPolygonsChanged: (polys) {
                        if (!_polygonsGeometryEqual(_fovPolygons, polys)) {
                          setState(() => _fovPolygons = polys);
                        }
                      },
                      fovAngle: 40.0,
                      steps: 14,
                    ),

                    // Navigation Controls
                    if (_isRouteActive)
                      Positioned(
                        top: screenHeight * 0.18, // 8% from top
                        right: 20,
                        child: Material(
                          color: Colors.transparent,
                          child: Column(
                            children: [
                              // Close Button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.close),
                                  color: Colors.black,
                                  onPressed: _resetCameraToNormal,
                                  tooltip: 'Exit navigation',
                                ),
                              ),
                              SizedBox(height: 10),
                              // Navigation Mode Toggle
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _routeUpdateTimer == null
                                        ? Icons.navigation
                                        : Icons.zoom_out_map,
                                  ),
                                  color: Colors.black,
                                  onPressed: _toggleNavigationMode,
                                  tooltip: _routeUpdateTimer == null
                                      ? 'Follow my position'
                                      : 'Show overview',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Navigation Info Panel - Positioned above bottom widgets
                    if (_isRouteActive && _routeDestination != null)
                      Positioned(
                        bottom: screenHeight * _initialNavigationPanelBottom +
                            _navigationPanelOffset,
                        left: 20,
                        right: 20,
                        child: GestureDetector(
                          onVerticalDragUpdate: (details) {
                            setState(() {
                              // Limit dragging range to prevent going off screen
                              _navigationPanelOffset = (_navigationPanelOffset -
                                      details.delta.dy)
                                  .clamp(
                                      -screenHeight * 0.3, screenHeight * 0.3);
                            });
                          },
                          onVerticalDragEnd: (details) {
                            // Snap back to original position if released near it
                            if (_navigationPanelOffset.abs() < 20) {
                              setState(() {
                                _navigationPanelOffset = 0.0;
                              });
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Add a handle bar to indicate draggability
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    margin: EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[400],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                Text(
                                  'Navigating to destination',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                if (_locationHandler.currentLocation != null)
                                  FutureBuilder<String>(
                                    future:
                                        _getLocationName(_routeDestination!),
                                    builder: (context, snapshot) {
                                      return Text(
                                        snapshot.data ?? 'Calculating...',
                                        style: TextStyle(fontSize: 14),
                                      );
                                    },
                                  ),
                                SizedBox(height: 8),
                                if (_polylines.isNotEmpty)
                                  FutureBuilder<double>(
                                    future: _calculateRouteDistance(),
                                    builder: (context, snapshot) {
                                      return Text(
                                        'Distance remaining: ${snapshot.hasData ? '${snapshot.data!.toStringAsFixed(1)} km' : 'Calculating...'}',
                                        style: TextStyle(fontSize: 14),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Regular UI Elements
                    Topwidgets(
                      key: _topWidgetsKey,
                      inboxKey: inboxKey,
                      settingsKey: settingsKey,
                      onCategorySelected: (selectedType) {
                        _fetchNearbyPlaces(selectedType);
                      },
                      onOverlayChange: (isVisible) {
                        setState(() {});
                      },
                      onSpaceSelected: _locationHandler.updateActiveSpaceId,
                      onMySpaceSelected: _onMySpaceSelected,
                      onSpaceIdChanged: _handleSpaceIdChanged,
                    ),
                    if (_locationHandler.currentIndex == 0)
                      LocationWidgets(
                        key: ValueKey(_locationHandler.activeSpaceId),
                        activeSpaceId: _locationHandler.activeSpaceId,
                        onCategorySelected: (LatLng location) {
                          _locationHandler.panCameraToLocation(location);
                        },
                        onMapViewPressed: _openMapSettings,
                        onMemberPressed: _onMemberPressed,
                        locationHandler: _locationHandler,
                        selectedPlace: _selectedPlace,
                        onCloseSelectedPlace: () {
                          setState(() {
                            _selectedPlace = null;
                          });
                        },
                        fetchNearbyPlaces: _fetchNearbyPlaces,
                        onPlaceSelected: _updateMapLocation,
                        isJoining: false,
                        onJoinStateChanged: (bool value) {},
                      ),
                    if (_locationHandler.currentIndex == 1)
                      FavoriteWidget(
                        onShowPlace: (Place place) {
                          if (_locationHandler.mapController != null) {
                            _locationHandler.mapController!.animateCamera(
                              CameraUpdate.newLatLng(
                                LatLng(place.latitude, place.longitude),
                              ),
                            );
                          }
                        },
                      ),
                    if (_locationHandler.currentIndex == 2)
                      SafetyAssistWidget(uid: userState.user.uid),
                  ],
                ),
                bottomNavigationBar: Accessabilityfooter(
                  securityKey: securityKey,
                  locationKey: locationKey,
                  youKey: youKey,
                  onOverlayChange: (isVisible) {
                    setState(() {});
                  },
                  onTap: (index) {
                    setState(() {
                      _locationHandler.currentIndex = index;
                    });
                  },
                ),
              ),
            );
          } else {
            return Center(child: Text('noUserData'.tr()));
          }
        },
      ),
    );
  }

  // Helper methods for navigation
  Future<String> _getLocationName(LatLng location) async {
    try {
      final geocodingService = OpenStreetMapGeocodingService();
      return await geocodingService.getAddressFromLatLng(location);
    } catch (e) {
      return 'Destination';
    }
  }

  // New method to toggle navigation mode
  void _toggleNavigationMode() {
    if (_routeUpdateTimer == null) {
      _startFollowingUser();
    } else {
      _stopFollowingUser();
      if (_locationHandler.currentLocation != null &&
          _routeDestination != null) {
        final bounds = _locationHandler.getLatLngBounds(
            [_locationHandler.currentLocation!, _routeDestination!]);
        _locationHandler.mapController
            ?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
      }
    }
  }

  Future<double> _calculateRouteDistance() async {
    if (_locationHandler.currentLocation == null || _routePoints.isEmpty) {
      return 0.0;
    }

    // Find the nearest point on the route
    int nearestIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < _routePoints.length; i++) {
      final distance = _calculateDistance(
        _locationHandler.currentLocation!,
        _routePoints[i],
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    // Calculate remaining distance
    double remainingDistance = 0.0;
    for (int i = nearestIndex; i < _routePoints.length - 1; i++) {
      remainingDistance += _calculateDistance(
        _routePoints[i],
        _routePoints[i + 1],
      );
    }

    return remainingDistance;
  }
}
