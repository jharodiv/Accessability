import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/accessability/presentation/widgets/accessability_footer.dart';
import 'package:frontend/accessability/presentation/widgets/homepagewidgets/top_widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

class GpsScreen extends StatefulWidget {
  const GpsScreen({super.key});

  @override
  _GpsScreenState createState() => _GpsScreenState();
}

class _GpsScreenState extends State<GpsScreen> {
  OverlayEntry? _overlayEntry;
  GoogleMapController? _mapController;
  final Location _location = Location();
  LatLng? _currentLocation;
  final Set<Marker> _markers = {}; // Set of markers for the map
  GlobalKey inboxKey = GlobalKey();
  GlobalKey settingsKey = GlobalKey();
  GlobalKey youKey = GlobalKey();
  GlobalKey locationKey = GlobalKey();
  GlobalKey securityKey = GlobalKey();
  final String _apiKey = dotenv.env["GOOGLE_API_KEY"] ?? '';

   final List<Map<String, dynamic>> pwdFriendlyLocations = [
    {
      "name": "Dagupan City Hall",
      "latitude": 16.0439,
      "longitude": 120.3333,
      "details": "Wheelchair ramps, accessible restrooms, and reserved parking.",
    },
    {
      "name": "Nepo Mall Dagupan",
      "latitude": 16.0486,
      "longitude": 120.3398,
      "details": "Elevators, ramps, and PWD-friendly restrooms.",
    },
    {
      "name": "Dagupan Public Market",
      "latitude": 16.0417,
      "longitude": 120.3361,
      "details": "Wheelchair-friendly pathways and accessible stalls.",
    },
  ];

