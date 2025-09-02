// lib/presentation/screens/gpsscreen/gps_screen.dart
import 'dart:async';
import 'dart:convert'; // For JSON decoding.
import 'dart:math';
import 'package:accessability/accessability/backgroundServices/deep_link_service.dart';
import 'package:accessability/accessability/data/model/place.dart';
import 'package:accessability/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:accessability/accessability/logic/bloc/place/bloc/place_event.dart'
    show GetAllPlacesEvent;
import 'package:accessability/accessability/logic/bloc/place/bloc/place_state.dart'
    as place_state;
import 'package:accessability/accessability/logic/bloc/user/user_bloc.dart'
    show UserBloc;
import 'package:accessability/accessability/logic/bloc/user/user_event.dart'
    show FetchUserData;
import 'package:accessability/accessability/logic/bloc/user/user_state.dart'
    as user_state
    show UserError, UserInitial, UserLoaded, UserLoading, UserState;
import 'package:accessability/accessability/presentation/screens/gpsscreen/location_handler.dart'
    show LocationHandler;
import 'package:accessability/accessability/presentation/screens/gpsscreen/pwd_friendly_locations.dart'
    show getPwdFriendlyLocations;
import 'package:accessability/accessability/presentation/widgets/accessability_footer.dart'
    show Accessabilityfooter;
import 'package:accessability/accessability/presentation/widgets/google_helper/map_view_screen.dart'
    show MapViewScreen;
import 'package:accessability/accessability/presentation/widgets/google_helper/openstreetmap_helper.dart'
    show OpenStreetMapHelper;
import 'package:accessability/accessability/presentation/widgets/gpsWidgets/circle_manager.dart';
import 'package:accessability/accessability/presentation/widgets/gpsWidgets/fov_overlay_widget.dart';
import 'package:accessability/accessability/presentation/widgets/gpsWidgets/gps_map.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/top_widgets.dart'
    show Topwidgets, TopwidgetsState;
import 'package:accessability/accessability/services/marker_factory.dart'
    show MarkerFactory;
import 'package:accessability/accessability/services/nearby_manager.dart'
    show NearbyManager;
import 'package:accessability/accessability/services/route_controller.dart'
    show RouteController;
import 'package:accessability/accessability/themes/theme_provider.dart'
    show ThemeProvider;
import 'package:accessability/accessability/utils/badge_icon.dart';
import 'package:accessability/accessability/utils/map_utils.dart' show MapUtils;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:accessability/accessability/presentation/screens/gpsscreen/marker_handler.dart';
import 'package:accessability/accessability/presentation/screens/gpsscreen/nearby_places_handler.dart';
import 'package:accessability/accessability/presentation/screens/gpsscreen/tutorial_widget.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/location_widgets.dart';
import 'package:accessability/accessability/presentation/widgets/bottomSheetWidgets/favorite_widget.dart';
import 'package:accessability/accessability/presentation/widgets/safetyAssistWidgets/safety_assist_widget.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_state.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// MapPerspective enum (if you had it elsewhere, keep that definition; otherwise define here)
enum MapPerspective { classic, aerial, terrain, street, perspective }

class GpsScreen extends StatefulWidget {
  const GpsScreen({super.key});

  @override
  _GpsScreenState createState() => _GpsScreenState();
}

class _GpsScreenState extends State<GpsScreen> {
  // --- Handlers & services ---
  late LocationHandler _locationHandler;
  final MarkerHandler _markerHandler = MarkerHandler();
  final NearbyPlacesHandler _nearbyPlacesHandler = NearbyPlacesHandler();
  late TutorialWidget _tutorialWidget;

  // --- Keys/UI state ---
  bool _isTutorialShown = false;
  final GlobalKey inboxKey = GlobalKey();
  final GlobalKey settingsKey = GlobalKey();
  final GlobalKey youKey = GlobalKey();
  final GlobalKey locationKey = GlobalKey();
  final GlobalKey securityKey = GlobalKey();
  final GlobalKey<TopwidgetsState> _topWidgetsKey = GlobalKey();

