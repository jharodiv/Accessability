import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_event.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/pwd_friendly_locations.dart';
import 'package:AccessAbility/accessability/presentation/widgets/accessability_footer.dart';
import 'package:AccessAbility/accessability/presentation/widgets/google_helper/google_place_helper.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/top_widgets.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
import 'package:provider/provider.dart';

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

  // Added: Holds the detailed info for a selected establishment.
  Place? _selectedPlace;

  @override
  void initState() {
    super.initState();
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
    });

    // Create markers for PWD-friendly locations.
    _markerHandler.createMarkers(pwdFriendlyLocations).then((markers) {
      setState(() {
        _markers.addAll(markers);
      });
    });

    // Check if onboarding is completed before showing the tutorial.
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
  void dispose() {
    _locationHandler.disposeHandler();
    super.dispose();
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
        final Set<Marker> nearbyMarkers = result["markers"];
        final Set<Circle> nearbyCircles = result["circles"];
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
          _locationHandler.mapController!
              .animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
          print("🎯 Adjusted camera to fit ${updatedMarkers.length} markers.");
        } else {
          print("⚠️ No bounds to adjust camera.");
        }
      } else {
        print("No nearby results for $placeType. Cleared previous markers.");
      }
    }

  void _onMemberPressed(LatLng location, String userId) {
    if (_locationHandler.mapController != null) {
      _locationHandler.mapController!.animateCamera(
        CameraUpdate.newLatLng(location),
      );
      // Trigger marker selection
      _locationHandler.selectedUserId = userId;
      _locationHandler.listenForLocationUpdates();
    }
  }

  void _onMySpaceSelected() {
    setState(() {
      _locationHandler.activeSpaceId = '';
    });
    _locationHandler.updateActiveSpaceId(''); // Explicitly cancel listeners
  }

  @override
Widget build(BuildContext context) {
  final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
  _mapKey = ValueKey(isDarkMode);

  return BlocListener<PlaceBloc, placeState.PlaceState>(
    listener: (context, state) {
      if (state is placeState.PlacesLoaded) {
        // Create markers for every place.
        Set<Marker> placeMarkers = {};
        for (Place place in state.places) {
          Marker marker = Marker(
            markerId: MarkerId('place_${place.id}'),
            position: LatLng(place.latitude, place.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(256.43),
            infoWindow: InfoWindow(
              title: place.name,
              snippet: 'Category: ${place.category}',
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
                Text('Error: ${userState.message}'),
                ElevatedButton(
                  onPressed: () {
                    context.read<UserBloc>().add(FetchUserData());
                  },
                  child: const Text('Retry'),
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
                    markers: _markers,
                    circles: _circles,
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
                  ),
                  if (_locationHandler.currentIndex == 0)
                    BottomWidgets(
                      key: ValueKey(_locationHandler.activeSpaceId),
                      scrollController: ScrollController(),
                      activeSpaceId: _locationHandler.activeSpaceId,
                      onCategorySelected: (LatLng location) {
                        _locationHandler.panCameraToLocation(location);
                      },
                      onMemberPressed: _onMemberPressed,
                      selectedPlace: _selectedPlace,
                      onCloseSelectedPlace: () {
                        setState(() {
                          _selectedPlace = null;
                        });
                      },
                      fetchNearbyPlaces: _fetchNearbyPlaces
                    ),
                  if (_locationHandler.currentIndex == 1)
                    const FavoriteWidget(),
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
          return const Center(child: Text('No user data available'));
        }
      },
    ),
  );
}
}