  @override
  void initState() {
    super.initState();
    _getUserLocation();

    // Check if onboarding is completed before showing the tutorial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authBloc = context.read<AuthBloc>();
      final hasCompletedOnboarding = authBloc.state is AuthenticatedLogin
          ? (authBloc.state as AuthenticatedLogin).hasCompletedOnboarding
          : false;

      if (!hasCompletedOnboarding) {
        _showTutorial();
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<BitmapDescriptor> _getCustomIcon() async {
  return await BitmapDescriptor.fromAssetImage(
    const ImageConfiguration(size: Size(48, 48)),
    'assets/images/pwd_icon.png', // Path to your custom icon
  );
}

   Set<Marker> _createMarkers() {
    return pwdFriendlyLocations.map((location) {
      return Marker(
        markerId: MarkerId(location["name"]),
        position: LatLng(location["latitude"], location["longitude"]),
        infoWindow: InfoWindow(
          title: location["name"],
          snippet: location["details"],
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), // Green for PWD-friendly
        onTap: () => {},
      );
    }).toSet();
  }

   

  Future<void> _fetchNearbyPlaces(String placeType) async {
    if (_currentLocation == null) {
      print("🚨 Current position is null, cannot fetch nearby places.");
      return;
    }

    final String url =
        "https://maps.googleapis.com/maps/api/place/nearbysearch/json?"
        "location=${_currentLocation!.latitude},${_currentLocation!.longitude}"
        "&radius=1500&type=$placeType&key=$_apiKey";

    print("🔵 Fetching nearby places: $url");

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print("🟢 API Response: ${data.toString()}"); // Log full response

      final List<dynamic> places = data["results"];

      setState(() {
        _markers.clear();
        List<LatLng> bounds = [];

        for (var place in places) {
          final lat = place["geometry"]["location"]["lat"];
          final lng = place["geometry"]["location"]["lng"];
          final name = place["name"];
          LatLng position = LatLng(lat, lng);

          _markers.add(
            Marker(
              markerId: MarkerId(name),
              position: position,
              infoWindow: InfoWindow(title: name),
            ),
          );

          bounds.add(position);
          print("📍 Added Marker: $name at ($lat, $lng)");
        }

        // Adjust the camera to fit all markers
        if (_mapController != null && bounds.isNotEmpty) {
          LatLngBounds bound = _getLatLngBounds(bounds);
          _mapController!
              .animateCamera(CameraUpdate.newLatLngBounds(bound, 100));
          print("🎯 Adjusted camera to fit ${_markers.length} markers.");
        } else {
          print("⚠️ No bounds to adjust camera.");
        }
      });
    } else {
      print("❌ HTTP Request Failed: ${response.statusCode}");
    }
  }

// Helper function to calculate bounds
  LatLngBounds _getLatLngBounds(List<LatLng> locations) {
    double south = locations.first.latitude;
    double north = locations.first.latitude;
    double west = locations.first.longitude;
    double east = locations.first.longitude;

    for (var loc in locations) {
      if (loc.latitude < south) south = loc.latitude;
      if (loc.latitude > north) north = loc.latitude;
      if (loc.longitude < west) west = loc.longitude;
      if (loc.longitude > east) east = loc.longitude;
    }

    print("📌 Camera Bounds: SW($south, $west) - NE($north, $east)");

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  void _showTutorial() {
    List<TargetFocus> targets = [];

    targets.add(TargetFocus(
      identify: "inboxTarget",
      keyTarget: inboxKey,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          child: Container(
            color: Colors.transparent, // Set a background color
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This is your inbox.",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                      color: Colors.white),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    "Tap here to view your messages.",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "settingsTarget",
      keyTarget: settingsKey,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          child: Container(
            color: Colors.transparent, // Set a background color
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This is the settings button.",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                      color: Colors.white),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    "Tap here to access settings.",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "locationTarget",
      keyTarget: locationKey,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          child: Container(
            color: Colors.transparent,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This is the location button.",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                      color: Colors.white),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    "Tap here to view your location.",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "youTarget",
      keyTarget: youKey,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          child: Container(
            color: Colors.transparent,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This is the 'You' button.",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                      color: Colors.white),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    "Tap here to view your profile.",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ));

    // Security Target
    targets.add(TargetFocus(
      identify: "securityTarget",
      keyTarget: securityKey,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          child: Container(
            color: Colors.transparent,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This is the security button.",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                      color: Colors.white),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    "Tap here to view security settings.",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ));

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        print("Tutorial finished");
      },
      onClickTarget: (target) {
        print('Clicked on target: $target');
      },
      onSkip: () {
        print("Tutorial skipped");
        return true; // Return a boolean value
      },
    ).show(context: context);
  }

   // Get user location
  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // Check if GPS is enabled
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    // Check for permissions
    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    // Get location
    final locationData = await _location.getLocation();
    setState(() {
      _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);

      // Add a marker at the current location
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );

      // Add PWD-friendly markers
      _markers.addAll(_createMarkers());
    });

    if (_mapController != null && _currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 14),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(16.0430, 120.3333),
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            onMapCreated: _onMapCreated,
          ),
          Topwidgets(
            inboxKey: inboxKey,
            settingsKey: settingsKey,
            onCategorySelected: (selectedType) {
              print('Selected Category: $selectedType');

              _fetchNearbyPlaces(selectedType);
            },
            onOverlayChange: (isVisible) {
              print('Overlay state changed: $isVisible');

              setState(() {
                if (isVisible) {
                  _showOverlay(context, OverlayPosition.top);
                } else {
                  _removeOverlay();
                }
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: Accessabilityfooter(
        securityKey: securityKey,
        locationKey: locationKey,
        youKey: youKey,
        onOverlayChange: (isVisible) {
          setState(() {
            if (isVisible) {
              _showOverlay(context, OverlayPosition.bottom);
            } else {
              _removeOverlay();
            }
          });
        },
      ),
    );
  }

  void _showOverlay(BuildContext context, OverlayPosition position) {
    _overlayEntry = _createOverlayEntry(position);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry(OverlayPosition position) {
    return OverlayEntry(
      builder: (context) => Positioned(
        top: position == OverlayPosition.top ? 70 : null,
        bottom: position == OverlayPosition.bottom ? 70 : null,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Column(
              children:
                  [' Circle One', 'Circle Two', 'Circle Three'].map((option) {
                return GestureDetector(
                  onTap: () {
                    debugPrint('$option selected');
                    _removeOverlay();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Text(
                      option,
                      style: const TextStyle(
                        color: Color(0xFF6750A4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

enum OverlayPosition { top, bottom }