  // --- Map UI state ---
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  bool _autoSelectAttempted = false;
  static const String _kSavedActiveSpaceKey = 'saved_active_space_id';
  bool _isLocationFetched = false;
  late Key _mapKey = UniqueKey();
  String _activeSpaceId = '';
  bool _isLoading = false;
  Place? _selectedPlace;
  double _currentZoom = 14.0; // track current zoom
  final double _pwdBaseRadiusMeters = 30.0; // base radius for pwd locations
  final Color _pwdCircleColor = const Color(0xFF7C4DFF);
  double _navigationPanelOffset = 0.0;
  Set<Polygon> _fovPolygons = {};
  MapType _currentMapType = MapType.normal;
  MapPerspective? _pendingPerspective;
  String _activeSpaceName = '';

  // Polylines / route visuals (driven by RouteController callbacks)
  Set<Polyline> _polylines = {};

  final String _googleAPIKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
  final double _initialNavigationPanelBottom = 0.20;
  double _pwdRadiusMultiplier = 1.0;
  double _currentZoomPrev = 14.0;
  late final ValueNotifier<double> _mapZoomNotifier =
      ValueNotifier<double>(_currentZoom);
  Timer? _zoomDebounceTimer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Minimal route UI state (mirrors controller via callbacks)
  bool _isRouteActive = false;
  bool _isRerouting = false;
  LatLng? _routeDestination;
  List<LatLng> _routePoints = [];
  bool _isWheelchairFriendlyRoute = false;
  Timer?
      _routeUpdateTimer; // used only to decide icon state (kept for minimal changes)

  // Nearby management
  List<NearbyCircleSpec> _nearbyCircleSpecs = [];
  List<dynamic> _cachedPwdLocations = [];

  // Services (instantiate in initState AFTER _locationHandler)
  late final RouteController routeController;
  final NearbyManager _nearbyManager = NearbyManager();

  @override
  void initState() {
    super.initState();

    print("Using API Key: $_googleAPIKey");
    _mapKey = UniqueKey();

    // Fetch user data and places.
    context.read<UserBloc>().add(FetchUserData());
    context.read<PlaceBloc>().add(GetAllPlacesEvent());

    // Initialize tutorial widget.
    _tutorialWidget = TutorialWidget(
      inboxKey: inboxKey,
      settingsKey: settingsKey,
      youKey: youKey,
      locationKey: locationKey,
      securityKey: securityKey,
      onTutorialComplete: _onTutorialComplete,
    );

    // 1) Initialize LocationHandler first (used by RouteController)
    _locationHandler = LocationHandler(
      onMarkersUpdated: (markers) {
        final existingMarkers = _markers
            .where((marker) => !marker.markerId.value.startsWith('user_'))
            .toSet();
        final updatedMarkers = existingMarkers.union(markers);
        setState(() {
          _markers = updatedMarkers;
        });
      },
    );

    // 2) Initialize RouteController after LocationHandler so its getter works correctly.
    routeController = RouteController(
      mapControllerGetter: () => _locationHandler.mapController,
      onPolylinesChanged: (polys) {
        if (!mounted) return;
        setState(() => _polylines = polys);
      },
      onRouteActiveChanged: (active) {
        if (!mounted) return;
        setState(() {
          _isRouteActive = active;
          // keep routeUpdateTimer icon semantics simple:
          if (!active) {
            _routeUpdateTimer?.cancel();
            _routeUpdateTimer = null;
          }
        });
      },
      onReroutingChanged: (rerouting) {
        if (!mounted) return;
        setState(() {
          _isRerouting = rerouting;
        });
      },
    );

    // LocationHandler immediate deviation hook -> use controller's routePoints
    _locationHandler.enableRouteDeviationChecking((LatLng newLocation) {
      if (routeController.isRouteActive &&
          routeController.routePoints.isNotEmpty) {
        _checkImmediateRouteDeviation(newLocation);
      }
    });

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

    // load PWD locations and markers (keeps behavior identical)
    _getPwdLocationsAndCreateMarkers();

    _restoreOrAutoSelectSpace();
  }

