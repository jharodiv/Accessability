import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/widgets/accessability_footer.dart';
import 'package:frontend/accessability/presentation/widgets/homepagewidgets/top_widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class GpsScreen extends StatefulWidget {
  const GpsScreen({super.key});

  @override
  _GpsScreenState createState() => _GpsScreenState();
}

class _GpsScreenState extends State<GpsScreen> {
  OverlayEntry? _overlayEntry;
  GoogleMapController? _mapController;
  Location _location = Location();
  LatLng? _currentLocation;
  Set<Marker> _markers = {}; // Set of markers for the map

  @override
  void initState() {
    super.initState();
    _getUserLocation();
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
          markerId: MarkerId('user_location'),
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
            onOverlayChange: (isVisible) {
              setState(() {
                if (isVisible) {
                  _showOverlay(context);
                } else {
                  _removeOverlay();
                }
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: const Accessabilityfooter(),
    );
  }

  void _showOverlay(BuildContext context) {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        top: 70,
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
                  ['Circle One', 'Circle Two', 'Circle Three'].map((option) {
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
