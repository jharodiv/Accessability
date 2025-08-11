import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:AccessAbility/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as location_package;
import 'package:AccessAbility/accessability/presentation/widgets/google_helper/openstreetmap_helper.dart';

class LocationHandler {
  final location_package.Location _location = location_package.Location();
  LatLng? currentLocation;
  String activeSpaceId = '';
  final OpenStreetMapGeocodingService _geocodingService =
      OpenStreetMapGeocodingService();

  // Location update control
  static const double _minDistanceForUpdate = 50.0; // meters
  DateTime? _lastLocationUpdateTime;
  LatLng? _lastUpdatedLocation;
  static const Duration _movementVerificationWindow = Duration(seconds: 1);
  List<LatLng> _recentLocations = [];
  static const double _significantMovementThreshold = 50.0; // meters
  static const Duration _stationaryCheckInterval = Duration(minutes: 5);
  DateTime? _lastStationaryCheckTime;
  bool _isStationary = false;
  LatLng? _stationaryReferencePoint;

  // Separate subscription for location stream
  StreamSubscription<location_package.LocationData>?
      _locationStreamSubscription;

  // Subscription for Firestore updates
  StreamSubscription? _firestoreSubscription;

  location_package.LocationData? _lastLocation;
  int currentIndex = 0;
  Set<Marker> _markers = {};
  String? selectedUserId;
  GoogleMapController? mapController;
  OverlayEntry? _overlayEntry;
  bool _showBottomWidgets = false;
  bool get showBottomWidgets => _showBottomWidgets;
  bool _isNavigating = false;
  bool get isNavigating => _isNavigating;
  Set<Circle> _circles = {};
  Set<Circle> get circles => _circles;

  // Cache for addresses
  final Map<String, String> _addressCache = {};
  final Map<String, DateTime> _addressCacheTimestamps = {};

  // Callback to update markers in the parent widget
  final Function(Set<Marker>) onMarkersUpdated;

  LocationHandler({required this.onMarkersUpdated});

