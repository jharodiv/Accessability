import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

enum MapPerspective {
  classic,
  aerial,
  terrain,
  street,
  perspective,
}

class MapViewScreen extends StatefulWidget {
  final MapPerspective? initialPerspective; // Optional parameter

  const MapViewScreen({Key? key, this.initialPerspective}) : super(key: key);

  @override
  _MapViewScreenState createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  MapType _currentMapType = MapType.normal;
  late GoogleMapController _controller;
  late MapPerspective _selectedPerspective;

  // Instead of a hard-coded position, we use _currentLocation.
  // Default fallback is Dagupan, Pangasinan.
  LatLng _currentLocation = const LatLng(16.0430, 120.3333);
  bool _isLocationFetched = false;

  // Using the same logic as in gps.dart.
  late LocationHandler _locationHandler;

  @override
  void initState() {
    super.initState();
    // Set the initial perspective (or default to classic).
    _selectedPerspective = widget.initialPerspective ?? MapPerspective.classic;

    _locationHandler = LocationHandler(
      onMarkersUpdated: (markers) {
        // Not used here.
      },
    );

    _locationHandler.getUserLocation().then((_) {
      setState(() {
        _isLocationFetched = true;
        if (_locationHandler.currentLocation != null) {
          _currentLocation = _locationHandler.currentLocation!;
        }
      });
      _locationHandler.initializeUserMarker();
      if (_locationHandler.currentLocation != null) {
        _controller.animateCamera(
          CameraUpdate.newLatLng(_locationHandler.currentLocation!),
        );
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    if (_isLocationFetched && _locationHandler.currentLocation != null) {
      _controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _locationHandler.currentLocation!,
            zoom: 14.0,
          ),
        ),
      );
    }
  }

  void _onMapTypeButtonPressed(MapType type) {
    setState(() {
      _currentMapType = type;
    });
  }

  void _setClassicView() {
    setState(() {
      _selectedPerspective = MapPerspective.classic;
    });
    _onMapTypeButtonPressed(MapType.normal);
    _controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation,
          zoom: 14.4746,
        ),
      ),
    );
  }

  void _setAerialView() {
    setState(() {
      _selectedPerspective = MapPerspective.aerial;
    });
    _onMapTypeButtonPressed(MapType.satellite);
    _controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation,
          zoom: 14.4746,
        ),
      ),
    );
  }

  void _setTerrainView() {
    setState(() {
      _selectedPerspective = MapPerspective.terrain;
    });
    _onMapTypeButtonPressed(MapType.terrain);
    _controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation,
          zoom: 14.4746,
        ),
      ),
    );
  }

  void _setStreetLevelView() {
    setState(() {
      _selectedPerspective = MapPerspective.street;
    });
    _onMapTypeButtonPressed(MapType.hybrid);
    _controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation,
          zoom: 18,
        ),
      ),
    );
  }

  void _set3DView() {
    setState(() {
      _selectedPerspective = MapPerspective.perspective;
    });
    _onMapTypeButtonPressed(MapType.normal);
    _controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation,
          zoom: 18,
          tilt: 60,
          bearing: 45,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(65),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: AppBar(
              elevation: 0,
              leading: IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back),
                color: const Color(0xFF6750A4),
              ),
              title: Text(
                'map_settings'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80.0),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 300,
                    margin: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: const Color(0xFF6750A4)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation,
                          zoom: 14.0,
                        ),
                        mapType: _currentMapType,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "choose_a_perspective".tr(),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _setClassicView,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _selectedPerspective == MapPerspective.classic
                                  ? const Color(0xFF6750A4)
                                  : const Color.fromARGB(255, 211, 198, 248),
                        ),
                        child: Text("classic_view".tr()),
                      ),
                      ElevatedButton(
                        onPressed: _setAerialView,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _selectedPerspective == MapPerspective.aerial
                                  ? const Color(0xFF6750A4)
                                  : const Color.fromARGB(255, 211, 198, 248),
                        ),
                        child: Text("aerial_view".tr()),
                      ),
                      ElevatedButton(
                        onPressed: _setTerrainView,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _selectedPerspective == MapPerspective.terrain
                                  ? const Color(0xFF6750A4)
                                  : const Color.fromARGB(255, 211, 198, 248),
                        ),
                        child: Text("terrain_view".tr()),
                      ),
                      ElevatedButton(
                        onPressed: _setStreetLevelView,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _selectedPerspective == MapPerspective.street
                                  ? const Color(0xFF6750A4)
                                  : const Color.fromARGB(255, 211, 198, 248),
                        ),
                        child: Text("street_level".tr()),
                      ),
                      ElevatedButton(
                        onPressed: _set3DView,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _selectedPerspective == MapPerspective.perspective
                                  ? const Color(0xFF6750A4)
                                  : const Color.fromARGB(255, 211, 198, 248),
                        ),
                        child: Text("three_d_perspective".tr()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(bottom: 25, left: 10, right: 10),
          child: ElevatedButton(
            onPressed: () {
              // Return the currently selected perspective.
              Navigator.pop(context, {'perspective': _selectedPerspective});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6750A4),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: Text("save".tr(), style: const TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
