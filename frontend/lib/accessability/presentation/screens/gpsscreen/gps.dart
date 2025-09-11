// lib/presentation/screens/gpsscreen/gps_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:accessability/accessability/backgroundServices/deep_link_service.dart';
import 'package:accessability/accessability/data/model/place.dart';
import 'package:accessability/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:accessability/accessability/presentation/widgets/dialog/ok_dialog_widget.dart';
import 'package:accessability/accessability/presentation/widgets/gpsWidgets/map_perspective.dart';
import 'package:accessability/accessability/presentation/widgets/gpsWidgets/navigation_controls.dart';
import 'package:accessability/accessability/presentation/widgets/gpsWidgets/navigation_panel.dart';
import 'package:accessability/accessability/presentation/widgets/gpsWidgets/rerouting_banner.dart';
import 'package:accessability/accessability/presentation/widgets/gpsWidgets/user_marker_info_card.dart';
import 'package:url_launcher/url_launcher.dart';

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
    show MapViewScreen, MapPerspectivePicker;
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
import 'package:accessability/accessability/utils/map_utils.dart' show MapUtils;
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
import 'package:accessability/accessability/backgroundServices/pwd_location_notification_service.dart';
import 'package:accessability/accessability/backgroundServices/space_member_notification_service.dart';

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
  late final DraggableScrollableController _favoriteSheetController;

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
  bool _showingPwdMarkers = false;

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
  final PWDLocationNotificationService _pwdNotificationService =
      PWDLocationNotificationService();
  final SpaceMemberNotificationService _spaceMemberNotificationService =
      SpaceMemberNotificationService();

  // Minimal route UI state (mirrors controller via callbacks)
  bool _isRouteActive = false;
  bool _isRerouting = false;
  LatLng? _routeDestination;
  List<LatLng> _routePoints = [];
  bool _isWheelchairFriendlyRoute = false;
  bool _isApplyingPerspective = false;
  late final DraggableScrollableController _locationSheetController;
  late final DraggableScrollableController _safetySheetController;
  bool _suppressMapTapCollapse = false;
  Timer? _suppressMapTapCollapseTimer;
  final ValueNotifier<bool> _userOverlayVisible = ValueNotifier<bool>(false);

  Timer?
      _routeUpdateTimer; // used only to decide icon state (kept for minimal changes)

  // Nearby management
  List<NearbyCircleSpec> _nearbyCircleSpecs = [];
  List<dynamic> _cachedPwdLocations = [];

  // Services (instantiate in initState AFTER _locationHandler)
  late final RouteController routeController;
  final NearbyManager _nearbyManager = NearbyManager();
  OverlayEntry? _userOverlayEntry;

  @override
  void initState() {
    super.initState();

    _favoriteSheetController = DraggableScrollableController();
    _locationSheetController = DraggableScrollableController();
    _safetySheetController = DraggableScrollableController();

    print("Using API Key: $_googleAPIKey");
    _mapKey = UniqueKey();

    _pwdNotificationService.initialize().then((_) {
      _pwdNotificationService.startLocationMonitoring();
    });

    _spaceMemberNotificationService.initialize().then((_) {
      _spaceMemberNotificationService.startMemberMonitoring();
    });

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
      onUserMarkerTap: ({
        required String userId,
        required String username,
        required LatLng location,
        required String address,
        required String profileUrl,
        required double distanceMeters,
        int? batteryPercent,
        double? speedKmh,
        DateTime? timestamp,
      }) {
        // forward to overlay helper (now including telemetry)
        _showUserOverlay(
          userId: userId,
          username: username,
          location: location,
          address: address,
          profileUrl: profileUrl,
          distanceMeters: distanceMeters,
          batteryPercent: batteryPercent,
          speedKmh: speedKmh,
          timestamp: timestamp,
        );
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
      // NEW: Add destination reached callback
      onDestinationReached: _showDestinationReachedDialog,
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

    _restoreOrAutoSelectSpace();
  }

  void _showDestinationReachedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return OkDialogWidget(
          title:
              'destination_reached'.tr(), // Make sure to add this translation
          message:
              'you_have_arrived_at_destination'.tr(), // Add this translation
          onConfirm: () {
            // Additional cleanup if needed
            setState(() {
              _isRouteActive = false;
              _polylines.clear();
              _routeDestination = null;
              _routePoints.clear();
            });
          },
        );
      },
    );
  }

  Future<void> _launchCaller(String number) async {
    if (number.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('no_number_available'.tr())),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: number);
    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('cannot_launch_phone'.tr())),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching dialer: $e')),
      );
    }
  }

  void _removeUserOverlay() {
    _userOverlayEntry?.remove();
    _userOverlayEntry = null;

    // notify LocationWidgets overlay is gone
    _userOverlayVisible.value = false;

    // allow map taps to collapse again
    _suppressMapTapCollapse = false;
    _suppressMapTapCollapseTimer?.cancel();
    _suppressMapTapCollapseTimer = null;
  }

  Future<void> _showUserOverlay({
    required String userId,
    required String username,
    required LatLng location,
    required String address,
    required String profileUrl,
    required double distanceMeters,
    int? batteryPercent,
    double? speedKmh,
    DateTime? timestamp,
  }) async {
    // remove any existing overlay first
    _removeUserOverlay();

    // Suppress the usual map-onTap collapse while we prepare/show the overlay.
    _userOverlayVisible.value = true;
    _suppressMapTapCollapse = true;
    _suppressMapTapCollapseTimer?.cancel();
    _suppressMapTapCollapseTimer = Timer(
        const Duration(seconds: 4), () => _suppressMapTapCollapse = false);

    // --- IMPORTANT: collapse relevant DraggableScrollableSheets so LocationWidgets
    // will go to its min height when the user overlay is shown.
    // We try all three controllers (favorite, location, safety). Each animateTo is
    // guarded and non-fatal so we don't crash if controller isn't attached.
    const double favoriteMin = 0.10; // matches FavoriteWidget minChildSize
    const double locationMin =
        0.20; // matches LocationWidgets._sheetMinChildSize
    const double safetyMin = 0.10; // matches SafetyAssistWidget minChildSize

    Future<void> tryCollapse(
        DraggableScrollableController? controller, double target) async {
      if (controller == null) return;
      try {
        // Only attempt if noticeably larger than target to avoid redundant calls
        final cur = controller.size;
        if (cur > target + 0.01) {
          if (controller.isAttached) {
            await controller.animateTo(
              target,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
            );
          } else {
            // If not attached yet, try a short delay then attempt again.
            await Future.delayed(const Duration(milliseconds: 120));
            if (controller.isAttached) {
              await controller.animateTo(
                target,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
              );
            } // otherwise ignore — it will be collapsed when sheet attaches
          }
        }
      } catch (e) {
        debugPrint('[GpsScreen] collapse attempt failed for controller: $e');
      }
    }

    // Fire-and-await collapses so the UI has settled before we position overlay.
    await tryCollapse(_favoriteSheetController, favoriteMin);
    await tryCollapse(_locationSheetController, locationMin);
    await tryCollapse(_safetySheetController, safetyMin);

    final controller = _locationHandler.mapController;
    if (controller == null) {
      // can't proceed — clear suppression and exit
      _suppressMapTapCollapse = false;
      _suppressMapTapCollapseTimer?.cancel();
      _suppressMapTapCollapseTimer = null;
      return;
    }

    try {
      // card size used for positioning (matches card design)
      const double cardWidth = 260.0;
      const double cardHeight = 112.0;
      const double topOffsetFromProfile = 20.0;
      const double leftNudge = 8.0;

      final screenW = MediaQuery.of(context).size.width;
      final screenH = MediaQuery.of(context).size.height;

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final bool isCurrentUser = currentUid != null && currentUid == userId;

      // conservative fallback position (center-ish)
      double left = ((screenW - cardWidth) / 2 - leftNudge)
          .clamp(8.0, screenW - cardWidth - 8.0);
      double top = ((screenH / 2) - cardHeight - topOffsetFromProfile)
          .clamp(8.0, screenH - cardHeight - 8.0);

      // Insert overlay immediately with a barrier to avoid tap-through.
      _userOverlayEntry = OverlayEntry(builder: (ctx) {
        return Stack(
          children: [
            const ModalBarrier(color: Colors.transparent, dismissible: false),
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: UserMarkerInfoCard(
                  username: username,
                  address: address,
                  distanceKm: distanceMeters / 1000.0,
                  profileUrl: profileUrl,
                  batteryPercent: batteryPercent,
                  speedKmh: speedKmh,
                  timestamp: timestamp,
                  onClose: () => _removeUserOverlay(),
                ),
              ),
            ),
          ],
        );
      });

      Overlay.of(context)!.insert(_userOverlayEntry!);

      // Compute precise position: center-based for current user (after camera move),
      // or marker-screen-coordinate for other users.
      if (isCurrentUser) {
        try {
          await controller.animateCamera(CameraUpdate.newLatLng(location));
        } catch (e) {
          debugPrint('[GpsScreen] animateCamera failed for current user: $e');
        }
        // brief wait for camera/layout to stabilise
        await Future.delayed(const Duration(milliseconds: 250));

        final double centerY = screenH / 2;
        left = ((screenW - cardWidth) / 2 - leftNudge)
            .clamp(8.0, screenW - cardWidth - 8.0);
        top = (centerY - cardHeight - topOffsetFromProfile)
            .clamp(8.0, screenH - cardHeight - 8.0);
      } else {
        try {
          final screenCoord = await controller.getScreenCoordinate(location);
          final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
          final dx = screenCoord.x.toDouble() / devicePixelRatio;
          final dy = screenCoord.y.toDouble() / devicePixelRatio;

          left = (dx - cardWidth / 2 - leftNudge)
              .clamp(8.0, screenW - cardWidth - 8.0);
          top = (dy - cardHeight - topOffsetFromProfile)
              .clamp(8.0, screenH - cardHeight - 8.0);
        } catch (e) {
          debugPrint(
              '[GpsScreen] getScreenCoordinate failed, using fallback: $e');
        }
      }

      // Rebuild overlay so the card moves to the computed coordinates.
      try {
        _userOverlayEntry?.markNeedsBuild();
      } catch (e) {
        debugPrint('[GpsScreen] markNeedsBuild failed: $e');
      }

      // Keep suppression active while the overlay is present; _removeUserOverlay()
      // clears `_suppressMapTapCollapse` and cancels the timer.
    } catch (e, st) {
      debugPrint('[GpsScreen] Error creating overlay: $e\n$st');
      // cleanup on error
      _suppressMapTapCollapse = false;
      _suppressMapTapCollapseTimer?.cancel();
      _suppressMapTapCollapseTimer = null;
      _removeUserOverlay();
    }
  }

  MapPerspective? _mapPerspectiveFromDynamic(dynamic v) {
    if (v == null) return null;
    try {
      if (v is MapPerspective) return v;
      if (v is int) {
        final idx = v.clamp(0, MapPerspective.values.length - 1).toInt();
        return MapPerspective.values[idx];
      }
      if (v is String) {
        final byName = MapPerspective.values.firstWhere(
          (e) => e.toString().split('.').last.toLowerCase() == v.toLowerCase(),
          orElse: () => MapPerspective.classic,
        );
        return byName;
      }
    } catch (_) {}
    return null;
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
        outerSize: 64,
        innerSize: 30,
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
        // Only update circles if PWD markers are currently showing
        if (_showingPwdMarkers) {
          _circles.removeWhere(
              (circle) => circle.circleId.value.startsWith('pwd_'));
          _circles = _circles.union(createPwdfriendlyRouteCircles(locations));
        }
      });
    } catch (e) {
      print('Error updating circles: $e');
    }
  }

  Future<void> _showPwdLocations() async {
    try {
      final locations = await getPwdFriendlyLocations();
      _cachedPwdLocations = locations;

      final markers = await _markerHandler.createMarkers(
          context, locations, _locationHandler.currentLocation);

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
              snippet: 'Tap to show route',
              onTap: () {
                if (_locationHandler.currentLocation != null) {
                  routeController.createRoute(
                    _locationHandler.currentLocation!,
                    marker.position,
                  );
                  routeController.startFollowingUser(
                    () => _locationHandler.currentLocation,
                  );
                }
              },
            ),
            onTap: () async {
              try {
                final doc = await _firestore
                    .collection('pwd_locations')
                    .doc(location["id"])
                    .get();
                if (doc.exists) {
                  final double latitude = MapUtils.parseDouble(doc['latitude']);
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
        // Remove any existing PWD markers first
        _markers
            .removeWhere((marker) => marker.markerId.value.startsWith('pwd_'));
        // Add the new PWD markers
        _markers.addAll(pwdMarkers);

        // Remove any existing PWD circles
        _circles
            .removeWhere((circle) => circle.circleId.value.startsWith('pwd_'));
        // Create and add new PWD circles
        _circles = _circles.union(createPwdfriendlyRouteCircles(locations));

        // Set the state to show PWD markers
        _showingPwdMarkers = true;
      });
    } catch (e) {
      print('Error fetching PWD locations: $e');
      setState(() {
        _showingPwdMarkers = false;
      });
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

    dynamic maybe = args;
    if (args is Map)
      maybe = args['perspective'] ??
          args['perspectiveIndex'] ??
          args['perspectiveName'];
    final maybePerspective = _mapPerspectiveFromDynamic(maybe);
    debugPrint('[GpsScreen] maybePerspective = $maybePerspective');

    if (maybePerspective != null) {
      _pendingPerspective = maybePerspective;
      if (_isLocationFetched && _locationHandler.mapController != null) {
        debugPrint('[GpsScreen] applying pending perspective now');
        applyMapPerspective(_pendingPerspective!);
        _pendingPerspective = null;
      } else {
        debugPrint(
            '[GpsScreen] pending perspective saved for later because map or location not ready');
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
    _pwdNotificationService.stopLocationMonitoring();
    _spaceMemberNotificationService.stopMemberMonitoring();
    _zoomDebounceTimer?.cancel();
    _mapZoomNotifier.dispose();
    _favoriteSheetController.dispose();
    _locationSheetController.dispose();
    _safetySheetController.dispose();

    _removeUserOverlay();
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

  void _handleSpaceIdChanged(String spaceId) async {
    setState(() {
      _activeSpaceId = spaceId;
      _isLoading = true;
    });

    String name = '';
    if (spaceId.isNotEmpty) {
      try {
        final doc = await _firestore.collection('Spaces').doc(spaceId).get();
        if (doc.exists) {
          name = (doc.data() as Map<String, dynamic>)['name']?.toString() ?? '';
        }
      } catch (e) {
        debugPrint('[GpsScreen] _handleSpaceIdChanged failed: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _activeSpaceName = name;
      _isLoading = false;
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
    // If PWD category is selected
    if (placeType == 'PWD') {
      if (_showingPwdMarkers) {
        // Clear PWD markers and circles (toggle off)
        if (!mounted) return;
        setState(() {
          _markers.removeWhere(
              (marker) => marker.markerId.value.startsWith('pwd_'));
          _circles.removeWhere(
              (circle) => circle.circleId.value.startsWith('pwd_'));
          _showingPwdMarkers = false;
        });
      } else {
        // Show PWD markers (toggle on)
        await _showPwdLocations();
        _showingPwdMarkers = true;
      }
      return;
    }

    // If no place type => treat as "toggle off" and remove previously-added nearby markers/circles.
    if (placeType.isEmpty) {
      if (!mounted) return;
      setState(() {
        // Clear all markers except user and place markers
        _markers.removeWhere((m) => !(m.markerId.value.startsWith('user_') ||
            m.markerId.value.startsWith('place_')));

        // Clear all circles
        _circles.clear();

        // Clear computed nearby specs
        _nearbyCircleSpecs = [];

        // Clear route visuals
        _polylines.clear();

        // Also clear PWD markers if they were showing
        _showingPwdMarkers = false;
      });
      return;
    }

    // Clear PWD markers when other categories are selected
    if (_showingPwdMarkers) {
      setState(() {
        _markers
            .removeWhere((marker) => marker.markerId.value.startsWith('pwd_'));
        _circles
            .removeWhere((circle) => circle.circleId.value.startsWith('pwd_'));
        _showingPwdMarkers = false;
      });
    }

    // Original nearby places fetching logic for other categories
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
        // preserve core markers only (pwd_, user_, place_), we'll add new nearby markers
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
        // nothing returned => clear nearby circles (but keep pwd ones)
        setState(() {
          _circles.removeWhere((c) => !c.circleId.value.startsWith('pwd_'));
          _nearbyCircleSpecs = [];
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

  void _onMemberPressed(LatLng location, String userId) async {
    // 1) Pan/center the map and prepare LocationHandler as before
    if (_locationHandler.mapController != null) {
      try {
        await _locationHandler.mapController!.animateCamera(
          CameraUpdate.newLatLng(location),
        );
      } catch (e) {
        debugPrint('_onMemberPressed animateCamera error: $e');
      }

      _locationHandler.selectedUserId = userId;
      _locationHandler.listenForLocationUpdates();
    }

    // 2) Fetch display info for the member (Users collection)
    String username = 'User';
    String profileUrl = '';
    try {
      // Prefer querying by uid field (your Users docs use 'uid' per earlier code)
      final q = await _firestore
          .collection('Users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final data = q.docs.first.data();
        final first = (data['firstName'] ?? '').toString().trim();
        final last = (data['lastName'] ?? '').toString().trim();
        username = (first.isNotEmpty || last.isNotEmpty)
            ? ('$first${first.isNotEmpty && last.isNotEmpty ? ' ' : ''}$last')
                .trim()
            : (data['username']?.toString() ?? 'User');
        profileUrl = data['profilePicture']?.toString() ?? '';
      }
    } catch (e, st) {
      debugPrint('_onMemberPressed: failed to fetch Users doc: $e\n$st');
    }

    // 3) Try to fetch telemetry from UserLocations (battery, speed, timestamp)
    int? batteryPercent;
    double? speedKmh;
    DateTime? timestamp;
    try {
      final locSnap =
          await _firestore.collection('UserLocations').doc(userId).get();
      if (locSnap.exists) {
        final ld = locSnap.data();
        if (ld != null) {
          // batteryPercent may be stored as int or string — try both
          final bp = ld['batteryPercent'];
          if (bp is int)
            batteryPercent = bp;
          else if (bp is String)
            batteryPercent = int.tryParse(bp) ?? batteryPercent;

          // speed may be stored as number or string
          try {
            speedKmh = MapUtils.parseDouble(ld['speedKmh']);
          } catch (_) {}

          final rawTs = ld['timestamp'];
          if (rawTs is Timestamp)
            timestamp = rawTs.toDate();
          else if (rawTs is int)
            timestamp = DateTime.fromMillisecondsSinceEpoch(rawTs);
          else if (rawTs is String) {
            final ms = int.tryParse(rawTs);
            if (ms != null) timestamp = DateTime.fromMillisecondsSinceEpoch(ms);
          }
        }
      }
    } catch (e, st) {
      debugPrint('_onMemberPressed: failed to fetch UserLocations: $e\n$st');
    }

    // 4) Resolve a friendly address for the tapped location (best-effort)
    String address = 'Location';
    try {
      address = await _getLocationName(location);
    } catch (e) {
      debugPrint('_onMemberPressed: _getLocationName failed: $e');
    }

    // 5) Compute distance in meters relative to current user location (if available)
    double distanceMeters = 0.0;
    try {
      if (_locationHandler.currentLocation != null) {
        distanceMeters = MapUtils.calculateDistanceKm(
                _locationHandler.currentLocation!, location) *
            1000.0;
      }
    } catch (e) {
      debugPrint('_onMemberPressed: distance calc failed: $e');
    }

    // 6) Finally show the overlay
    try {
      await _showUserOverlay(
        userId: userId,
        username: username,
        location: location,
        address: address,
        profileUrl: profileUrl,
        distanceMeters: distanceMeters,
        batteryPercent: batteryPercent,
        speedKmh: speedKmh,
        timestamp: timestamp,
      );
    } catch (e, st) {
      debugPrint('_onMemberPressed: _showUserOverlay failed: $e\n$st');
    }
  }

  void _onMySpaceSelected() {
    setState(() {
      _locationHandler.activeSpaceId = '';
    });
    _locationHandler.updateActiveSpaceId('');
  }

  Future<void> applyMapPerspective(MapPerspective perspective) async {
    if (_isApplyingPerspective) {
      debugPrint('[GpsScreen] applyMapPerspective ignored — already applying');
      return;
    }
    _isApplyingPerspective = true;

    debugPrint('[GpsScreen] applyMapPerspective called with -> $perspective');

    final currentLatLng =
        _locationHandler.currentLocation ?? const LatLng(16.0430, 120.3333);
    final newMapType = MapPerspectiveUtils.mapTypeFor(perspective);
    final newPosition =
        MapPerspectiveUtils.cameraPositionFor(perspective, currentLatLng);

    debugPrint(
        '[GpsScreen] will set mapType=$_currentMapType -> newMapType=$newMapType');
    debugPrint(
        '[GpsScreen] newCameraPosition: zoom=${newPosition.zoom}, tilt=${newPosition.tilt}, bearing=${newPosition.bearing}');

    // Update mapType immediately (no key recreation)
    setState(() {
      _currentMapType = newMapType;
    });

    // Try immediate camera update if controller is available
    final controller = _locationHandler.mapController;
    if (controller != null) {
      try {
        // Use moveCamera for instant jump; switch to animateCamera if you prefer animation
        await controller
            .moveCamera(CameraUpdate.newCameraPosition(newPosition));
        debugPrint('[GpsScreen] camera moved to perspective $perspective');
      } catch (e, st) {
        debugPrint('[GpsScreen] moveCamera error: $e\n$st');
      } finally {
        _isApplyingPerspective = false;
      }
      return;
    }

    // If controller is null, store the pending perspective so _onMapCreated can apply it later.
    debugPrint(
        '[GpsScreen] mapController is null — saving pending perspective for later');
    _pendingPerspective = perspective;

    // Optional: wait a short time for controller then try again (non-blocking)
    // (we attempt a short poll so users who quickly open settings then return still see it)
    const waitTimeout = Duration(seconds: 3);
    final deadline = DateTime.now().add(waitTimeout);
    while (_locationHandler.mapController == null &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    final lateController = _locationHandler.mapController;
    if (lateController != null) {
      try {
        await lateController
            .moveCamera(CameraUpdate.newCameraPosition(newPosition));
        debugPrint(
            '[GpsScreen] late camera move applied after controller became ready');
        _pendingPerspective = null;
      } catch (e, st) {
        debugPrint('[GpsScreen] late moveCamera error: $e\n$st');
      }
    } else {
      debugPrint(
          '[GpsScreen] controller still null after waiting — pending kept');
    }

    _isApplyingPerspective = false;
  }

  String _mapTypeName(MapPerspective p) {
    switch (p) {
      case MapPerspective.aerial:
        return 'satellite';
      case MapPerspective.terrain:
        return 'terrain';
      case MapPerspective.street:
        return 'hybrid';
      case MapPerspective.perspective:
        // static maps can't tilt — satellite is the closest
        return 'satellite';
      case MapPerspective.classic:
      default:
        return 'roadmap';
    }
  }

  String? _staticMapUrlFor(MapPerspective p) {
    // use the API key already in your state
    if (_googleAPIKey.isEmpty) return null;

    final lat = _locationHandler.currentLocation?.latitude ?? 16.0430;
    final lng = _locationHandler.currentLocation?.longitude ?? 120.3333;
    final center = '$lat,$lng';
    final mapType = _mapTypeName(p);
    final size = '300x300';
    final zoom = (p == MapPerspective.street || p == MapPerspective.perspective)
        ? '17'
        : '14';

    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$center&zoom=$zoom&size=$size&scale=2&maptype=$mapType&key=$_googleAPIKey';
  }

  Future<void> _openMapSettings() async {
    debugPrint('[GpsScreen] _openMapSettings -> showing bottom sheet');
    final urls = [
      _staticMapUrlFor(MapPerspective.classic),
      _staticMapUrlFor(MapPerspective.aerial),
      _staticMapUrlFor(MapPerspective.street),
      _staticMapUrlFor(MapPerspective.perspective),
    ].whereType<String>().toList();

// prefetch (fire-and-forget)
    for (final url in urls) {
      try {
        precacheImage(NetworkImage(url), context);
      } catch (e) {
        debugPrint('precache failed: $e');
      }
    }
    try {
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        useRootNavigator: true, // <- add this

        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Container(
            decoration: BoxDecoration(
              color:
                  Provider.of<ThemeProvider>(context, listen: false).isDarkMode
                      ? Colors.grey[900]
                      : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            // pass the currently pending or default perspective if you want initial highlight
            child: MapPerspectivePicker(
              initialPerspective: _pendingPerspective ?? MapPerspective.classic,
              currentLocation: _locationHandler.currentLocation,
            ),
          );
        },
      );

      debugPrint('[GpsScreen] bottom sheet returned -> $result');

      // `MapPerspectivePicker` returns {'perspectiveName': 'classic'} (string)
      dynamic dyn = result;
      if (result is Map<String, dynamic>) {
        dyn = result['perspective'] ??
            result['perspectiveIndex'] ??
            result['perspectiveName'];
      }

      final perspective = _mapPerspectiveFromDynamic(dyn);
      if (perspective != null) {
        debugPrint('[GpsScreen] parsed perspective -> $perspective');
        await applyMapPerspective(perspective);
      } else {
        debugPrint(
            '[GpsScreen] no valid perspective returned from bottom sheet');
      }
    } catch (e, st) {
      debugPrint('[GpsScreen] _openMapSettings bottom sheet error: $e\n$st');
    }
  }

  void _onMapCreated(GoogleMapController controller, bool isDarkMode) {
    _locationHandler.onMapCreated(controller, isDarkMode);

    if (_isLocationFetched && _locationHandler.currentLocation != null) {
      controller.animateCamera(
        CameraUpdate.newLatLng(_locationHandler.currentLocation!),
      );
    }

    // If a perspective was requested earlier while the controller was unavailable,
    // apply it now.
    if (_pendingPerspective != null) {
      // apply without awaiting so map creation finishes and UI stays responsive
      final pending = _pendingPerspective;
      _pendingPerspective = null;
      if (pending != null) {
        debugPrint(
            '[GpsScreen] applying pending perspective from _onMapCreated -> $pending');
        // call but don't await — applyMapPerspective will check controller existence
        applyMapPerspective(pending);
      }
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
          .createMarkers(context, locations, _locationHandler.currentLocation)
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
                snippet: 'Tap to show route',
                onTap: () {
                  if (_locationHandler.currentLocation != null) {
                    routeController.createRoute(
                      _locationHandler.currentLocation!,
                      marker.position,
                    );
                    routeController.startFollowingUser(
                      () => _locationHandler.currentLocation,
                    );
                  }
                },
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
          _markers.removeWhere(
              (marker) => marker.markerId.value.startsWith('pwd_'));
          _markers.addAll(pwdMarkers);
          _circles.removeWhere(
              (circle) => circle.circleId.value.startsWith('pwd_'));
          _circles = createPwdfriendlyRouteCircles(locations);
          _showingPwdMarkers = true;
        });
      });
    } catch (e) {
      print('Error fetching PWD locations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
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

                          Set<Circle> pwdSet = {};
                          // Only create PWD circles if they should be showing
                          if (_showingPwdMarkers) {
                            pwdSet = createPwdfriendlyRouteCircles(
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
                          }

                          final nearbySet = _computeNearbyCirclesFromRaw();
                          setState(() {
                            _circles = pwdSet.union(nearbySet);
                          });
                        });
                      },
                      onMapCreated: (controller) =>
                          _onMapCreated(controller, isDarkMode),
                      onTap: (latlng) async {
                        if (_suppressMapTapCollapse) {
                          debugPrint(
                              '[GpsScreen] map onTap suppressed because overlay is visible');
                          // optional: still clear selectedPlace / remove overlay? we keep overlay until user closes it
                          return;
                        }
                        setState(() => _selectedPlace = null);
                        _removeUserOverlay(); // hide card when map tapped

                        // collapse all relevant sheets safely
                        try {
                          const double favoriteMin =
                              0.10; // FavoriteWidget minChildSize
                          const double locationMin =
                              0.10; // LocationWidgets minChildSize
                          const double safetyMin =
                              0.10; // SafetyAssistWidget minChildSize

                          // Fav
                          try {
                            final favCur = _favoriteSheetController.size;
                            if (favCur > favoriteMin + 0.01) {
                              await _favoriteSheetController.animateTo(
                                favoriteMin,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOut,
                              );
                            }
                          } catch (e) {
                            debugPrint('fav collapse error: $e');
                          }

                          // Location
                          try {
                            final locCur = _locationSheetController.size;
                            if (locCur > locationMin + 0.01) {
                              await _locationSheetController.animateTo(
                                locationMin,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOut,
                              );
                            }
                          } catch (e) {
                            debugPrint('location collapse error: $e');
                          }

                          // Safety
                          try {
                            final safetyCur = _safetySheetController.size;
                            if (safetyCur > safetyMin + 0.01) {
                              await _safetySheetController.animateTo(
                                safetyMin,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOut,
                              );
                            }
                          } catch (e) {
                            debugPrint('safety collapse error: $e');
                          }
                        } catch (e) {
                          debugPrint('Error collapsing sheets: $e');
                        }
                      },
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
                        child: NavigationControls(
                          isWheelchair: _isWheelchairFriendlyRoute,
                          isRouted: _isRouteActive,
                          onReset: _resetCameraToNormal,
                          onToggleFollow: _toggleNavigationMode,
                          onToggleWheelchair: _toggleWheelchairFriendlyRoute,
                          isFollowing: _routeUpdateTimer != null,
                        ),
                      ),

                    if (_isRerouting)
                      Positioned(
                        top: screenHeight * 0.17,
                        left: 0,
                        right: 0,
                        child: const Center(child: ReroutingBanner()),
                      ),

                    // Navigation Info Panel
                    if (_isRouteActive &&
                        routeController.routeDestination != null)
                      Positioned(
                        bottom: screenHeight * _initialNavigationPanelBottom +
                            _navigationPanelOffset,
                        left: 20,
                        right: 20,
                        child: NavigationInfoPanel(
                          bottomOffset:
                              screenHeight * _initialNavigationPanelBottom +
                                  _navigationPanelOffset,
                          isWheelchair: _isWheelchairFriendlyRoute,
                          // Provide closures so the panel can fetch data when it builds.
                          getDestinationName: () => _getLocationName(
                            routeController.routeDestination ??
                                _locationHandler.currentLocation!,
                          ),
                          getRemainingKm: () async =>
                              routeController.calculateRemainingDistanceKm(
                            fromLocation: _locationHandler.currentLocation,
                          ),
                          onDragUpdate: (delta) {
                            setState(() {
                              _navigationPanelOffset =
                                  (_navigationPanelOffset - delta).clamp(
                                      -screenHeight * 0.3, screenHeight * 0.3);
                            });
                          },
                          onDragReset: () {
                            if (_navigationPanelOffset.abs() < 20) {
                              setState(() => _navigationPanelOffset = 0.0);
                            }
                          },
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
                      onSpaceSelected: (String id, String name) async {
                        setState(() {
                          _activeSpaceId = id;
                          _activeSpaceName = name;
                          _isLoading = false;
                        });
                        _locationHandler.updateActiveSpaceId(id);

                        _spaceMemberNotificationService.updateActiveSpace(id);

                        // persist selection so next app start restores it
                        await _saveActiveSpaceToPrefs(id);
                      },
                      onMySpaceSelected: () {
                        // clear name as well
                        setState(() {
                          _locationHandler.updateActiveSpaceId('');
                          _activeSpaceId = '';
                          _activeSpaceName = ''; // <-- important
                          _isLoading = false;
                        });

                        _spaceMemberNotificationService.updateActiveSpace('');
                        // clear saved pref so next launch auto-selects first available space again
                        _saveActiveSpaceToPrefs('');
                      },
                      onSpaceIdChanged: _handleSpaceIdChanged,
                    ),
                    if (_locationHandler.currentIndex == 0)
                      LocationWidgets(
                        key: ValueKey(_activeSpaceId),
                        activeSpaceId: _activeSpaceId,
                        overlayVisibleNotifier:
                            _userOverlayVisible, // <-- ADD THIS

                        onCategorySelected: (LatLng location) {
                          _locationHandler.panCameraToLocation(location);
                        },
                        onMapViewPressed: () async {
                          debugPrint(
                              '[GpsScreen] onMapViewPressed closure called');
                          await _openMapSettings();
                        },
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
                        controller: _locationSheetController, // <-- add this
                        onShowMyInfoPressed: () async {
                          final currentUid = userState.user.uid;
                          final username = [
                            userState.user.firstName,
                            userState.user.lastName
                          ]
                              .where((s) => s != null && s!.trim().isNotEmpty)
                              .join(' ')
                              .trim();
                          final displayName = username.isNotEmpty
                              ? username
                              : (userState.user.username ?? 'You');
                          final profileUrl =
                              userState.user.profilePicture ?? '';
                          final location = _locationHandler.currentLocation;

                          if (location == null) {
                            // Nothing we can show — optionally center map or show snackbar
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('locationNotAvailable'.tr())),
                            );
                            return;
                          }

                          // Optionally fetch a friendly address for the user's location
                          String address = 'Current Location';
                          try {
                            address = await _getLocationName(location);
                          } catch (e) {
                            debugPrint(
                                'Failed to fetch address for overlay: $e');
                          }

                          // distance = 0 for self; telemetry fields optional
                          await _showUserOverlay(
                            userId: currentUid,
                            username: displayName,
                            location: location,
                            address: address,
                            profileUrl: profileUrl,
                            distanceMeters: 0.0,
                            batteryPercent: null,
                            speedKmh: null,
                            timestamp: DateTime.now(),
                          );
                        },
                      ),
                    if (_locationHandler.currentIndex == 1)
                      FavoriteWidget(
                        controller: _favoriteSheetController, // << add this
                        currentLocation: _locationHandler.currentLocation,
                        onMapViewPressed: () async {
                          // open map settings (reuse your existing helper)
                          await _openMapSettings();
                        },
                        onCenterPressed: () {
                          // pan/center the map on the user's location
                          final loc = _locationHandler.currentLocation;
                          if (loc != null) {
                            // either use handler pan helper...
                            _locationHandler.panCameraToLocation(loc);
                            // ...or animate via controller:
                            // _locationHandler.mapController?.animateCamera(CameraUpdate.newLatLng(loc));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('locationNotAvailable'.tr())),
                            );
                          }
                        },
                        onServiceButtonPressed: (label) {
                          // forward service button presses (e.g. category string) to your nearby search
                          _fetchNearbyPlaces(label);
                        },
                        onShowPlace: (Place place) {
                          if (_locationHandler.mapController != null) {
                            _locationHandler.mapController!.animateCamera(
                              CameraUpdate.newLatLng(
                                  LatLng(place.latitude, place.longitude)),
                            );
                          }
                        },
                        onPlaceAdded: () {
                          // optional: refresh UI or re-fetch places
                          context
                              .read<PlaceBloc>()
                              .add(const GetAllPlacesEvent());
                        },
                        onShowMyInfoPressed: () async {
                          final currentUid = userState.user.uid;
                          final username = [
                            userState.user.firstName,
                            userState.user.lastName
                          ]
                              .where((s) => s != null && s!.trim().isNotEmpty)
                              .join(' ')
                              .trim();
                          final displayName = username.isNotEmpty
                              ? username
                              : (userState.user.username ?? 'You');
                          final profileUrl =
                              userState.user.profilePicture ?? '';
                          final location = _locationHandler.currentLocation;

                          if (location == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('locationNotAvailable'.tr())),
                            );
                            return;
                          }

                          String address = 'Current Location';
                          try {
                            address = await _getLocationName(location);
                          } catch (e) {
                            debugPrint(
                                'Failed to fetch address for overlay: $e');
                          }

                          await _showUserOverlay(
                            userId: currentUid,
                            username: displayName,
                            location: location,
                            address: address,
                            profileUrl: profileUrl,
                            distanceMeters: 0.0,
                            batteryPercent: null,
                            speedKmh: null,
                            timestamp: DateTime.now(),
                          );
                        },
                      ),
// inside GpsScreen build where you show the sheet
                    if (_locationHandler.currentIndex == 2)
                      SafetyAssistWidget(
                        uid: userState.user.uid,
                        // give it the current location so ServiceButtons shows enabled state & can use it
                        currentLocation: _locationHandler.currentLocation,
                        // pass the LocationHandler instance so the widget can call panCameraToLocation directly
                        locationHandler: _locationHandler,
                        // optional: allow SafetyAssist to open map settings via your existing helper
                        onMapViewPressed: () async {
                          await _openMapSettings();
                        },
                        onShowMyInfoPressed: () async {
                          final currentUid = userState.user.uid;
                          final username = [
                            userState.user.firstName,
                            userState.user.lastName
                          ]
                              .where((s) => s != null && s!.trim().isNotEmpty)
                              .join(' ')
                              .trim();
                          final displayName = username.isNotEmpty
                              ? username
                              : (userState.user.username ?? 'You');
                          final profileUrl =
                              userState.user.profilePicture ?? '';
                          final location = _locationHandler.currentLocation;

                          if (location == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('locationNotAvailable'.tr())),
                            );
                            return;
                          }

                          // Optionally fetch a friendly address for the user's location
                          String address = 'Current Location';
                          try {
                            address = await _getLocationName(location);
                          } catch (e) {
                            debugPrint(
                                'Failed to fetch address for overlay: $e');
                          }

                          await _showUserOverlay(
                            userId: currentUid,
                            username: displayName,
                            location: location,
                            address: address,
                            profileUrl: profileUrl,
                            distanceMeters: 0.0,
                            batteryPercent: null,
                            speedKmh: null,
                            timestamp: DateTime.now(),
                          );
                        },
                        // explicit center handler — safer because you control null-check and any animation
                        onCenterPressed: () {
                          final loc = _locationHandler.currentLocation;
                          if (loc != null) {
                            try {
                              _locationHandler.panCameraToLocation(loc);
                              debugPrint(
                                  '[GpsScreen] SafetyAssist center pressed -> panned to $loc');
                            } catch (e, st) {
                              debugPrint(
                                  '[GpsScreen] panCameraToLocation failed: $e\n$st');
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('locationNotAvailable'.tr())),
                            );
                          }
                        },
                        // forward service button presses to your nearby search (optional, useful)
                        onServiceButtonPressed: (label) {
                          debugPrint(
                              '[GpsScreen] SafetyAssist service button: $label');
                          _fetchNearbyPlaces(label);
                        },
                        // optional: override emergency action (if you want custom behavior)
                        onEmergencyServicePressed: (label, number) {
                          if (number != null && number.isNotEmpty) {
                            // reuse your existing phone launcher logic
                            _launchCaller(
                                number); // make this helper available in GpsScreen or call directly
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('no_number_available'.tr())));
                          }
                        },
                        controller:
                            _safetySheetController, // <-- pass controller
                      ),
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
