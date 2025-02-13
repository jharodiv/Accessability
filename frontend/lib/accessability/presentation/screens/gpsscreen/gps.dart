import 'dart:math';

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
      "latitude": 16.04361106008402,
      "longitude": 120.33531522527143,
      "details": "Wheelchair ramps, accessible restrooms, and reserved parking.",
    },
    {
      "name": "Nepo Mall Dagupan",
      "latitude": 16.051224004022384,
      "longitude": 120.34170650545146,
      "details": "Elevators, ramps, and PWD-friendly restrooms.",
    },
    {
      "name": "Dagupan Public Market",
      "latitude": 16.043166316470707,
      "longitude": 120.33608116388851,
      "details": "Wheelchair-friendly pathways and accessible stalls.",
    },

    {
      "name": "PHINMA University of Pangasinan",
      "latitude": 16.047254394614715,
      "longitude":  120.34250043932526,
      "details": "Wheelchair accessible entrances and parking lots."
    }
  ];

 @override
void initState() {
  super.initState();
  _getUserLocation();

  // Add PWD-friendly markers
  _createMarkers().then((markers) {
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
      _showTutorial();
    }
  });
}

Future<bool> _onWillPop() async {
    // Show confirmation dialog
    return await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Exit'),
          content: const Text('Do you really want to exit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Do not exit
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Exit
              child: const Text('Yes'),
            ),
          ],
        );
      },
    ) ?? false; // Return false if dialog is dismissed
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<BitmapDescriptor> _getCustomIcon() async {
    return await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(24, 24)), // Match the resized image dimensions
      'assets/images/others/accessabilitylogo.png',
    );
  }



   Future<Set<Marker>> _createMarkers() async {
  final customIcon = await _getCustomIcon();
  return pwdFriendlyLocations.map((location) {
    return Marker(
      markerId: MarkerId("pwd_${location["name"]}"), // Add prefix for PWD-friendly markers
      position: LatLng(location["latitude"], location["longitude"]),
      infoWindow: InfoWindow(
        title: location["name"],
        snippet: location["details"],
      ),
      icon: customIcon,
      onTap: () => _onMarkerTapped(MarkerId("pwd_${location["name"]}")),
    );
  }).toSet();
}

   void _onMarkerTapped(MarkerId markerId) {
    final location = pwdFriendlyLocations.firstWhere(
      (loc) => loc["name"] == markerId.value,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(location["name"]),
          content: Text(location["details"]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

   Set<Polygon> _createPolygons() {
    final Set<Polygon> polygons = {};

    for (var location in pwdFriendlyLocations) {
      final LatLng center = LatLng(location["latitude"], location["longitude"]);

      // Create a small circular area around the location
      final List<LatLng> points = [];
      for (double angle = 0; angle <= 360; angle += 10) {
        final double radians = angle * (3.141592653589793 / 180);
        final double latOffset = 0.0005 * cos(radians); // Adjust for size
        final double lngOffset = 0.0005 * sin(radians); // Adjust for size
        points.add(LatLng(center.latitude + latOffset, center.longitude + lngOffset));
      }

      polygons.add(
        Polygon(
          polygonId: PolygonId(location["name"]),
          points: points,
          strokeColor: Colors.green,
          fillColor: Colors.green.withOpacity(0.2),
          strokeWidth: 2,
        ),
      );
    }

    return polygons;
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

    // Create a new set for nearby places markers
    final Set<Marker> nearbyMarkers = {};

    for (var place in places) {
      final lat = place["geometry"]["location"]["lat"];
      final lng = place["geometry"]["location"]["lng"];
      final name = place["name"];
      LatLng position = LatLng(lat, lng);

      nearbyMarkers.add(
        Marker(
          markerId: MarkerId(name),
          position: position,
          infoWindow: InfoWindow(title: name),
        ),
      );

      print("📍 Added Nearby Marker: $name at ($lat, $lng)");
    }

    // Combine PWD-friendly markers and nearby markers
    final Set<Marker> allMarkers = {};
    allMarkers.addAll(_markers.where((marker) => marker.markerId.value.startsWith("pwd_"))); // Preserve PWD-friendly markers
    allMarkers.addAll(nearbyMarkers); // Add nearby places markers

    setState(() {
      _markers.clear();
      _markers.addAll(allMarkers); // Update the map with all markers
    });

    // Adjust the camera to fit all markers
    if (_mapController != null && allMarkers.isNotEmpty) {
      final bounds = _getLatLngBounds(allMarkers.map((marker) => marker.position).toList());
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
      print("🎯 Adjusted camera to fit ${allMarkers.length} markers.");
    } else {
      print("⚠️ No bounds to adjust camera.");
    }
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
      _createMarkers().then((markers) {
        setState(() {
          _markers.addAll(markers);
        });
      });
    });

    if (_mapController != null && _currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 14),
      );
    }
  }


@override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
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
              polygons: _createPolygons(),
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
                    } else {
                    }
                  });
                },
              ),
            // DraggableScrollableSheet with search bar and add person button
            DraggableScrollableSheet(
              initialChildSize: 0.1,
              minChildSize: 0.1,
              maxChildSize: 0.8,
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Search bar
                          TextField(
                            decoration: const InputDecoration(
                              labelText: "Search Location",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(20))
                                
                              ),
                            ),
                            onChanged: (value) {
                              // Handle search logic here
                            },
                          ),
                          const SizedBox(height: 20),
                          // Add person section
                          ElevatedButton(
                            onPressed: () {
                              // Handle add person action here
                            },
                            child: const Text("Add Person"),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
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
              } else {
              }
            });
          },
        ),
      ),
    );
  }
}


enum OverlayPosition { top, bottom }