  // [Core Location Methods]
  Future<void> getUserLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    location_package.PermissionStatus permissionGranted =
        await _location.hasPermission();
    if (permissionGranted == location_package.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != location_package.PermissionStatus.granted) {
        return;
      }
    }

    _locationStreamSubscription = _location.onLocationChanged.listen(
      (location_package.LocationData locationData) async {
        if (locationData.latitude == null || locationData.longitude == null) {
          return;
        }

        final newLocation =
            LatLng(locationData.latitude!, locationData.longitude!);
        _recentLocations.add(newLocation);

        // Keep only locations from the last verification window
        _recentLocations = _recentLocations
            .where((loc) =>
                DateTime.now()
                    .difference(_lastLocationUpdateTime ?? DateTime.now()) <
                _movementVerificationWindow)
            .toList();

        if (_shouldUpdateLocation(newLocation)) {
          currentLocation = newLocation;
          _lastLocation = locationData;
          _lastUpdatedLocation = newLocation;
          _lastLocationUpdateTime = DateTime.now();

          await _updateUserLocation(newLocation);

          final locationKey =
              '${newLocation.latitude}_${newLocation.longitude}';
          if (!_addressCache.containsKey(locationKey) ||
              await _isNetworkAvailable()) {
            _updateAddressCache(newLocation);
          }
        }
      },
      onError: (error) {
        print("Error receiving location updates: $error");
      },
    );
  }

  Future<bool> _isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<LatLng?> getUserLocationOnce() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return null;
      }

      location_package.PermissionStatus permissionGranted =
          await _location.hasPermission();
      if (permissionGranted == location_package.PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != location_package.PermissionStatus.granted)
          return null;
      }

      final locationData = await _location.getLocation();
      if (locationData.latitude == null || locationData.longitude == null) {
        return null;
      }

      final latLng = LatLng(locationData.latitude!, locationData.longitude!);
      currentLocation = latLng;
      _updateUserLocation(latLng);
      return latLng;
    } catch (e) {
      print("Error fetching user location: $e");
      return null;
    }
  }

  Future<void> initializeUserMarker() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .get();
    final username = userDoc['username'];
    final profilePictureUrl = userDoc.data()?['profilePicture'] ?? '';

    BitmapDescriptor customIcon;
    if (profilePictureUrl.isNotEmpty) {
      try {
        customIcon =
            await _createCustomMarkerIcon(profilePictureUrl, isSelected: false);
      } catch (e) {
        print("Error creating custom marker for $username: $e");
        customIcon = await BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(size: Size(24, 24)),
          'assets/images/others/default_profile.png',
        );
      }
    } else {
      customIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(24, 24)),
        'assets/images/others/default_profile.png',
      );
    }

    if (currentLocation != null) {
      final userMarker = Marker(
        markerId: const MarkerId('user_current'),
        position: currentLocation!,
        infoWindow: const InfoWindow(title: 'You'),
        icon: customIcon,
      );

      _markers.add(userMarker);
      onMarkersUpdated(_markers);
    }
  }

  // [Space Management Methods]
  void updateActiveSpaceId(String spaceId) {
    if (spaceId.isEmpty) {
      _firestoreSubscription?.cancel();
      _firestoreSubscription = null;
      activeSpaceId = '';
      selectedUserId = null;
      return;
    }

    if (spaceId == activeSpaceId) return;

    activeSpaceId = spaceId;
    listenForLocationUpdates(); // Start listening for the new space
  }

  void listenForLocationUpdates() {
    if (activeSpaceId.isEmpty) return;

    _firestoreSubscription?.cancel();

    _firestoreSubscription = FirebaseFirestore.instance
        .collection('Spaces')
        .doc(activeSpaceId)
        .snapshots()
        .asyncMap((spaceSnapshot) async {
          final members = List<String>.from(spaceSnapshot['members']);
          return FirebaseFirestore.instance
              .collection('UserLocations')
              .where(FieldPath.documentId, whereIn: members)
              .snapshots();
        })
        .asyncExpand((snapshotStream) => snapshotStream)
        .listen((snapshot) async {
          final updatedMarkers = <Marker>{};
          final existingMarkers = _markers
              .where((marker) => !marker.markerId.value.startsWith('user_'))
              .toSet();

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final lat = data['latitude'];
            final lng = data['longitude'];
            final userId = doc.id;

            if (_shouldProcessMemberUpdate(userId, lat, lng)) {
              final userDoc = await FirebaseFirestore.instance
                  .collection('Users')
                  .doc(userId)
                  .get();
              final username = userDoc['username'];
              final profilePictureUrl = userDoc.data()?['profilePicture'] ?? '';

              final isSelected = userId == selectedUserId;
              BitmapDescriptor customIcon;
              if (profilePictureUrl.isNotEmpty) {
                try {
                  customIcon = await _createCustomMarkerIcon(
                    profilePictureUrl,
                    isSelected: isSelected,
                  );
                } catch (e) {
                  customIcon = await BitmapDescriptor.fromAssetImage(
                    const ImageConfiguration(size: Size(24, 24)),
                    'assets/images/others/default_profile.png',
                  );
                }
              } else {
                customIcon = await BitmapDescriptor.fromAssetImage(
                  const ImageConfiguration(size: Size(24, 24)),
                  'assets/images/others/default_profile.png',
                );
              }

              final location = LatLng(lat, lng);
              final address = await getAddressForLocation(location);

              updatedMarkers.add(
                Marker(
                  markerId: MarkerId('user_$userId'),
                  position: location,
                  infoWindow: InfoWindow(
                    title: username,
                    snippet: '${_calculateDistance(
                      currentLocation!.latitude,
                      currentLocation!.longitude,
                      lat,
                      lng,
                    ).toStringAsFixed(1)} km • $address',
                  ),
                  icon: customIcon,
                  onTap: () => _onMarkerTapped(MarkerId('user_$userId')),
                ),
              );
            }
          }

          if (updatedMarkers.isNotEmpty) {
            _markers = existingMarkers.toSet().union(updatedMarkers);
            onMarkersUpdated(_markers);
          }
        });
  }

  // [UI Control Methods]
  void showOverlay(BuildContext context, Widget overlayContent) {
    _overlayEntry = OverlayEntry(builder: (context) => overlayContent);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void updateCircles(Set<Circle> newCircles) {
    _circles = newCircles;
  }

  void setNavigating(bool isNavigating) {
    _isNavigating = isNavigating;
  }

  void toggleBottomWidgetsVisibility(bool isVisible) {
    _showBottomWidgets = isVisible;
  }

  // [Helper Methods]
  bool _shouldUpdateLocation(LatLng newLocation) {
    // First location always updates
    if (_lastUpdatedLocation == null) {
      _stationaryReferencePoint = newLocation;
      _lastLocationUpdateTime = DateTime.now();
      return true;
    }

    final distance = _calculateDistance(
      _stationaryReferencePoint!.latitude,
      _stationaryReferencePoint!.longitude,
      newLocation.latitude,
      newLocation.longitude,
    );

    // Check if 5 minutes have passed since last update
    final timeSinceLastUpdate =
        DateTime.now().difference(_lastLocationUpdateTime!);
    final fiveMinutesPassed = timeSinceLastUpdate >= Duration(minutes: 5);

    // Significant movement always triggers update
    if (distance > _significantMovementThreshold) {
      _isStationary = false;
      _stationaryReferencePoint = newLocation;
      _lastLocationUpdateTime = DateTime.now();
      return true;
    }

    // If 5 minutes passed with no significant movement
    if (fiveMinutesPassed) {
      _lastLocationUpdateTime = DateTime.now();
      return true;
    }

    // Otherwise, don't update
    return false;
  }

  bool _shouldProcessMemberUpdate(String userId, double lat, double lng) {
    final existingMarker = _markers.firstWhere(
      (marker) => marker.markerId.value == 'user_$userId',
      orElse: () => Marker(markerId: const MarkerId('')),
    );

    if (existingMarker.markerId.value.isEmpty) return true;

    final distance = _calculateDistance(
      existingMarker.position.latitude,
      existingMarker.position.longitude,
      lat,
      lng,
    );

    return distance > _minDistanceForUpdate;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _updateAddressCache(LatLng location) async {
    final locationKey = '${location.latitude}_${location.longitude}';

    try {
      final address = await _geocodingService
          .getAddressFromLatLng(location)
          .timeout(Duration(seconds: 10));

      _addressCache[locationKey] = address;
      _addressCacheTimestamps[locationKey] = DateTime.now();
    } catch (e) {
      print("Error updating address cache: $e");
      // Store basic coordinates if network fails
      _addressCache[locationKey] =
          'Near ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
      _addressCacheTimestamps[locationKey] = DateTime.now();
    }
  }

  Future<String> getAddressForLocation(LatLng location) async {
    final locationKey = '${location.latitude}_${location.longitude}';

    // Return cached address if available and not expired (24 hours)
    if (_addressCache.containsKey(locationKey)) {
      final cacheTime = _addressCacheTimestamps[locationKey];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime) < Duration(hours: 24)) {
        return _addressCache[locationKey]!;
      }
    }

    try {
      final address = await _geocodingService
          .getAddressFromLatLng(location)
          .timeout(Duration(seconds: 10)); // Add timeout

      _addressCache[locationKey] = address;
      _addressCacheTimestamps[locationKey] = DateTime.now();
      return address;
    } catch (e) {
      print("Error fetching address: $e");
      // Return cached address even if expired when network fails
      if (_addressCache.containsKey(locationKey)) {
        return _addressCache[locationKey]!;
      }
      return 'Near ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
    }
  }

  void _onMarkerTapped(MarkerId markerId) {
    if (markerId.value.startsWith('user_')) {
      final userId = markerId.value.replaceFirst('user_', '');
      selectedUserId = userId;
      listenForLocationUpdates();
    }
  }

  Future<void> _updateUserLocation(LatLng location) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Only update if we're supposed to (handled by _shouldUpdateLocation)
    await FirebaseFirestore.instance
        .collection('UserLocations')
        .doc(user.uid)
        .set({
      'latitude': location.latitude,
      'longitude': location.longitude,
      'timestamp': DateTime.now(),
      'is_stationary': _isStationary,
    });
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon(String imageUrl,
      {bool isSelected = false}) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load image: ${response.statusCode}');
      }

      final profileBytes = response.bodyBytes;
      final profileCodec = await ui.instantiateImageCodec(profileBytes);
      final profileFrame = await profileCodec.getNextFrame();
      final profileImage = profileFrame.image;

      final markerShapeAsset = isSelected
          ? 'assets/images/others/marker_shape_selected.png'
          : 'assets/images/others/marker_shape.png';
      final markerShapeBytes = await rootBundle.load(markerShapeAsset);
      final markerShapeCodec =
          await ui.instantiateImageCodec(markerShapeBytes.buffer.asUint8List());
      final markerShapeFrame = await markerShapeCodec.getNextFrame();
      final markerShapeImage = markerShapeFrame.image;

      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);

      final markerWidth = markerShapeImage.width.toDouble();
      final markerHeight = markerShapeImage.height.toDouble();
      canvas.drawImage(markerShapeImage, Offset.zero, Paint());

      const profileSize = 100.0;
      final profileOffset = Offset(
        (markerWidth - profileSize) / 1.8,
        11,
      );

      final clipPath = Path()
        ..addOval(Rect.fromCircle(
          center: Offset(profileOffset.dx + profileSize / 2,
              profileOffset.dy + profileSize / 2),
          radius: profileSize / 2,
        ));
      canvas.clipPath(clipPath);

      canvas.drawImageRect(
        profileImage,
        Rect.fromLTWH(0, 0, profileImage.width.toDouble(),
            profileImage.height.toDouble()),
        Rect.fromLTWH(
            profileOffset.dx, profileOffset.dy, profileSize, profileSize),
        Paint(),
      );

      final picture = pictureRecorder.endRecording();
      final imageMarker =
          await picture.toImage(markerWidth.toInt(), markerHeight.toInt());
      final byteData =
          await imageMarker.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }

      return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
    } catch (e) {
      print("Error creating custom marker icon: $e");
      return BitmapDescriptor.defaultMarker;
    }
  }

  Future<bool> onWillPop(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Confirm Exit'),
              content: const Text('Do you really want to exit?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  LatLngBounds getLatLngBounds(List<LatLng> locations) {
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

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  void navigateToSettings(BuildContext context) {
    if (_isNavigating) return;
    _isNavigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, '/settings').then((_) {
        _isNavigating = false;
      });
    });
  }

  void onMapCreated(GoogleMapController controller, bool isDarkMode) {
    mapController = controller;
    setMapStyle(controller, isDarkMode);
  }

  Future<void> panCameraToLocation(LatLng location) async {
    if (mapController != null) {
      await mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(location, 14.0),
      );
    }
  }

  Future<void> setMapStyle(
      GoogleMapController controller, bool isDarkMode) async {
    if (isDarkMode) {
      String style =
          await rootBundle.loadString('assets/map_styles/dark_mode.json');
      controller.setMapStyle(style);
    } else {
      controller.setMapStyle(null);
    }
  }

  void disposeHandler() {
    _locationStreamSubscription?.cancel();
    _firestoreSubscription?.cancel();
  }
}
