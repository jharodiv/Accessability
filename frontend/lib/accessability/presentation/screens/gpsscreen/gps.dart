import 'package:AccessAbility/accessability/logic/bloc/user/user_event.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/pwd_friendly_locations.dart';
import 'package:AccessAbility/accessability/presentation/widgets/accessability_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_state.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/marker_handler.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/nearby_places_handler.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/tutorial_widget.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottom_widgets.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepagewidgets/top_widgets.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/favorite_widget.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/safety_assist_widget.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_state.dart';

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
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();

    // Initialize _tutorialWidget with keys
    _tutorialWidget = TutorialWidget(
      inboxKey: inboxKey,
      settingsKey: settingsKey,
      youKey: youKey,
      locationKey: locationKey,
      securityKey: securityKey,
    );

    // Initialize LocationHandler
    _locationHandler = LocationHandler(
      onMarkersUpdated: (markers) {
        setState(() {
          _markers = markers;
        });
      },
    );

    // Get user location
    _locationHandler.getUserLocation();

    // Create markers for PWD-friendly locations
    _markerHandler.createMarkers(pwdFriendlyLocations).then((markers) {
      setState(() {
        _markers.addAll(markers);
      });
    });

    // Check if onboarding is completed before showing the tutorial
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

  Future<void> _fetchNearbyPlaces(String placeType) async {
    if (_locationHandler.currentLocation == null) {
      print("🚨 Current position is null, cannot fetch nearby places.");
      return;
    }

    final result = await _nearbyPlacesHandler.fetchNearbyPlaces(
      placeType,
      _locationHandler.currentLocation!,
    );

    if (result.isNotEmpty) {
      final Set<Marker> nearbyMarkers = result["markers"];
      final Set<Circle> nearbyCircles = result["circles"];

      // Preserve existing PWD-friendly markers
      final Set<Marker> allMarkers = {};
      allMarkers.addAll(
        _markers.where((marker) => marker.markerId.value.startsWith("pwd_")),
      );
      allMarkers.addAll(nearbyMarkers);

      setState(() {
        _markers = allMarkers;
        _circles = nearbyCircles;
      });

      // Adjust the camera to fit all markers
      if (_locationHandler.mapController != null && allMarkers.isNotEmpty) {
        final bounds = _locationHandler.getLatLngBounds(
          allMarkers.map((marker) => marker.position).toList(),
        );
        _locationHandler.mapController!
            .animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
        print("🎯 Adjusted camera to fit ${allMarkers.length} markers.");
      } else {
        print("⚠️ No bounds to adjust camera.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, userState) {
        if (userState is UserLoading) {
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
                    initialCameraPosition: CameraPosition(
                      target: _locationHandler.currentLocation ?? const LatLng(16.0430, 120.3333),
                      zoom: 14,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    markers: _markers,
                    circles: _circles,
                    onMapCreated: _locationHandler.onMapCreated,
                    polygons: _markerHandler.createPolygons(pwdFriendlyLocations),
                    onTap: (LatLng position) {
                      // Handle map tap if needed
                    },
                  ),
                  Topwidgets(
                    inboxKey: inboxKey,
                    settingsKey: settingsKey,
                    onCategorySelected: (selectedType) {
                      _fetchNearbyPlaces(selectedType);
                    },
                    onOverlayChange: (isVisible) {
                      setState(() {});
                    },
                    onSpaceSelected: _locationHandler.updateActiveSpaceId,
                  ),
                  if (_locationHandler.currentIndex == 0)
                    BottomWidgets(
                      key: ValueKey(_locationHandler.activeSpaceId),
                      scrollController: ScrollController(),
                      activeSpaceId: _locationHandler.activeSpaceId,
                      onCategorySelected: (selectedType) {
                        _fetchNearbyPlaces(selectedType);
                      },
                    ),
                  if (_locationHandler.currentIndex == 1) const FavoriteWidget(),
                  if (_locationHandler.currentIndex == 2) const SafetyAssistWidget(),
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
    );
  }
}