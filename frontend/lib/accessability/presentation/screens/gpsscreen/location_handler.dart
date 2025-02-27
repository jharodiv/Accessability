import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

class LocationHandler {
  final Location _location = Location();
  LatLng? currentLocation;
  String activeSpaceId = '';

  // Separate subscription for location stream.
  StreamSubscription<LocationData>? _locationStreamSubscription;

  // Subscription for Firestore updates.
  StreamSubscription? _firestoreSubscription;

  LocationData? _lastLocation;
  int currentIndex = 0;
  Set<Marker> _markers = {};
  String? selectedUserId; // Track the selected user ID
  GoogleMapController? mapController;
  OverlayEntry? _overlayEntry;
  bool _showBottomWidgets = false;
  bool get showBottomWidgets => _showBottomWidgets;
  bool _isNavigating = false;
  bool get isNavigating => _isNavigating;
  Set<Circle> _circles = {};
  Set<Circle> get circles => _circles;

  // Callback to update markers in the parent widget.
  final Function(Set<Marker>) onMarkersUpdated;

  LocationHandler({required this.onMarkersUpdated});

  Future<void> getUserLocation() async {
    // Check if the location service is enabled.
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    // Check for permission.
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    // Listen to location changes and store the subscription.
    _locationStreamSubscription =
        _location.onLocationChanged.listen((LocationData locationData) {
      if (locationData.latitude == null || locationData.longitude == null)
        return;
      final newLocation =
          LatLng(locationData.latitude!, locationData.longitude!);
      if (_lastLocation == null ||
          _lastLocation!.latitude != locationData.latitude ||
          _lastLocation!.longitude != locationData.longitude) {
        currentLocation = newLocation;
        _updateUserLocation(newLocation);
        _lastLocation = locationData;
      }
    }, onError: (error) {
      print("Error receiving location updates: $error");
    });
  }

  Future<void> initializeUserMarker() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch the user's profile data.
    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .get();
    final username = userDoc['username'];
    final profilePictureUrl = userDoc.data()?['profilePicture'] ?? '';

    // Create a custom marker icon with the profile picture.
    BitmapDescriptor customIcon;
    if (profilePictureUrl.isNotEmpty) {
      try {
        customIcon =
            await _createCustomMarkerIcon(profilePictureUrl, isSelected: false);
      } catch (e) {
        print("❌ Error creating custom marker for $username: $e");
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

    // Add the user's marker to the map.
    if (currentLocation != null) {
      final userMarker = Marker(
        markerId: const MarkerId('user_current'),
        position: currentLocation!,
        infoWindow: InfoWindow(title: 'You'),
        icon: customIcon,
      );

      _markers.add(userMarker);
      onMarkersUpdated(_markers);
    }
  }

  void showOverlay(BuildContext context, Widget overlayContent) {
    _overlayEntry = OverlayEntry(builder: (context) => overlayContent);
    Overlay.of(context)?.insert(_overlayEntry!);
  }

  void hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void setNavigating(bool isNavigating) {
    _isNavigating = isNavigating;
  }

  void toggleBottomWidgetsVisibility(bool isVisible) {
    _showBottomWidgets = isVisible;
  }

  Future<void> _updateUserLocation(LatLng location) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('UserLocations')
        .doc(user.uid)
        .set({
      'latitude': location.latitude,
      'longitude': location.longitude,
      'timestamp': DateTime.now(),
    });
  }

  void updateActiveSpaceId(String spaceId) {
    if (spaceId.isEmpty) return;
    activeSpaceId = spaceId;
    listenForLocationUpdates();
  }

  void updateCircles(Set<Circle> newCircles) {
    _circles = newCircles;
  }

  void listenForLocationUpdates() {
    if (activeSpaceId.isEmpty) return;
    // Cancel any previous Firestore subscription.
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
              .where((marker) => !marker.markerId.value.startsWith('user_'));
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lat = data['latitude'];
            final lng = data['longitude'];
            final userId = doc.id;

            final userDoc = await FirebaseFirestore.instance
                .collection('Users')
                .doc(userId)
                .get();
            final username = userDoc['username'];
            final profilePictureUrl = userDoc.data()?['profilePicture'] ?? '';

            print("🟢 Fetched user data for $username: $profilePictureUrl");

            final isSelected = userId == selectedUserId;
            BitmapDescriptor customIcon;
            if (profilePictureUrl.isNotEmpty) {
              try {
                customIcon = await _createCustomMarkerIcon(profilePictureUrl,
                    isSelected: isSelected);
              } catch (e) {
                print("❌ Error creating custom marker for $username: $e");
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

            updatedMarkers.add(
              Marker(
                markerId: MarkerId('user_$userId'),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(title: username),
                icon: customIcon,
                onTap: () => _onMarkerTapped(MarkerId('user_$userId')),
              ),
            );
          }

          print("🟢 Updated ${updatedMarkers.length} user markers.");
          _markers = existingMarkers.toSet().union(updatedMarkers);
          onMarkersUpdated(_markers);
        });
  }

  void _onMarkerTapped(MarkerId markerId) {
    if (markerId.value.startsWith('user_')) {
      final userId = markerId.value.replaceFirst('user_', '');
      selectedUserId = userId;
      listenForLocationUpdates();
    }
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon(String imageUrl,
      {bool isSelected = false}) async {
    print(
        "🟢 Creating custom marker icon for: $imageUrl (isSelected: $isSelected)");
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        print("❌ Failed to load image: ${response.statusCode}");
        throw Exception('Failed to load image');
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

      final profileSize = 100.0;
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
        print("❌ Failed to convert image to bytes");
        throw Exception('Failed to convert image to bytes');
      }
      print("🟢 Custom marker icon created successfully");
      return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
    } catch (e) {
      print("❌ Error creating custom marker icon: $e");
      throw Exception('Failed to create custom marker icon: $e');
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
    print("Navigating to settings...");
    if (_isNavigating) return;
    _isNavigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, '/settings').then((_) {
        print("Returned from settings.");
        _isNavigating = false;
      });
    });
  }

  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // Dispose both subscriptions
  void disposeHandler() {
    _locationStreamSubscription?.cancel();
    _firestoreSubscription?.cancel();
  }
}
