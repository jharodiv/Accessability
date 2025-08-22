import 'dart:async';
import 'dart:convert'; // For JSON decoding.
import 'dart:math';
import 'package:AccessAbility/accessability/data/model/place.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_state.dart'
    as place_state;
import 'package:AccessAbility/accessability/presentation/widgets/gpsWidgets/circle_manager.dart';
import 'package:AccessAbility/accessability/presentation/widgets/gpsWidgets/fov_overlay_widget.dart';
import 'package:AccessAbility/accessability/presentation/widgets/gpsWidgets/gps_map.dart';
import 'package:AccessAbility/accessability/utils/badge_icon.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:AccessAbility/accessability/presentation/widgets/reusableWidgets/favorite_map_marker.dart';

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
  bool _isTutorialShown = false;
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
  List<NearbyCircleSpec> _nearbyCircleSpecs = [];
  MapType _currentMapType = MapType.normal;
  MapPerspective? _pendingPerspective; // New field
  List<dynamic> _cachedPwdLocations = [];
  final Map<String, BitmapDescriptor> _favMarkerCache = {};

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
  bool _isWheelchairFriendlyRoute = false;
  Color _routeColor = const Color(0xFF6750A4); // Default purple

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

    // // Show the tutorial if onboarding has not been completed.
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final authBloc = context.read<AuthBloc>();
    //   final hasCompletedOnboarding = authBloc.state is AuthenticatedLogin
    //       ? (authBloc.state as AuthenticatedLogin).hasCompletedOnboarding
    //       : false;
    //   if (!hasCompletedOnboarding) {
    //     _tutorialWidget.showTutorial(context);q
    //   }
    // });
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

  Color _colorForPlaceType(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('bus')) return Colors.blue;
    if (t.contains('restaurant') || t.contains('restawran')) return Colors.red;
    if (t.contains('grocery') || t.contains('grocer')) return Colors.green;
    if (t.contains('hotel')) return Colors.teal;
    // fallback to your preferred purple
    return const Color(0xFF6750A4);
  }

  Future<BitmapDescriptor> _ensureFavoriteBitmap(
    BuildContext ctx,
    Place place, {
    double outerSize = 88,
    double innerSize = 45,
    double pixelRatio = 0,
  }) async {
    final Color placeColor = _colorForPlaceType(place.category);
    final cacheKey =
        'place_${place.id}_v2_c${placeColor.value}_s${outerSize.toInt()}_is${innerSize.toInt()}';

    // quick cache hit
    if (_favMarkerCache.containsKey(cacheKey)) {
      debugPrint('FavMarker cache hit for ${place.id} key=$cacheKey');
      return _favMarkerCache[cacheKey]!;
    }

    debugPrint(
        'Generating fav bitmap for place ${place.id} using color: $placeColor (key=$cacheKey)');

    try {
      final desc = await FavoriteMapMarker.toBitmapDescriptor(
        ctx,
        cacheKey: cacheKey,
        pixelRatio: (pixelRatio <= 0) ? 0 : pixelRatio,
        size: outerSize,
        outerColor: placeColor, // your same purple (unchanged)
        outerStrokeColor: placeColor, // same purple (unchanged)
        outerOpacity: 0.45, // try 0.45 or 0.35 to make it even more subtle
        innerBgColor: Colors.white,
        iconColor: placeColor,
        icon: Icons.place,
        iconSize: innerSize * 0.60,
      );

      // sanity-check descriptor (some plugins may return default marker)
      if (desc == null) throw Exception('Descriptor is null');

      _favMarkerCache[cacheKey] = desc;
      debugPrint('Generated fav bitmap for ${place.id}');
      return desc;
    } catch (e, st) {
      debugPrint('Error generating fav bitmap for ${place.id}: $e\n$st');
      // fallback: return default violet marker as last resort (visible)
      final fallback =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      _favMarkerCache[cacheKey] = fallback;
      return fallback;
    }
  }

  // REPLACE THIS METHOD
  Future<Marker> _createPlaceMarker(Place place) async {
    final Color placeColor = _colorForPlaceType(place.category);
    debugPrint('Creating marker for place ${place.id} color=$placeColor');

    BitmapDescriptor icon;
    try {
      icon = await _ensureFavoriteBitmap(
        context,
        place,
        outerSize: 88,
        innerSize: 40,
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      debugPrint('Got BitmapDescriptor for place ${place.id}');
    } catch (e, st) {
      debugPrint('Error creating custom icon for place ${place.id}: $e\n$st');
      icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }

    // Defensive: if icon is null (shouldn't happen), use default marker
    final usedIcon = icon;

    final marker = Marker(
      markerId: MarkerId('place_${place.id}'),
      position: LatLng(place.latitude, place.longitude),
      icon: usedIcon,
      anchor: const Offset(0.5, 0.5),
      zIndex: 300,
      infoWindow: InfoWindow(
        title: place.name,
        snippet:
            '${'category'.tr()}: ${place.category ?? ''}\nTap for 3D navigation',
        onTap: () {
          if (_locationHandler.currentLocation != null) {
            _createRoute(_locationHandler.currentLocation!,
                LatLng(place.latitude, place.longitude));
          }
        },
      ),
      onTap: () async {
        try {
          final openStreetMapHelper = OpenStreetMapHelper();
          final detailedPlace = await openStreetMapHelper.fetchPlaceDetails(
            place.latitude,
            place.longitude,
            place.name,
          );
          if (!mounted) return;
          setState(() => _selectedPlace = detailedPlace);
        } catch (e) {
          debugPrint('Error fetching details: $e');
        }
      },
    );

    return marker;
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

  /// Create circles for the given pwd-friendly locations list.
  /// Expects objects in `pwdFriendlyLocations` to have `latitude`, `longitude`, and optional `radiusMeters`.
  Set<Circle> createPwdfriendlyRouteCircles(
    List<dynamic> pwdLocations, {
    double? currentZoom,
    double? pwdBaseRadiusMeters,
    double? pwdRadiusMultiplier,
    Color? pwdCircleColor,
    void Function(LatLng center, double suggestedZoom)? onTap,
  }) {
    final double cz = currentZoom ?? _currentZoom;
    final double baseMeters = pwdBaseRadiusMeters ?? _pwdBaseRadiusMeters;
    final double multiplier = pwdRadiusMultiplier ?? _pwdRadiusMultiplier;
    final Color color = pwdCircleColor ?? _pwdCircleColor;

    // Provide a sensible default onTap (same behavior you used previously).
    final void Function(LatLng, double) effectiveOnTap = onTap ??
        ((center, suggestedZoom) {
          _locationHandler.mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(center, suggestedZoom));
        });

    return CircleManager.createPwdfriendlyRouteCircles(
      pwdLocations: pwdLocations,
      currentZoom: cz,
      pwdBaseRadiusMeters: baseMeters,
      pwdRadiusMultiplier: multiplier,
      pwdCircleColor: color,
      onTap: effectiveOnTap,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // --- Apply map perspective if provided ---
    final args = ModalRoute.of(context)?.settings.arguments;
    debugPrint('[GpsScreen] didChangeDependencies: args = $args');

    if (args is MapPerspective) {
      debugPrint('[GpsScreen] MapPerspective detected, applying...');
      _pendingPerspective = args;
      if (_isLocationFetched && _locationHandler.mapController != null) {
        debugPrint('[GpsScreen] MapPerspective applied immediately');
        applyMapPerspective(_pendingPerspective!);
        _pendingPerspective = null;
      } else {
        debugPrint('[GpsScreen] MapPerspective pending until map ready');
      }
    }

    // --- Show tutorial if route requested it ---
    final showTutorial =
        args is Map<String, dynamic> && args['showTutorial'] == true;
    debugPrint('[GpsScreen] showTutorial flag = $showTutorial');

    final authState = context.read<AuthBloc>().state;
    debugPrint('[GpsScreen] authState = $authState');
    debugPrint('[GpsScreen] _isTutorialShown = $_isTutorialShown');

    if (!_isTutorialShown && authState is AuthenticatedLogin && showTutorial) {
      debugPrint('[GpsScreen] Triggering tutorial...');
      _isTutorialShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tutorialWidget.showTutorial(context);
        debugPrint('[GpsScreen] Tutorial shown');
      });
    } else {
      debugPrint('[GpsScreen] Tutorial not triggered');
    }
  }

  @override
  void dispose() {
    _locationHandler.disposeHandler();
    _zoomDebounceTimer?.cancel();
    _mapZoomNotifier.dispose();
    _locationHandler.disposeHandler();
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

  // Replace the existing _buildPlaceMarkersAsync with this version
  Future<void> _buildPlaceMarkersAsync(List<Place> places) async {
    debugPrint('buildPlaceMarkers called with ${places.length} places');

    // Build icons in parallel to speed up marker rendering.
    final futures = <Future<Marker>>[];
    for (final place in places) {
      futures.add(_createPlaceMarker(place));
    }

    // Wait for all markers to be created.
    final createdMarkers = await Future.wait(futures);

    if (!mounted) return;

    // --- Build NearbyCircleSpec list for all places (lightweight specs) ---
    final List<NearbyCircleSpec> placeSpecs = places.map((place) {
      return NearbyCircleSpec(
        id: 'place_circle_${place.id}',
        center: LatLng(place.latitude, place.longitude),
        // use base fallback (you can replace with per-place radius if you have one)
        baseRadius: _pwdBaseRadiusMeters,
        zIndex: 200,
        visible: true,
      );
    }).toList();

    // --- Compute scaled circles using CircleManager (same algorithm as _fetchNearbyPlaces) ---
    final Set<Circle> computedPlaceCirclesRaw =
        CircleManager.computeNearbyCirclesFromSpecs(
      specs: placeSpecs,
      currentZoom: _currentZoom,
      pwdBaseRadiusMeters: _pwdBaseRadiusMeters,
      pwdRadiusMultiplier: _pwdRadiusMultiplier,
      pwdCircleColor:
          _pwdCircleColor, // used as placeholder - we'll recolor per-place below
      onTap: (center, suggestedZoom) {
        _locationHandler.mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(center, suggestedZoom),
        );
      },
      // match the tuning used for nearby places
      minPixelRadius: 24.0,
      shrinkFactor: 0.92,
      extraVisualBoost: 1.15,
    );

    // --- Recolor each computed circle to match the corresponding place's color ---
    // Build a map from place id -> color to apply
    final Map<String, Color> placeColorById = {
      for (final p in places) p.id: _colorForPlaceType(p.category)
    };

    final Set<Circle> computedPlaceCircles = computedPlaceCirclesRaw.map((c) {
      final String circleIdValue = c.circleId.value;
      final String placeId = _placeIdFromCircleId(circleIdValue);
      final Color placeColor = placeColorById.containsKey(placeId)
          ? placeColorById[placeId]!
          : _pwdCircleColor;

      // recreate the circle with the same geometry but recolored
      return Circle(
        circleId: c.circleId,
        center: c.center,
        radius: c.radius,
        fillColor: placeColor.withOpacity(0.16),
        strokeColor: placeColor.withOpacity(0.95),
        strokeWidth: c.strokeWidth,
        zIndex: c.zIndex,
        visible: c.visible,
        consumeTapEvents: true,
        onTap: () {
          // replicate the same onTap used by CircleManager (zoom in slightly)
          _locationHandler.mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              c.center,
              max(15.0, min(18.0, _currentZoom + 1.6)),
            ),
          );
        },
      );
    }).toSet();

    // --- Update state atomically: replace place_ markers and place_circle_ circles ---
    setState(() {
      // Replace all markers with place_ prefix
      _markers
          .removeWhere((marker) => marker.markerId.value.startsWith('place_'));
      _markers.addAll(createdMarkers.toSet());

      // Remove existing place_circle_ circles, then add the newly computed recolored ones.
      _circles.removeWhere((c) => c.circleId.value.startsWith('place_circle_'));
      _circles = {..._circles, ...computedPlaceCircles};
    });

    debugPrint(
        'Added ${createdMarkers.length} place markers and ${computedPlaceCircles.length} place circles');
  }

  Future<void> _getPwdLocationsAndCreateMarkers() async {
    try {
      final locations = await getPwdFriendlyLocations();
      _cachedPwdLocations = locations; // CACHE THEM

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
          _circles = createPwdfriendlyRouteCircles(locations);
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

  Set<Circle> _computeNearbyCirclesFromRaw() {
    return CircleManager.computeNearbyCirclesFromSpecs(
      specs: _nearbyCircleSpecs,
      currentZoom: _currentZoom,
      pwdBaseRadiusMeters: _pwdBaseRadiusMeters,
      pwdRadiusMultiplier: _pwdRadiusMultiplier,
      pwdCircleColor: _pwdCircleColor,
      onTap: (center, suggestedZoom) {
        _locationHandler.mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(center, suggestedZoom),
        );
      },
      // tune to match the larger visuals you wanted:
      minPixelRadius: 24.0,
      shrinkFactor: 0.92,
      extraVisualBoost: 1.15,
    );
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
            size: 64,
            outerRingColor: Colors.white,
            iconBgColor: accentColor, // your purple
            innerRatio: 0.86,
            iconRatio:
                0.90, // leaves a little padding so circle stroke is visible
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
              anchor: const Offset(0.5, 0.72),
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

          // convert incoming circles to lightweight "specs" we can rescale later
          _nearbyCircleSpecs = CircleManager.specsFromRawCircles(
            raw,
            inflateFactor: 1.6, // preserve your earlier inflation
            baseFallback: _pwdBaseRadiusMeters,
          );

          // now compute scaled circles immediately for display
          newCircles = _computeNearbyCirclesFromRaw();
        }

        // preserve existing special markers (pwd/user/place) earlier computed
        setState(() {
          _markers = existingMarkers.union(newMarkers);

          // Preserve PWD circles already in _circles (ids starting with 'pwd_')
          final existingPwdCircles = _circles
              .where((c) => c.circleId.value.startsWith('pwd_'))
              .toSet();

          // merge preserved pwd circles + newly rescaled nearby circles
          _circles = existingPwdCircles.union(newCircles);

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

      // Use wheelchair profile if enabled, otherwise use driving profile
      final profile = _isWheelchairFriendlyRoute ? 'wheelchair' : 'driving';

      final url = Uri.parse('https://router.project-osrm.org/route/v1/$profile/'
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

        // Set route color based on wheelchair-friendly setting
        final routeColor =
            _isWheelchairFriendlyRoute ? Colors.green : const Color(0xFF6750A4);

        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: _routePoints,
              color: routeColor,
              width: 6,
            ),
          };
          _routeColor = routeColor; // Store the current route color
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

  void _toggleWheelchairFriendlyRoute() {
    setState(() {
      _isWheelchairFriendlyRoute = !_isWheelchairFriendlyRoute;
    });

    // If a route is already active, recreate it with the new setting
    if (_isRouteActive &&
        _routeDestination != null &&
        _locationHandler.currentLocation != null) {
      _createRoute(_locationHandler.currentLocation!, _routeDestination!);
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
        _isWheelchairFriendlyRoute = false; // Reset to default
        _routeColor = const Color(0xFF6750A4); // Reset to purple
      });
    }
  }

  void _updateMarkerWithRouteInfo(
      LatLng position, String distance, String duration) {
    final marker = _markers.firstWhere(
      (m) => m.position == position,
      orElse: () => throw Exception('Marker not found'),
    );

    final routeType = _isWheelchairFriendlyRoute ? 'Wheelchair' : 'Car';

    setState(() {
      _markers.remove(marker);
      _markers.add(marker.copyWith(
        infoWindowParam: InfoWindow(
          title: marker.infoWindow.title,
          snippet: '$distance km • $duration mins • $routeType route',
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
          // compute pwd circles and merge with any rescaled nearby circles we have
          final Set<Circle> pwdCircles =
              createPwdfriendlyRouteCircles(locations);
          final Set<Circle> nearbyRescaled = _computeNearbyCirclesFromRaw();
          _circles = pwdCircles.union(nearbyRescaled);
        });
      }
    } catch (e) {
      print('Error updating circles with Firebase data: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller, bool isDarkMode) {
    // Call your location handler or map style logic here
    _locationHandler.onMapCreated(controller, isDarkMode);

    // Example: animate to current location if available
    if (_isLocationFetched && _locationHandler.currentLocation != null) {
      controller.animateCamera(
        CameraUpdate.newLatLng(_locationHandler.currentLocation!),
      );
    }
  }

  String _placeIdFromCircleId(String circleIdValue) {
    // expecting "place_circle_<id>"
    if (!circleIdValue.startsWith('place_circle_')) return '';
    return circleIdValue.substring('place_circle_'.length);
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
          _buildPlaceMarkersAsync(state.places);
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
                    GpsMap(
                      mapKey: _mapKey,
                      initialCamera: CameraPosition(
                        target: _locationHandler.currentLocation ??
                            const LatLng(16.0430, 120.3333),
                        zoom: 14.0,
                      ),
                      markers: _markers,
                      circles: _circles,
                      polygons: _fovPolygons, // <-- pass the FOV polygons here

                      polylines: _polylines,
                      mapType: _currentMapType,
                      onCameraMove: (CameraPosition pos) {
                        final newZoom = pos.zoom;
                        // cheap updates
                        // only react when zoom changed noticeably
                        const zoomThreshold = 0.01;
                        if ((newZoom - _currentZoom).abs() > zoomThreshold) {
                          _currentZoom = newZoom;
                          _mapZoomNotifier.value = newZoom;

                          // trigger FOV recompute / camera logic immediately (cheap)
                          // Option 1: force FOVOverlay to recompute by calling setState on polygons,
                          // if you have a function to compute polygons you can call it here:
                          // final polys = FovOverlay.computePolygons(..., newZoom);
                          // if (!_polygonsGeometryEqual(_fovPolygons, polys)) setState(() => _fovPolygons = polys);

                          // Option 2: if FovOverlay calls back via onPolygonsChanged based on getMapZoom,
                          // just force a rebuild so it re-queries the getter:
                          setState(() {});
                        } else {
                          // small movement but still update notifier so other logic can use it
                          _mapZoomNotifier.value = newZoom;
                        }
                      },

                      // heavy work deferred to onCameraIdle (fires after gestures finish)
                      onCameraIdle: () {
                        // Debounce to avoid double-firing if there are quick idles
                        _zoomDebounceTimer?.cancel();
                        _zoomDebounceTimer =
                            Timer(const Duration(milliseconds: 120), () {
                          if (!mounted) return;
                          // Recompute circles (PWD + nearby) using current zoom
                          // Use cached pwd locations and nearby specs (fast)
                          final pwdSet = createPwdfriendlyRouteCircles(
                            _cachedPwdLocations,
                            currentZoom: _currentZoom,
                            pwdBaseRadiusMeters: _pwdBaseRadiusMeters,
                            pwdRadiusMultiplier: _pwdRadiusMultiplier,
                            pwdCircleColor: _pwdCircleColor,
                            onTap: (center, suggestedZoom) {
                              _locationHandler.mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                    center, suggestedZoom),
                              );
                            },
                          );
                          final nearbySet = _computeNearbyCirclesFromRaw();
                          setState(() {
                            _circles = pwdSet.union(nearbySet);
                          });
                        });
                      },
                      onMapCreated: (controller) =>
                          _onMapCreated(controller, isDarkMode),
                      onTap: (latlng) => setState(() => _selectedPlace = null),
                    ),
                    FovOverlay(
                      getCurrentLocation: () =>
                          _locationHandler.currentLocation,
                      locationStream: _locationHandler.locationStream,
                      mapZoomListenable: _mapZoomNotifier, // <--- pass this

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
                              SizedBox(height: 10),
                              // Wheelchair Friendly Route Toggle
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
                                    _isWheelchairFriendlyRoute
                                        ? Icons.accessible
                                        : Icons.accessible_forward,
                                    color: _isWheelchairFriendlyRoute
                                        ? Colors.green
                                        : Colors.black,
                                  ),
                                  onPressed: _toggleWheelchairFriendlyRoute,
                                  tooltip: _isWheelchairFriendlyRoute
                                      ? 'Using wheelchair-friendly route'
                                      : 'Switch to wheelchair-friendly route',
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
                                // Route type indicator
                                Row(
                                  children: [
                                    Icon(
                                      _isWheelchairFriendlyRoute
                                          ? Icons.accessible
                                          : Icons.directions_car,
                                      color: _isWheelchairFriendlyRoute
                                          ? Colors.green
                                          : const Color(0xFF6750A4),
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      _isWheelchairFriendlyRoute
                                          ? 'Wheelchair-friendly route'
                                          : 'Standard route',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: _isWheelchairFriendlyRoute
                                            ? Colors.green
                                            : const Color(0xFF6750A4),
                                      ),
                                    ),
                                  ],
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
}
