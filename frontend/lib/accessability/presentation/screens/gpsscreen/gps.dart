import 'dart:convert'; // For JSON decoding.
import 'package:http/http.dart' as http; // For HTTP requests.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:AccessAbility/accessability/presentation/widgets/google_helper/google_place_helper.dart';
import 'package:AccessAbility/accessability/presentation/widgets/google_helper/map_view_screen.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/top_widgets.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_state.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/marker_handler.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/nearby_places_handler.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/tutorial_widget.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottom_widgets.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/favorite_widget.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/safety_assist_widget.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_state.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_state.dart'
    as placeState;
import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';

class GpsScreen extends StatefulWidget {
  const GpsScreen({super.key});

  @override
  _GpsScreenState createState() => _GpsScreenState();
}

class _GpsScreenState extends State<GpsScreen> {
  late LocationHandler _locationHandler;
  final MarkerHandler _markerHandler = MarkerHandler();
  final NearbyPlacesHandler _nearbyPlacesHandler = NearbyPlacesHandler();
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

  MapType _currentMapType = MapType.normal;
  MapPerspective? _pendingPerspective; // New field

  // Variables for polylines.
  Set<Polyline> _polylines = {};
  final PolylinePoints _polylinePoints = PolylinePoints();
  final String _googleAPIKey = dotenv.env['GOOGLE_API_KEY'] ?? '';

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

