import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:accessability/accessability/backgroundServices/pwd_location_notification_service.dart';
import 'package:accessability/accessability/backgroundServices/space_member_notification_service.dart';
import 'package:accessability/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as location_package;
import 'package:battery_plus/battery_plus.dart';
import 'package:accessability/accessability/backgroundServices/place_notification_service.dart';

typedef UserMarkerTapCallback = void Function({
  required String userId,
  required String username,
  required LatLng location,
  required String address,
  required String profileUrl,
  required double distanceMeters,
  int? batteryPercent,
  double? speedKmh,
  DateTime? timestamp,
});

class LocationHandler {
  final location_package.Location _location = location_package.Location();
  LatLng? currentLocation;
  String activeSpaceId = '';
  final OpenStreetMapGeocodingService _geocodingService =
      OpenStreetMapGeocodingService();
  final Map<String, Marker> _markerMap = {};
  Set<Marker> get markersSet => _markerMap.values.toSet();

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

  final StreamController<LatLng> _locationStreamController =
      StreamController<LatLng>.broadcast();

  /// A broadcast stream that emits the current location whenever it changes.
  Stream<LatLng> get locationStream => _locationStreamController.stream;

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
  final PWDLocationNotificationService _pwdNotificationService =
      PWDLocationNotificationService();

  final SpaceMemberNotificationService _spaceMemberNotificationService =
      SpaceMemberNotificationService();

  // Cache for addresses
  final Map<String, String> _addressCache = {};
  final Map<String, DateTime> _addressCacheTimestamps = {};

  // Callback to update markers in the parent widget
  final Function(Set<Marker>) onMarkersUpdated;
  final UserMarkerTapCallback? onUserMarkerTap;

  LocationHandler({
    required this.onMarkersUpdated,
    this.onUserMarkerTap, // new optional callback
  });

  void _setMarker(Marker marker) {
    _markerMap[marker.markerId.value] = marker; // replace or add
    _markers = _markerMap.values.toSet();
    onMarkersUpdated(_markers);
  }

