

import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/widgets/accessability_footer.dart';
import 'package:frontend/accessability/presentation/widgets/homepagewidgets/top_widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

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

  @override
  void initState() {
    super.initState();
    _getUserLocation();
     WidgetsBinding.instance.addPostFrameCallback((_) {
    _showTutorial();
  });
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0, color: Colors.white),
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0, color: Colors.white),
              ),
              Padding(
                padding:  EdgeInsets.only(top: 10.0),
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
        align: ContentAlign.bottom,
        child: Container(
          color: Colors.transparent,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "This is the location button.",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0, color: Colors.white),
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
        align: ContentAlign.bottom,
        child: Container(
          color: Colors.transparent,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "This is the 'You' button.",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0, color: Colors.white),
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
        align: ContentAlign.bottom,
        child: Container(
          color: Colors.transparent,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "This is the security button.",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0, color: Colors.white),
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

  // Get User Location
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
      _currentLocation = LatLng(
          locationData.latitude ?? 120.0, locationData.longitude ?? 120.0);
      // Add a marker at the current location
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure), // Custom marker icon (circle for now)
        ),
      );
    });

    // Move camera to user location
    if (_mapController != null && _currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 17),
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
            myLocationEnabled: true, // Shows the blue dot for user location
            myLocationButtonEnabled: true, // Adds a button to center location
            markers: _markers, // Set markers for the map
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              if (_currentLocation != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentLocation!, 17),
                );
              }
            },
          ),
          Topwidgets(
            inboxKey: inboxKey,
            settingsKey: settingsKey,
            onOverlayChange: (isVisible) {
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
              children: [' Circle One', 'Circle Two', 'Circle Three'].map((option) {
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