  Future<void> _restoreOrAutoSelectSpace() async {
    if (_autoSelectAttempted) return;

    try {
      debugPrint('[GpsScreen] restoreOrAutoSelectSpace start');

      // 1) Try to restore from prefs first (and fetch the space name)
      final saved = await _loadSavedActiveSpaceFromPrefs();
      if (saved != null && saved.isNotEmpty) {
        // try to fetch the space doc to get its name
        String restoredName = '';
        try {
          final doc = await _firestore.collection('Spaces').doc(saved).get();
          if (doc.exists) {
            restoredName =
                (doc.data() as Map<String, dynamic>)['name']?.toString() ?? '';
          }
        } catch (e) {
          debugPrint('[GpsScreen] failed to fetch restored space name: $e');
        }

        if (!mounted) return;
        setState(() {
          _activeSpaceId = saved;
          _activeSpaceName = restoredName;
          _isLoading = false;
        });
        try {
          _locationHandler.updateActiveSpaceId(saved);
        } catch (e) {
          debugPrint('[GpsScreen] updateActiveSpaceId failed: $e');
        }

        debugPrint(
            '[GpsScreen] restored saved active space id=$saved name=$_activeSpaceName');
        _autoSelectAttempted = true; // done
        return;
      }

      // 2) If no saved pref, only proceed to Firestore auto-select when user is available
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[GpsScreen] no current user yet; will retry later');
        return; // don't mark attempted so we can try again when user loads
      }

      // fallback: auto-select first space from Firestore (this function will set id+name too)
      await _autoSelectFirstSpace();

      _autoSelectAttempted = true;
    } catch (e, st) {
      debugPrint('[GpsScreen] restoreOrAutoSelectSpace error: $e\n$st');
      _autoSelectAttempted = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint("🛰️ GPS mounted, checking for pending deep links...");
      await Future.delayed(const Duration(seconds: 2));
      DeepLinkService().consumePendingLinkIfAny();
    });
  }

  // --- Helper: small place-type color mapping (kept local for quick tweak) ---
  Color _colorForPlaceType(String? type) {
    return MapUtils.colorForPlaceType(type);
  }

  // --- Favorite/fallback marker using MarkerFactory (delegated) ---
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

    // delegate to MarkerFactory; pass pixelRatio in a sane way
    return await MarkerFactory.ensureFavoriteBitmap(
      ctx: ctx,
      cacheKey: cacheKey,
      placeColor: placeColor,
      outerSize: outerSize,
      innerSize: innerSize,
      pixelRatio:
          pixelRatio <= 0 ? MediaQuery.of(ctx).devicePixelRatio : pixelRatio,
      outerOpacity: 0.45,
    );
  }

  Future<void> _saveActiveSpaceToPrefs(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSavedActiveSpaceKey, id);
      debugPrint('[GpsScreen] saved active space $id to prefs');
    } catch (e) {
      debugPrint('[GpsScreen] error saving active space: $e');
    }
  }

  Future<String?> _loadSavedActiveSpaceFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kSavedActiveSpaceKey);
    } catch (e) {
      debugPrint('[GpsScreen] error loading active space from prefs: $e');
      return null;
    }
  }

  // --- Place marker creation (delegates to MarkerFactory) ---
  Future<Marker> _createPlaceMarker(Place place) async {
    final cacheKey =
        'place_${place.id}_v2_c${_colorForPlaceType(place.category).value}_s88_is40';
    return MarkerFactory.createPlaceMarker(
      ctx: context,
      place: place,
      iconProvider: () => MarkerFactory.ensureFavoriteBitmap(
        ctx: context,
        cacheKey: cacheKey,
        placeColor: _colorForPlaceType(place.category),
        outerSize: 88,
        innerSize: 40,
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      ),
      onInfoTap: () {
        if (_locationHandler.currentLocation != null) {
          // start route to this place
          routeController.createRoute(_locationHandler.currentLocation!,
              LatLng(place.latitude, place.longitude));
          routeController
              .startFollowingUser(() => _locationHandler.currentLocation);
        }
      },
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
  }

  /// Call this to change PWD circle size and immediately rebuild circles
  void setPwdRadiusMultiplier(double multiplier) async {
    try {
      final locations = await getPwdFriendlyLocations();
      _cachedPwdLocations = locations;
      setState(() {
        _pwdRadiusMultiplier = multiplier.clamp(0.2, 3.0);
        _circles = createPwdfriendlyRouteCircles(locations);
      });
    } catch (e) {
      print('Error updating circles: $e');
    }
  }

  // --- Use NearbyManager for PWD circles (delegated) ---
  Set<Circle> createPwdfriendlyRouteCircles(
    List<dynamic> pwdLocations, {
    double? currentZoom,
    double? pwdBaseRadiusMeters,
    double? pwdRadiusMultiplier,
    Color? pwdCircleColor,
    void Function(LatLng center, double suggestedZoom)? onTap,
  }) {
    final cz = currentZoom ?? _currentZoom;
    final baseMeters = pwdBaseRadiusMeters ?? _pwdBaseRadiusMeters;
    final multiplier = pwdRadiusMultiplier ?? _pwdRadiusMultiplier;
    final color = pwdCircleColor ?? _pwdCircleColor;

    final effectiveOnTap = onTap ??
        ((center, suggestedZoom) {
          _locationHandler.mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(center, suggestedZoom),
          );
        });

    return _nearbyManager.createPwdfriendlyRouteCircles(
      pwdLocations,
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
        applyMapPerspective(_pendingPerspective!);
        _pendingPerspective = null;
      }
    }

    // --- Show tutorial if route requested it ---
    final showTutorial =
        args is Map<String, dynamic> && args['showTutorial'] == true;

    final authState = context.read<AuthBloc>().state;
    if (!_isTutorialShown && authState is AuthenticatedLogin && showTutorial) {
      _isTutorialShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tutorialWidget.showTutorial(context);
      });
    }
  }

  @override
  void dispose() {
    routeController.dispose();
    _locationHandler.disposeHandler();
    _zoomDebounceTimer?.cancel();
    _mapZoomNotifier.dispose();
    super.dispose();
  }

  void _updateMapLocation(Place place) {
    if (_locationHandler.mapController != null) {
      _locationHandler.mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(place.latitude, place.longitude),
            zoom: 16,
          ),
        ),
      );
    }
  }

  // --- Build place markers (keeps prior behavior but uses marker factory) ---
  Future<void> _buildPlaceMarkersAsync(List<Place> places) async {
    debugPrint('buildPlaceMarkers called with ${places.length} places');
    final futures = <Future<Marker>>[];
    for (final place in places) {
      futures.add(_createPlaceMarker(place));
    }
    final createdMarkers = await Future.wait(futures);
    if (!mounted) return;

    final List<NearbyCircleSpec> placeSpecs = places.map((place) {
      return NearbyCircleSpec(
        id: 'place_circle_${place.id}',
        center: LatLng(place.latitude, place.longitude),
        baseRadius: _pwdBaseRadiusMeters,
        zIndex: 200,
        visible: true,
      );
    }).toList();

    final Set<Circle> computedPlaceCirclesRaw =
        CircleManager.computeNearbyCirclesFromSpecs(
      specs: placeSpecs,
      currentZoom: _currentZoom,
      pwdBaseRadiusMeters: _pwdBaseRadiusMeters,
      pwdRadiusMultiplier: _pwdRadiusMultiplier,
      pwdCircleColor: _pwdCircleColor,
      onTap: (center, suggestedZoom) {
        _locationHandler.mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(center, suggestedZoom),
        );
      },
      minPixelRadius: 24.0,
      shrinkFactor: 0.92,
      extraVisualBoost: 1.15,
    );

    final Map<String, Color> placeColorById = {
      for (final p in places) p.id: _colorForPlaceType(p.category)
    };

    final Set<Circle> computedPlaceCircles = computedPlaceCirclesRaw.map((c) {
      final String circleIdValue = c.circleId.value;
      final String placeId = _placeIdFromCircleId(circleIdValue);
      final Color placeColor = placeColorById[placeId] ?? _pwdCircleColor;
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
          _locationHandler.mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              c.center,
              max(15.0, min(18.0, _currentZoom + 1.6)),
            ),
          );
        },
      );
    }).toSet();

    setState(() {
      _markers
          .removeWhere((marker) => marker.markerId.value.startsWith('place_'));
      _markers.addAll(createdMarkers.toSet());
      _circles.removeWhere((c) => c.circleId.value.startsWith('place_circle_'));
      _circles = {..._circles, ...computedPlaceCircles};
    });

    debugPrint(
        'Added ${createdMarkers.length} place markers and ${computedPlaceCircles.length} place circles');
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1) try to restore saved choice
      final saved = await _loadSavedActiveSpaceFromPrefs();
      if (saved != null && saved.isNotEmpty) {
        // set and make location handler aware
        if (mounted) {
          setState(() {
            _activeSpaceId = saved;
            _isLoading = false;
            _autoSelectAttempted = true;
          });
          try {
            _locationHandler.updateActiveSpaceId(saved);
          } catch (_) {}
          debugPrint('[GpsScreen] restored saved space id=$saved');
        }
        return;
      }

      // 2) otherwise auto-select first space from Firestore (only once)
      if (!_autoSelectAttempted && _activeSpaceId.isEmpty) {
        _autoSelectAttempted = true;
        await _autoSelectFirstSpace();
      }
    });
  }

  void _handleSpaceIdChanged(String spaceId) {
    setState(() {
      _activeSpaceId = spaceId;
      _isLoading = true;
    });
  }

  /// Convert raw nearby circles into "specs" stored in our manager and compute rescaled circles.
  Set<Circle> _computeNearbyCirclesFromRaw() {
    // delegate to NearbyManager (and also keep local copy of specs for compatibility)
    final specs = _nearbyCircleSpecs;
    if (specs.isEmpty) return {};
    return _nearbyManager.computeNearbyCirclesFromSpecs(
      currentZoom: _currentZoom,
      pwdBaseRadiusMeters: _pwdBaseRadiusMeters,
      pwdRadiusMultiplier: _pwdRadiusMultiplier,
      pwdCircleColor: _pwdCircleColor,
      onTap: (center, suggestedZoom) {
        _locationHandler.mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(center, suggestedZoom),
        );
      },
      minPixelRadius: 24.0,
      shrinkFactor: 0.92,
      extraVisualBoost: 1.15,
    );
  }

  // --- Nearby places fetching (delegates badge creation to MarkerFactory) ---
  Future<void> _fetchNearbyPlaces(String placeType) async {
    if (_locationHandler.currentLocation == null) {
      print("Current location is null - cannot fetch places");
      return;
    }

    // briefly move camera to user's location
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

      if (result != null && result.isNotEmpty) {
        final existingMarkers = _markers
            .where((marker) =>
                marker.markerId.value.startsWith("pwd_") ||
                marker.markerId.value.startsWith("user_") ||
                marker.markerId.value.startsWith("place_"))
            .toSet();

        final Set<Marker> newMarkers = {};

        // badge creation via MarkerFactory
        final badgeIcon = await MarkerFactory.createBadgeForPlaceType(
          ctx: context,
          placeType: placeType,
          size: 64,
        );

        if (result['markers'] != null) {
          final markersSet = result['markers'] is Set
              ? result['markers'] as Set<Marker>
              : Set<Marker>.from(result['markers']);

          for (final marker in markersSet) {
            debugPrint(
                'nearby handler returned marker id=${marker.markerId.value} at ${marker.position}');
            final Marker newMarker = Marker(
              markerId: marker.markerId,
              position: marker.position,
              icon: badgeIcon,
              infoWindow: InfoWindow(
                title: marker.infoWindow.title,
                snippet: 'Tap to show route',
                onTap: () {
                  if (_locationHandler.currentLocation != null) {
                    // delegate to route controller
                    routeController.createRoute(
                        _locationHandler.currentLocation!, marker.position);
                    routeController.startFollowingUser(
                        () => _locationHandler.currentLocation);
                  }
                },
              ),
              onTap: () async {
                final openStreetMapHelper = OpenStreetMapHelper();
                try {
                  final detailedPlace =
                      await openStreetMapHelper.fetchPlaceDetails(
                    marker.position.latitude,
                    marker.position.longitude,
                    marker.infoWindow.title ?? 'Unknown Place',
                  );
                  if (!mounted) return;
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

        // Circles (if any)
        Set<Circle> newCircles = {};
        if (result['circles'] != null) {
          final raw = result['circles'] is Set<Circle>
              ? result['circles'] as Set<Circle>
              : Set<Circle>.from(result['circles']);

          // Convert raw circles to specs via CircleManager (we keep local copy for backward compatibility)
          _nearbyCircleSpecs = _nearbyManager.specsFromRawCircles(
            raw,
            inflateFactor: 1.6,
            baseFallback: _pwdBaseRadiusMeters,
          );

          // compute scaled circles using NearbyManager helper
          newCircles = _computeNearbyCirclesFromRaw();
        }

        setState(() {
          _markers = existingMarkers.union(newMarkers);
          final existingPwdCircles = _circles
              .where((c) => c.circleId.value.startsWith('pwd_'))
              .toSet();
          _circles = existingPwdCircles.union(newCircles);
          _polylines.clear();
        });
      } else {
        setState(() {
          _circles.clear();
        });
      }
    } catch (e) {
      print("Error fetching nearby places: $e");
    }
  }

  /// Helper that returns a textual location name for the given LatLng.
  Future<String> _getLocationName(LatLng location) async {
    try {
      final geocodingService = OpenStreetMapGeocodingService();
      return await geocodingService.getAddressFromLatLng(location);
    } catch (e) {
      return 'Destination';
    }
  }

  // --- Navigation toggles (now delegate to RouteController) ---
  void _toggleNavigationMode() {
    if (!routeController.isRouteActive ||
        routeController.routeDestination == null) {
      // if route not active, start following
      routeController
          .startFollowingUser(() => _locationHandler.currentLocation);
      _routeUpdateTimer?.cancel();
      _routeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {});
    } else {
      // show overview: stop following and fit bounds
      routeController.stopFollowingUser();
      _routeUpdateTimer?.cancel();
      _routeUpdateTimer = null;
      if (_locationHandler.currentLocation != null &&
          routeController.routeDestination != null) {
        final bounds = _locationHandler.getLatLngBounds([
          _locationHandler.currentLocation!,
          routeController.routeDestination!
        ]);
        _locationHandler.mapController
            ?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
      }
    }
  }

  void _toggleWheelchairFriendlyRoute() {
    setState(() {
      _isWheelchairFriendlyRoute = !_isWheelchairFriendlyRoute;
    });
    routeController.toggleWheelchairFriendly();
    if (routeController.isRouteActive &&
        routeController.routeDestination != null &&
        _locationHandler.currentLocation != null) {
      // re-create route with new profile
      routeController.createRoute(
          _locationHandler.currentLocation!, routeController.routeDestination!);
    }
  }

  Future<double> _calculateRouteDistance() async {
    final remainingKm = routeController.calculateRemainingDistanceKm(
        fromLocation: _locationHandler.currentLocation);
    return remainingKm;
  }

  void _resetCameraToNormal() {
    routeController.stopFollowingUser();
    _routeUpdateTimer?.cancel();
    _routeUpdateTimer = null;
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
    }
    setState(() {
      _isRouteActive = false;
      _polylines.clear();
      _routeDestination = null;
      _routePoints.clear();
      _isWheelchairFriendlyRoute = false;
    });
  }

  /// Called by LocationHandler's deviation callback to check for immediate reroute.
  void _checkImmediateRouteDeviation(LatLng currentLocation) {
    final pts = routeController.routePoints;
    final dest = routeController.routeDestination;
    if (pts.isEmpty || dest == null) return;

    double minDistance = double.infinity;
    for (final point in pts) {
      final distance = MapUtils.calculateDistanceKm(currentLocation, point) *
          1000.0; // meters
      if (distance < minDistance) minDistance = distance;
    }

    if (minDistance > routeController.maxRouteDeviationMeters * 2) {
      // re-route immediately from current location
      routeController.createRoute(currentLocation, dest);
    }
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

  Future<void> _openMapSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapViewScreen()),
    );
    if (result != null && result is Map<String, dynamic>) {
      final perspective = result['perspective'] as MapPerspective;
      applyMapPerspective(perspective);
    }
  }

  void _onMapCreated(GoogleMapController controller, bool isDarkMode) {
    _locationHandler.onMapCreated(controller, isDarkMode);
    if (_isLocationFetched && _locationHandler.currentLocation != null) {
      controller.animateCamera(
        CameraUpdate.newLatLng(_locationHandler.currentLocation!),
      );
    }
  }

  String _placeIdFromCircleId(String circleIdValue) {
    if (!circleIdValue.startsWith('place_circle_')) return '';
    return circleIdValue.substring('place_circle_'.length);
  }

  bool _polygonsGeometryEqual(Set<Polygon> a, Set<Polygon> b) {
    if (a.length != b.length) return false;
    final Map<String, Polygon> ma = {for (var p in a) p.polygonId.value: p};
    final Map<String, Polygon> mb = {for (var p in b) p.polygonId.value: p};
    if (!ma.keys.toSet().containsAll(mb.keys.toSet())) return false;
    for (final id in ma.keys) {
      final pa = ma[id]!;
      final pb = mb[id]!;
      if (!MapUtils.pointsEqual(pa.points, pb.points)) return false;
      if (pa.fillColor != pb.fillColor || pa.strokeWidth != pb.strokeWidth)
        return false;
    }
    return true;
  }

  /// Auto-select the first space the current user is a member of
  /// (only if nothing is already selected).
  Future<void> _autoSelectFirstSpace() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      // Don't override an existing selection
      if (_activeSpaceId.isNotEmpty) return;

      final snap = await _firestore
          .collection('Spaces')
          .where('members', arrayContains: user.uid)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final id = doc.id;
        final name = (doc.data() as Map<String, dynamic>)['name'] ?? 'Unnamed';
        if (!mounted) return;
        setState(() {
          _activeSpaceId = id;
          _activeSpaceName = name; // <- set name
          _isLoading = false;
        });
        // Make the LocationHandler aware of the new active space:
        try {
          _locationHandler.updateActiveSpaceId(id);
        } catch (_) {
          // ignore if not present or fails
        }

        await _saveActiveSpaceToPrefs(id);

        debugPrint('[GpsScreen] auto-selected space id=$id name=$name');
      } else {
        debugPrint('[GpsScreen] no spaces found for user, leaving My Space');
      }
    } catch (e, st) {
      debugPrint('[GpsScreen] _autoSelectFirstSpace error: $e\n$st');
    }
  }

  Future<void> _getPwdLocationsAndCreateMarkers() async {
    try {
      final locations = await getPwdFriendlyLocations();
      _cachedPwdLocations = locations;

      _markerHandler
          .createMarkers(locations, _locationHandler.currentLocation)
          .then((markers) {
        final pwdMarkers = markers.map((marker) {
          if (marker.markerId.value.startsWith('pwd_')) {
            final location = locations.firstWhere(
              (loc) => marker.markerId.value == 'pwd_${loc["name"]}',
              orElse: () => {},
            );

            return Marker(
              markerId: marker.markerId,
              position: marker.position,
              icon: marker.icon,
              zIndex: 100,
              infoWindow: InfoWindow(
                title: marker.infoWindow.title,
                snippet: 'Tap to show details and rate',
              ),
              onTap: () async {
                try {
                  final doc = await _firestore
                      .collection('pwd_locations')
                      .doc(location["id"])
                      .get();
                  if (doc.exists) {
                    final double latitude =
                        MapUtils.parseDouble(doc['latitude']);
                    final double longitude =
                        MapUtils.parseDouble(doc['longitude']);

                    final pwdPlace = Place(
                      id: doc.id,
                      userId: '',
                      name: doc['name'],
                      category: 'PWD Friendly',
                      latitude: latitude,
                      longitude: longitude,
                      timestamp: DateTime.now(),
                      address: doc['details'],
                      averageRating: MapUtils.parseDouble(doc['averageRating']),
                      totalRatings: doc['totalRatings'] is int
                          ? doc['totalRatings'] as int
                          : int.tryParse(
                                  doc['totalRatings']?.toString() ?? '0') ??
                              0,
                      reviews: doc['reviews'] != null
                          ? List<Map<String, dynamic>>.from(doc['reviews'])
                          : null,
                    );

                    if (!mounted) return;
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

        if (!mounted) return;
        setState(() {
          _markers.addAll(pwdMarkers);
          _circles = createPwdfriendlyRouteCircles(locations);
        });
      });
    } catch (e) {
      print('Error fetching PWD locations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    _mapKey = ValueKey(isDarkMode);
    final screenHeight = MediaQuery.of(context).size.height;

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
            if (!_autoSelectAttempted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _restoreOrAutoSelectSpace();
              });
            }
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
                      polygons: _fovPolygons,
                      polylines: _polylines,
                      mapType: _currentMapType,
                      onCameraMove: (CameraPosition pos) {
                        final newZoom = pos.zoom;
                        const zoomThreshold = 0.01;
                        if ((newZoom - _currentZoom).abs() > zoomThreshold) {
                          _currentZoom = newZoom;
                          _mapZoomNotifier.value = newZoom;
                          setState(() {});
                        } else {
                          _mapZoomNotifier.value = newZoom;
                        }
                      },
                      onCameraIdle: () {
                        _zoomDebounceTimer?.cancel();
                        _zoomDebounceTimer =
                            Timer(const Duration(milliseconds: 120), () {
                          if (!mounted) return;
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
                      mapZoomListenable: _mapZoomNotifier,
                      getMapZoom: () => _mapZoomNotifier.value,
                      onPolygonsChanged: (polys) {
                        if (!_polygonsGeometryEqual(_fovPolygons, polys)) {
                          setState(() => _fovPolygons = polys);
                        }
                      },
                      fovAngle: 40.0,
                      steps: 14,
                    ),

                    // Navigation Controls (uses local UI flags which are updated by routeController)
                    if (_isRouteActive)
                      Positioned(
                        top: screenHeight * 0.18,
                        right: 20,
                        child: Material(
                          color: Colors.transparent,
                          child: Column(
                            children: [
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

                    if (_isRerouting)
                      Positioned(
                        top: screenHeight * 0.15,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.green),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Re-routing...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Navigation Info Panel
                    if (_isRouteActive &&
                        routeController.routeDestination != null)
                      Positioned(
                        bottom: screenHeight * _initialNavigationPanelBottom +
                            _navigationPanelOffset,
                        left: 20,
                        right: 20,
                        child: GestureDetector(
                          onVerticalDragUpdate: (details) {
                            setState(() {
                              _navigationPanelOffset = (_navigationPanelOffset -
                                      details.delta.dy)
                                  .clamp(
                                      -screenHeight * 0.3, screenHeight * 0.3);
                            });
                          },
                          onVerticalDragEnd: (details) {
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
                                    future: _getLocationName(
                                        routeController.routeDestination ??
                                            _locationHandler.currentLocation!),
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
                                    future: Future.value(routeController
                                        .calculateRemainingDistanceKm(
                                            fromLocation: _locationHandler
                                                .currentLocation)),
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
                      activeSpaceId: _activeSpaceId,
                      activeSpaceName: _activeSpaceName,

                      onCategorySelected: (selectedType) {
                        _fetchNearbyPlaces(selectedType);
                      },
                      onOverlayChange: (isVisible) {
                        setState(() {});
                      },
                      // Ensure GpsScreen rebuilds when a space is selected:
                      onSpaceSelected: (String id) async {
                        debugPrint(
                            '[GpsScreen] Topwidgets.onSpaceSelected -> id=$id (current _activeSpaceId=$_activeSpaceId)');
                        setState(() {
                          _locationHandler.updateActiveSpaceId(id);
                          _activeSpaceId = id;
                          _isLoading = true;
                        });

                        // persist selection so next app start restores it
                        await _saveActiveSpaceToPrefs(id);

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          debugPrint(
                              '[GpsScreen] postFrame: _activeSpaceId=$_activeSpaceId, locationHandler.activeSpaceId=${_locationHandler.activeSpaceId}');
                        });
                      },
                      // Keep the explicit "my space" handler but make sure it updates _activeSpaceId too:
                      onMySpaceSelected: () {
                        setState(() {
                          _locationHandler.updateActiveSpaceId('');
                          _activeSpaceId = '';
                          _isLoading = false;
                        });
                        // clear saved pref so next launch auto-selects first available space again
                        _saveActiveSpaceToPrefs('');
                      },
                      // You can keep onSpaceIdChanged if other logic relies on it,
                      // but ensure it updates screen state (it already does).
                      onSpaceIdChanged: _handleSpaceIdChanged,
                    ),
                    if (_locationHandler.currentIndex == 0)
                      LocationWidgets(
                        key: ValueKey(_activeSpaceId),
                        activeSpaceId: _activeSpaceId,
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
                        isJoining: false,
                        onJoinStateChanged: (bool value) {},
                        // NEW: tell LocationWidgets whether a route is active
                        isRouteActive: _isRouteActive,
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