    // Create markers for PWD-friendly locations.
    // Modify each marker so that tapping it creates a route.
    _markerHandler.createMarkers(pwdFriendlyLocations).then((markers) {
      final pwdMarkers = markers.map((marker) {
        if (marker.markerId.value.startsWith('pwd_')) {
          return Marker(
            markerId: marker.markerId,
            position: marker.position,
            icon: marker.icon,
            infoWindow: marker.infoWindow,
            onTap: () async {
              // When a PWD-friendly marker is tapped, create a route from the user's current location to the marker.
              if (_locationHandler.currentLocation != null) {
                await _createRoute(
                  _locationHandler.currentLocation!,
                  marker.position,
                );
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
    _markerHandler.createMarkers(pwdFriendlyLocations).then((markers) {
      setState(() {
        _markers.addAll(markers);
      });
    });
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
      print("🚨 Current position is null, cannot fetch nearby places.");
      return;
    }
    final result = await _nearbyPlacesHandler.fetchNearbyPlaces(
      placeType,
      _locationHandler.currentLocation!,
    );
    setState(() {
      _markers
          .removeWhere((marker) => marker.markerId.value.startsWith("place_"));
      _circles.clear();
    });
    if (result.isNotEmpty) {
      final Set<Marker> originalNearbyMarkers = result["markers"];
      final Set<Circle> nearbyCircles = result["circles"];

      final Set<Marker> nearbyMarkers = originalNearbyMarkers.map((marker) {
        return Marker(
          markerId: marker.markerId,
          position: marker.position,
          icon: marker.icon,
          infoWindow: marker.infoWindow,
          onTap: () async {
            final googlePlacesHelper = GooglePlacesHelper();
            try {
              final detailedPlace = await googlePlacesHelper.fetchPlaceDetails(
                marker.markerId.value,
                marker.infoWindow.title ?? 'unknownPlace'.tr(),
              );
              setState(() {
                _selectedPlace = detailedPlace;
                _polylines.clear();
              });
              if (_locationHandler.currentLocation != null) {
                await _createRoute(
                  _locationHandler.currentLocation!,
                  marker.position,
                );
              }
            } catch (e) {
              print("Error fetching detailed place info: $e");
            }
          },
        );
      }).toSet();

      // Retain existing markers (PWD and user markers).
      final existingMarkers = _markers
          .where((marker) =>
              marker.markerId.value.startsWith("pwd_") ||
              marker.markerId.value.startsWith("user_"))
          .toSet();
      final updatedMarkers = existingMarkers.union(nearbyMarkers);
      setState(() {
        _markers = updatedMarkers;
        _circles = nearbyCircles;
      });
      if (_locationHandler.mapController != null && updatedMarkers.isNotEmpty) {
        final bounds = _locationHandler.getLatLngBounds(
          updatedMarkers.map((marker) => marker.position).toList(),
        );
        _locationHandler.mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _locationHandler.currentLocation!,
              zoom: 14.5,
            ),
          ),
        );
        print("🎯 Adjusted camera to fit ${updatedMarkers.length} markers.");
      } else {
        print("⚠️ No bounds to adjust camera.");
      }
    } else {
      print("No nearby results for $placeType. Cleared previous markers.");
    }
  }

  /// Create a route using Google Routes API from [origin] to [destination]
  /// and display it on the map.
  Future<void> _createRoute(LatLng origin, LatLng destination) async {
    final String url =
        "https://routes.googleapis.com/directions/v2:computeRoutes?key=$_googleAPIKey";

    final Map<String, dynamic> requestBody = {
      "origin": {
        "location": {
          "latLng": {
            "latitude": origin.latitude,
            "longitude": origin.longitude,
          }
        }
      },
      "destination": {
        "location": {
          "latLng": {
            "latitude": destination.latitude,
            "longitude": destination.longitude,
          }
        }
      },
      "travelMode": "DRIVE",
      "routingPreference": "TRAFFIC_AWARE",
    };

    final String body = jsonEncode(requestBody);
    print("Requesting URL: $url");
    print("Request Body: $body");

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        // Include the FieldMask header as required.
        "X-Goog-FieldMask":
            "routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline",
      },
      body: body,
    );
    print("Response: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final String encodedPolyline =
            data['routes'][0]['polyline']['encodedPolyline'];
        final List<PointLatLng> result =
            _polylinePoints.decodePolyline(encodedPolyline);
        final List<LatLng> polylineCoordinates = result
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        setState(() {
          _polylines.clear(); // Clear previous routes.
          _polylines.add(Polyline(
            polylineId: const PolylineId("route"),
            color: const Color(0xFF6750A4),
            width: 6,
            points: polylineCoordinates,
          ));
        });
      } else {
        print("No routes found");
      }
    } else {
      print("Error fetching directions: ${response.statusCode}");
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

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    _mapKey = ValueKey(isDarkMode);

    return BlocListener<PlaceBloc, placeState.PlaceState>(
      listener: (context, state) {
        if (state is placeState.PlacesLoaded) {
          // Create markers for every place from PlaceBloc.
          Set<Marker> placeMarkers = {};
          for (Place place in state.places) {
            Marker marker = Marker(
              markerId: MarkerId('place_${place.id}'),
              position: LatLng(place.latitude, place.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(256.43),
              infoWindow: InfoWindow(
                title: place.name,
                snippet: '${'category'.tr()}: ${place.category}',
              ),
              onTap: () async {
                if (place.placeId != null && place.placeId!.isNotEmpty) {
                  try {
                    final googlePlacesHelper = GooglePlacesHelper();
                    final detailedPlace =
                        await googlePlacesHelper.fetchPlaceDetails(
                      place.placeId!,
                      place.name,
                    );
                    setState(() {
                      _selectedPlace = detailedPlace;
                    });
                  } catch (e) {
                    print('Error fetching place details: $e');
                  }
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
        } else if (state is placeState.PlaceOperationError) {
          print("Error loading places: ${state.message}");
        }
      },
      child: BlocBuilder<UserBloc, UserState>(
        builder: (context, userState) {
          if (userState is UserInitial || userState is UserLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (userState is UserError) {
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
          } else if (userState is UserLoaded) {
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
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      mapType: _currentMapType,
                      markers: _markers,
                      circles: _circles,
                      polylines: _polylines, // Display the route polyline.
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
                      polygons:
                          _markerHandler.createPolygons(pwdFriendlyLocations),
                      onTap: (LatLng position) {
                        setState(() {
                          _selectedPlace = null;
                        });
                      },
                    ),
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
                      BottomWidgets(
                        key: ValueKey(_locationHandler.activeSpaceId),
                        scrollController: ScrollController(),
                        activeSpaceId: _locationHandler.activeSpaceId,
                        onCategorySelected: (LatLng location) {
                          _locationHandler.panCameraToLocation(location);
                        },
                        onMapViewPressed: _openMapSettings,
                        onMemberPressed: _onMemberPressed,
                        selectedPlace: _selectedPlace,
                        onCloseSelectedPlace: () {
                          setState(() {
                            _selectedPlace = null;
                          });
                        },
                        fetchNearbyPlaces: _fetchNearbyPlaces,
                        onPlaceSelected: _updateMapLocation,
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
