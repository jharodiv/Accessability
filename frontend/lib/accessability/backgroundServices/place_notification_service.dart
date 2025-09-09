import 'dart:async';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaceNotificationService {
  static final PlaceNotificationService _instance =
      PlaceNotificationService._internal();

  factory PlaceNotificationService() => _instance;

  PlaceNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Set<String> _notifiedPlaces = {};
  Timer? _checkTimer;
  LatLng? _currentLocation;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SharedPreferences? _sharedPrefs;
  String? _currentUserId;

  Future<void> initialize() async {
    // Initialize SharedPreferences
    _sharedPrefs = await SharedPreferences.getInstance();
    _currentUserId = _sharedPrefs?.getString('user_userId');

    print('PlaceNotificationService initialized with user ID: $_currentUserId');

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notifications.initialize(initializationSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'place_alerts',
      'Place Alerts',
      importance: Importance.high,
      description: 'Notifications for nearby places',
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Method to update current location and check for nearby places
  Future<void> checkLocationForNotifications(LatLng location) async {
    _currentLocation = location;
    await _checkForNearbyPlaces();
  }

  void startLocationMonitoring() {
    // Check every 30 seconds for nearby places
    _checkTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_currentLocation != null) {
        await _checkForNearbyPlaces();
      }
    });
  }

  void stopLocationMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _notifiedPlaces.clear();
  }

  Future<void> _checkForNearbyPlaces() async {
    if (_currentLocation == null) {
      print('❌ No current location available for place notifications');
      return;
    }

    print(
        '📍 Checking for nearby places at: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');

    try {
      final places = await _fetchAllPlaces();
      print('📋 Found ${places.length} total places to check');

      if (places.isEmpty) {
        print('ℹ️ No places found in database for notifications');
        return;
      }

      for (final place in places) {
        final distance = _calculateDistance(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          place['latitude'],
          place['longitude'],
        );

        final radius =
            _parseNotificationRadius(place['notificationRadius'] ?? 100.0);
        final placeId = place['id'];
        final placeName = place['name'];
        final placeType = place['type'];

        print('📊 $placeType Place: "$placeName"');
        print('   📍 Coordinates: ${place['latitude']}, ${place['longitude']}');
        print(
            '   📏 Distance: ${distance.toStringAsFixed(2)}m / Radius: ${radius}m');
        print('   🆔 Place ID: $placeId');
        print('   ✅ Already notified: ${_notifiedPlaces.contains(placeId)}');

        if (distance <= radius) {
          if (!_notifiedPlaces.contains(placeId)) {
            print('🎯 WITHIN RANGE: Showing notification for "$placeName"');
            await _showPlaceNotification(place);
            _notifiedPlaces.add(placeId);
          } else {
            print('ℹ️ Already notified about "$placeName"');
          }
        } else if (distance > radius * 1.5) {
          if (_notifiedPlaces.contains(placeId)) {
            print('🚪 LEFT AREA: Removed "$placeName" from notified places');
            _notifiedPlaces.remove(placeId);
          }
        }

        print('---');
      }
    } catch (e, stackTrace) {
      print('❌ Error checking for places: $e');
      print('StackTrace: $stackTrace');
    }

    print('✅ Place notification check completed');
  }

  Future<List<Map<String, dynamic>>> _fetchAllPlaces() async {
    // Get user ID from SharedPreferences each time (in case it changes)
    final userId = _sharedPrefs?.getString('user_userId');

    if (userId == null) {
      print('❌ No user ID found in SharedPreferences for place notifications');
      return [];
    }

    final List<Map<String, dynamic>> allPlaces = [];

    try {
      // Fetch user's custom places (filter by userId)
      final userPlaces = await _firestore
          .collection('Places')
          .where('userId', isEqualTo: userId)
          .get();

      print('📋 Found ${userPlaces.docs.length} user places for user: $userId');

      for (final doc in userPlaces.docs) {
        final data = doc.data();
        allPlaces.add({
          'id': doc.id,
          'name': data['name'] ?? 'User Place',
          'category': data['category'] ?? 'User Created',
          'latitude': _parseDouble(data['latitude']),
          'longitude': _parseDouble(data['longitude']),
          'notificationRadius': data['notificationRadius'] ?? 100.0,
          'address': data['address'] ?? '',
          'type': 'user_created',
          'userId': data['userId'],
        });

        print(
            '📍 User place: ${data['name']} at ${data['latitude']}, ${data['longitude']}');
      }

      // You can still fetch predefined places if you want
      final predefinedPlaces = await _firestore.collection('places').get();
      print('📋 Found ${predefinedPlaces.docs.length} predefined places');

      for (final doc in predefinedPlaces.docs) {
        final data = doc.data();
        allPlaces.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Place',
          'category': data['category'] ?? 'Place',
          'latitude': _parseDouble(data['latitude']),
          'longitude': _parseDouble(data['longitude']),
          'notificationRadius': data['notificationRadius'] ?? 100.0,
          'address': data['address'] ?? '',
          'type': 'predefined',
        });
      }
    } catch (e) {
      print('❌ Error fetching places: $e');
    }

    return allPlaces;
  }

  void updateUserId(String? userId) {
    _currentUserId = userId;
    if (userId != null) {
      _sharedPrefs?.setString('user_userId', userId);
      print('✅ Updated PlaceNotificationService user ID: $userId');
    } else {
      _sharedPrefs?.remove('user_userId');
      _notifiedPlaces.clear(); // Clear notifications when user logs out
      print('✅ Cleared PlaceNotificationService user ID');
    }
  }

  Future<void> _showPlaceNotification(Map<String, dynamic> place) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'place_alerts',
      'Place Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final category = place['category'] ?? 'Place';
    final placeType =
        place['type'] == 'user_created' ? 'User-created' : category;

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Saved Place Nearby!',
      'You\'re near ${place['name']}. ${place['address'] ?? ''}',
      platformChannelSpecifics,
    );
  }

  double _calculateDistance(
      dynamic lat1, dynamic lon1, dynamic lat2, dynamic lon2) {
    final double lat1Double = _parseDouble(lat1);
    final double lon1Double = _parseDouble(lon1);
    final double lat2Double = _parseDouble(lat2);
    final double lon2Double = _parseDouble(lon2);

    const earthRadius = 6371000;
    final dLat = _toRadians(lat2Double - lat1Double);
    final dLon = _toRadians(lon2Double - lon1Double);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1Double)) *
            cos(_toRadians(lat2Double)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _parseNotificationRadius(dynamic radiusValue) {
    if (radiusValue == null) return 100.0; // default

    if (radiusValue is double) {
      return radiusValue;
    } else if (radiusValue is int) {
      return radiusValue.toDouble();
    } else if (radiusValue is String) {
      return double.tryParse(radiusValue) ?? 100.0;
    } else {
      return 100.0; // fallback default
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    } else {
      return 0.0;
    }
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}