  void _removeMarkersWithPrefix(String prefix) {
    final keysToRemove =
        _markerMap.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in keysToRemove) _markerMap.remove(k);
    _markers = _markerMap.values.toSet();
    onMarkersUpdated(_markers);
  }

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
          try {
            _locationStreamController.add(currentLocation!);
          } catch (_) {
            // ignore if controller closed
          }

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

  Future<void> _updateUserLocation(LatLng location) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // compute speed (lastLocation.speed is m/s)
    double? mps;
    try {
      mps = _lastLocation?.speed;
    } catch (_) {
      mps = null;
    }
    double? speedKmh = (mps != null) ? mps * 3.6 : null;

    // battery (optional; requires battery_plus)
    int? batteryPercent;
    try {
      final battery = Battery();
      batteryPercent = await battery.batteryLevel;
    } catch (_) {
      batteryPercent = null;
    }

    try {
      await FirebaseFirestore.instance
          .collection('UserLocations')
          .doc(user.uid)
          .set({
        'latitude': location.latitude,
        'longitude': location.longitude,
        // server timestamp so other clients read a Timestamp object
        'timestamp': FieldValue.serverTimestamp(),
        'is_stationary': _isStationary,
        'speed': mps, // meters/sec (nullable)
        'speedKmh': speedKmh, // km/h (nullable)
        'batteryPercent': batteryPercent, // nullable
      }, SetOptions(merge: true));

      PlaceNotificationService().checkLocationForNotifications(location);

      _pwdNotificationService.checkLocationForNotifications(location);
      if (activeSpaceId.isNotEmpty) {
        _spaceMemberNotificationService.checkForNearbyMembers(
            location, activeSpaceId);
      }
    } catch (e) {
      debugPrint('Failed to update UserLocations: $e');
    }
  }

  Future<void> initializeNotificationService() async {
    await _pwdNotificationService.initialize();
    _pwdNotificationService.startLocationMonitoring();
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

// emit the one-off location as well
      try {
        _locationStreamController.add(latLng);
      } catch (_) {}

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
        infoWindow: InfoWindow.noText,
        consumeTapEvents: true,
        // ignore: deprecated_member_use
        zIndex: 2000.0, // <<--- ensure user is on top
        icon: customIcon,
        onTap: () async {
          final address = await getAddressForLocation(currentLocation!);
          final usernameLocal = userDoc.data()?['username'] ?? 'You';

          // compute distance (0 for current user)
          final distMeters = 0.0;

          // speed from last location (location package provides m/s)
          double? speedKmh;
          try {
            final mps = _lastLocation?.speed;
            if (mps != null) speedKmh = (mps.toDouble()) * 3.6;
          } catch (_) {
            speedKmh = null;
          }

          // battery (optional, requires battery_plus in pubspec)
          int? batteryPercent;
          try {
            final battery = Battery();
            batteryPercent = await battery.batteryLevel;
          } catch (_) {
            batteryPercent = null;
          }

          // timestamp: prefer server time when you wrote it; fallback to now
          DateTime? timestamp;
          try {
            // attempt to read the stored timestamp in UserLocations doc (if present)
            final doc = await FirebaseFirestore.instance
                .collection('UserLocations')
                .doc(user.uid)
                .get();
            final tsRaw = doc.data()?['timestamp'];
            if (tsRaw is Timestamp) {
              timestamp = tsRaw.toDate();
            } else if (tsRaw is String) {
              timestamp = DateTime.tryParse(tsRaw);
            } else {
              timestamp = DateTime.now();
            }
          } catch (_) {
            timestamp = DateTime.now();
          }

          // Debug print so you can see exactly what is being forwarded
          debugPrint(
              '[LocationHandler.initializeUserMarker] tapping current user payload: battery=$batteryPercent speedKmh=$speedKmh timestamp=$timestamp');

          if (onUserMarkerTap != null) {
            onUserMarkerTap!(
              userId: user.uid,
              username: usernameLocal,
              location: currentLocation!,
              address: address,
              profileUrl: profilePictureUrl ?? '',
              distanceMeters: distMeters,
              batteryPercent: batteryPercent,
              speedKmh: speedKmh,
              timestamp: timestamp,
            );
          }
        },
      );

      _setMarker(userMarker);
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
          // Track which member marker ids we saw in this update
          final Set<String> seenMemberMarkerIds = {};

          // Process each member doc and add/replace marker
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final lat = data['latitude'];
            final lng = data['longitude'];
            final userId = doc.id;

            if (!_shouldProcessMemberUpdate(userId, lat, lng)) {
              // skip if not worth updating
              continue;
            }

            // Fetch user profile for icon/text
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
            final memberMarkerId = 'user_$userId';

            // Build the marker (keep your existing onTap body)
            final Marker memberMarker = Marker(
              markerId: MarkerId(memberMarkerId),
              position: location,
              infoWindow: InfoWindow.noText,
              consumeTapEvents: true,
              icon: customIcon,
              zIndex: 300.0,
              onTap: () async {
                final address = await getAddressForLocation(location);
                double distMeters = 0.0;
                if (currentLocation != null) {
                  distMeters = _calculateDistance(
                    currentLocation!.latitude,
                    currentLocation!.longitude,
                    lat,
                    lng,
                  );
                }
                final dataMap = doc.data() as Map<String, dynamic>? ?? {};

                final rawBattery = dataMap['batteryPercent'];
                final int? batteryPercentParsed = rawBattery is int
                    ? rawBattery
                    : (rawBattery != null
                        ? int.tryParse(rawBattery.toString())
                        : null);

                double? speedKmhParsed;
                if (dataMap['speedKmh'] != null) {
                  final s = dataMap['speedKmh'];
                  speedKmhParsed =
                      (s is num) ? s.toDouble() : double.tryParse('$s');
                } else if (dataMap['speed'] != null) {
                  final s = dataMap['speed'];
                  final double? mps =
                      (s is num) ? s.toDouble() : double.tryParse('$s');
                  if (mps != null) speedKmhParsed = mps * 3.6;
                }

                DateTime? timestampParsed;
                final tsRaw = dataMap['timestamp'];
                if (tsRaw is Timestamp)
                  timestampParsed = tsRaw.toDate();
                else if (tsRaw is String)
                  timestampParsed = DateTime.tryParse(tsRaw);

                debugPrint(
                    '[LocationHandler.listenForLocationUpdates] tapped user=$userId battery=$batteryPercentParsed speedKmh=$speedKmhParsed timestamp=$timestampParsed dist=${distMeters.toStringAsFixed(1)}');

                selectedUserId = userId;

                if (onUserMarkerTap != null) {
                  onUserMarkerTap!(
                    userId: userId,
                    username: username,
                    location: location,
                    address: address,
                    profileUrl: profilePictureUrl ?? '',
                    distanceMeters: distMeters,
                    batteryPercent: batteryPercentParsed,
                    speedKmh: speedKmhParsed,
                    timestamp: timestampParsed,
                  );
                }

                // keep listening (you had this call previously)
                listenForLocationUpdates();
              },
            );

            // Add or replace the marker in the map (this is where _setMarker is used)
            _setMarker(memberMarker);
            seenMemberMarkerIds.add(memberMarkerId);
          }

          // Remove member markers that were NOT present in this snapshot (stale ones).
          // Important: do NOT remove the current user's marker (you used 'user_current' id earlier).
          final keysToRemove = _markerMap.keys.where((k) {
            return k.startsWith('user_') &&
                k !=
                    'user_current' && // keep current-user marker if you still use this id
                !seenMemberMarkerIds.contains(k);
          }).toList();

          if (keysToRemove.isNotEmpty) {
            for (final k in keysToRemove) {
              _markerMap.remove(k);
            }
            // push updated set to map consumers
            _markers = _markerMap.values.toSet();
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

  Future<BitmapDescriptor> _createCustomMarkerIcon(
    String imageUrl, {
    bool isSelected = false,
    String? username,
    Color? accentColor,
  }) async {
    try {
      final double dpr = ui.window.devicePixelRatio;

      // Logical sizes
      const double logicalSquare = 78.0;
      const double logicalBorder = 4.0;
      const double logicalCorner = 18.0;
      const double logicalPointerW = 16.0;
      const double logicalPointerH = 12.0;
      const double logicalOverlap = 6.0;

      // device pixels
      final double border = logicalBorder * dpr;
      final double corner = logicalCorner * dpr;
      final double pointerW = logicalPointerW * dpr;
      final double pointerH = logicalPointerH * dpr;
      final double overlap = logicalOverlap * dpr;
      final double outerSize = logicalSquare * dpr;

      const double logicalSafetyGap = 2.0;
      final double safetyGap = logicalSafetyGap * dpr;

      // softer accent purple
      final Color accent = accentColor ??
          (isSelected ? const Color(0xFF6750A4) : const Color(0xFF6750A4));
      final Color fallbackBg = const Color(0xFFEEEEF5);
      final Color initialColor = Colors.white;

      ui.Image? profileImg;
      Color? sampledColor;

      // load image
      if (imageUrl.isNotEmpty) {
        try {
          final resp = await http
              .get(Uri.parse(imageUrl))
              .timeout(const Duration(seconds: 10));
          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            final codec = await ui.instantiateImageCodec(resp.bodyBytes);
            final frame = await codec.getNextFrame();
            profileImg = frame.image;

            // --- SAMPLE COLOR ---
            final ByteData? bd =
                await profileImg.toByteData(format: ui.ImageByteFormat.rawRgba);
            if (bd != null) {
              final Uint8List pixels = bd.buffer.asUint8List();
              int r = 0, g = 0, b = 0, count = 0;
              // sample every 100th pixel for speed
              for (int i = 0; i < pixels.length; i += 400) {
                r += pixels[i];
                g += pixels[i + 1];
                b += pixels[i + 2];
                count++;
              }
              if (count > 0) {
                sampledColor =
                    Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count);
              }
            }
          }
        } catch (e) {
          debugPrint('[marker] image load error: $e');
        }
      }

      final double inset = border;
      final double innerSize = outerSize - inset * 2;
      final double innerBottomY = inset + innerSize;

      final double defaultPointerTopY = outerSize - overlap;
      final double pointerTopY =
          max(defaultPointerTopY, innerBottomY + safetyGap);
      final double tipY = pointerTopY + pointerH;

      final int canvasW = (outerSize).ceil();
      final int canvasH =
          max((outerSize + pointerH - overlap).ceil(), tipY.ceil());

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder,
          Rect.fromLTWH(0, 0, canvasW.toDouble(), canvasH.toDouble()));
      final paint = Paint()..isAntiAlias = true;

      canvas.drawRect(
          Rect.fromLTWH(0, 0, canvasW.toDouble(), canvasH.toDouble()),
          Paint()..blendMode = BlendMode.clear);

      final RRect outerRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, outerSize, outerSize),
        Radius.circular(corner),
      );

      // soft shadow
      canvas.drawRRect(
        outerRRect.shift(Offset(0, border * 0.45)),
        Paint()
          ..color = Colors.black.withOpacity(0.06)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, border),
      );

      // outer accent
      paint
        ..style = PaintingStyle.fill
        ..color = accent;
      canvas.drawRRect(outerRRect, paint);

      // inner rect
      final RRect innerRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(inset, inset, innerSize, innerSize),
        Radius.circular(max(0.0, corner - inset)),
      );

      // fill with sampled color or fallback
      final Color innerFillColor = sampledColor ?? Colors.white;
      canvas.drawRRect(
          innerRRect,
          Paint()
            ..style = PaintingStyle.fill
            ..color = innerFillColor);

      // draw profile
      canvas.save();
      canvas.clipRRect(innerRRect);
      if (profileImg != null) {
        final double imgW = profileImg.width.toDouble();
        final double imgH = profileImg.height.toDouble();
        final double scale = max(innerSize / imgW, innerSize / imgH);
        final double srcW = innerSize / scale;
        final double srcH = innerSize / scale;
        final double srcLeft = (imgW - srcW) / 2;
        final double srcTop = (imgH - srcH) / 2;
        final Rect src = Rect.fromLTWH(srcLeft, srcTop, srcW, srcH);
        final Rect dst = Rect.fromLTWH(inset, inset, innerSize, innerSize);
        canvas.drawImageRect(profileImg, src, dst, Paint()..isAntiAlias = true);
      } else {
        paint
          ..style = PaintingStyle.fill
          ..color = fallbackBg;
        canvas.drawRRect(innerRRect, paint);
        final String initial = (username != null && username.trim().isNotEmpty)
            ? username.trim()[0].toUpperCase()
            : '?';
        final tp = TextPainter(
          text: TextSpan(
            text: initial,
            style: TextStyle(
                color: initialColor,
                fontSize: innerSize * 0.42,
                fontWeight: FontWeight.w700),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        tp.layout(minWidth: 0, maxWidth: innerSize);
        tp.paint(
            canvas,
            Offset(inset + ((innerSize - tp.width) / 2),
                inset + ((innerSize - tp.height) / 2)));
      }
      canvas.restore();

      // pointer
      final double leftX = (outerSize / 2) - (pointerW / 2);
      final double rightX = (outerSize / 2) + (pointerW / 2);
      final double tipX = outerSize / 2;

      final Path triangle = Path()
        ..moveTo(leftX, pointerTopY)
        ..lineTo(tipX, tipY)
        ..lineTo(rightX, pointerTopY)
        ..close();

      paint
        ..style = PaintingStyle.fill
        ..color = accent;
      canvas.drawPath(triangle, paint);

      // highlight
      final double innerTopY = pointerTopY + (pointerH * 0.18);
      final double innerTipY = tipY - (pointerH * 0.18);
      canvas.drawPath(
        Path()
          ..moveTo(leftX + (pointerW * 0.2), innerTopY)
          ..lineTo(tipX, innerTipY)
          ..lineTo(rightX - (pointerW * 0.2), innerTopY)
          ..close(),
        Paint()..color = Colors.white.withOpacity(0.06),
      );

      final ui.Image finalImg =
          await recorder.endRecording().toImage(canvasW, canvasH);
      final ByteData? bd =
          await finalImg.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) throw Exception('Failed to encode marker image');

      return BitmapDescriptor.fromBytes(bd.buffer.asUint8List());
    } catch (e, st) {
      debugPrint('_createCustomMarkerIcon error: $e\n$st');
      try {
        return await BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(size: Size(48, 48)),
            'assets/images/others/default_profile.png');
      } catch (_) {
        return BitmapDescriptor.defaultMarker;
      }
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

  Future<void> panCameraToLocation(LatLng location,
      {double zoom = 17.0}) async {
    debugPrint('LocationHandler.panCameraToLocation -> $location (zoom=$zoom)');

    if (mapController == null) {
      debugPrint(
          'LocationHandler.panCameraToLocation: mapController == null — cannot animate');
      return;
    }

    try {
      // Try animated camera first
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: zoom),
        ),
      );
      debugPrint(
          'LocationHandler.panCameraToLocation: animateCamera completed');
    } catch (e, st) {
      debugPrint(
          'LocationHandler.panCameraToLocation: animateCamera threw: $e\n$st');
    }

    // Small delay to allow camera to settle, then verify visible region center
    await Future.delayed(const Duration(milliseconds: 250));
    try {
      final bounds = await mapController!.getVisibleRegion();
      final centerLat =
          (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
      final centerLng =
          (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
      final center = LatLng(centerLat, centerLng);

      // distance in meters between requested location and actual center
      final distMeters = _calculateDistance(
        center.latitude,
        center.longitude,
        location.latitude,
        location.longitude,
      );

      debugPrint(
          'LocationHandler.panCameraToLocation: center=$center distMeters=$distMeters');

      // If still far (> ~80 meters) force-move camera
      if (distMeters > 80) {
        debugPrint(
            'LocationHandler.panCameraToLocation: forcing moveCamera due to distance');
        await mapController!.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: location, zoom: zoom),
          ),
        );
      }
    } catch (e) {
      debugPrint(
          'LocationHandler.panCameraToLocation: getVisibleRegion / verify failed: $e');
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
    _pwdNotificationService.stopLocationMonitoring();
    try {
      _locationStreamController.close();
    } catch (_) {}
  }

  void enableRouteDeviationChecking(Function(LatLng) onDeviationDetected) {
    // Listen to location stream for real-time deviation detection
    _locationStreamController.stream.listen((LatLng newLocation) {
      onDeviationDetected(newLocation);
    });
  }
}
