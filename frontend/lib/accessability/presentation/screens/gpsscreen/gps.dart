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
import 'package:AccessAbility/accessability/presentation/widgets/google_helper/openstreetmap_helper.dart';
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
      print("Current location is null - cannot fetch places");
      return;
    }

    print("Fetching nearby $placeType places...");

    // First, return camera to user's location
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

        // Clear only previous nearby search markers (from top widgets)
        // Keep: pwd_ markers, user_ markers, and place_ markers (user-added)
        final existingMarkers = _markers
            .where((marker) =>
                marker.markerId.value.startsWith("pwd_") ||
                marker.markerId.value.startsWith("user_") ||
                marker.markerId.value.startsWith("place_"))
            .toSet();

        final Set<Marker> newMarkers = {};

        // Process new markers - ensure we're working with a Set
        if (result['markers'] != null) {
          final markersSet = result['markers'] is Set
              ? result['markers']
              : Set<Marker>.from(result['markers']);
          for (final marker in markersSet) {
            print("Adding marker: ${marker.markerId} at ${marker.position}");
            newMarkers.add(Marker(
              markerId: marker.markerId,
              position: marker.position,
              icon: marker.icon,
              infoWindow: marker.infoWindow,
              onTap: () async {
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
                  if (_locationHandler.currentLocation != null) {
                    await _createRoute(
                      _locationHandler.currentLocation!,
                      marker.position,
                    );
                  }
                } catch (e) {
                  print("Error fetching place details: $e");
                }
              },
            ));
          }
        }

        // Handle circles - convert to Set if needed
        Set<Circle> newCircles = {};
        if (result['circles'] != null) {
          newCircles = result['circles'] is Set<Circle>
              ? result['circles']
              : Set<Circle>.from(result['circles']);
        }

        setState(() {
          _markers = existingMarkers.union(newMarkers);
          _circles = newCircles;
          _polylines.clear();
        });

        print("Total markers after update: ${_markers.length}");
        print("Total circles after update: ${_circles.length}");

        // Adjust view to show all markers
        if (_markers.isNotEmpty && _locationHandler.mapController != null) {
          final bounds = _locationHandler.getLatLngBounds(
            _markers.map((m) => m.position).toList(),
          );
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
        // Only clear circles, keep all markers
        setState(() {
          _circles.clear();
        });
      }
    } catch (e) {
      print("Error fetching nearby places: $e");
      if (e is TypeError) {
        print("Type error details: ${e.toString()}");
      }
    }
  }

  /// Create a route using Google Routes API from [origin] to [destination]
  /// and display it on the map.
  Future<void> _createRoute(LatLng origin, LatLng destination) async {
    try {
      final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}?overview=full&geometries=geojson');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final geometry = data['routes'][0]['geometry']['coordinates'];

        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: geometry
                  .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
                  .toList(),
              color: const Color(0xFF6750A4),
              width: 6,
            ),
          };
        });
      }
    } catch (e) {
      print('Routing failed: $e');
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
                try {
                  final openStreetMapHelper = OpenStreetMapHelper();
                  final detailedPlace =
                      await openStreetMapHelper.fetchPlaceDetails(
                    place.latitude, // Use the place's existing coordinates
                    place.longitude,
                    place.name, // Fallback name
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
                      // ———— DISABLE ALL THE CONTROLS ————
                      zoomControlsEnabled: false, // hides the + / – buttons
                      zoomGesturesEnabled:
                          true, // (optional) disables pinch‐to‐zoom
                      myLocationButtonEnabled:
                          false, // hides the blue “you are here” button
                      compassEnabled: false, // hides the compass icon
                      mapToolbarEnabled: false, // hides the Google Maps toolbar
                      // ——————————————————————————
                      myLocationEnabled: true,
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
