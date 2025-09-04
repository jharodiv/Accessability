import 'dart:async';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:accessability/accessability/presentation/screens/gpsscreen/pwd_friendly_locations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PWDLocationNotificationService {
  static final PWDLocationNotificationService _instance =
      PWDLocationNotificationService._internal();

  factory PWDLocationNotificationService() => _instance;

  PWDLocationNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Set<String> _notifiedLocations = {};
  Timer? _checkTimer;
  LatLng? _currentLocation;

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notifications.initialize(initializationSettings);

    // Create notification channel for PWD location alerts
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'pwd_location_alerts',
      'PWD Location Alerts',
      importance: Importance.high,
      description: 'Notifications for nearby PWD-friendly locations',
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Method to update current location and check for nearby locations
  Future<void> checkLocationForNotifications(LatLng location) async {
    _currentLocation = location;
    await _checkForNearbyPWDLocations();
  }

  void startLocationMonitoring() {
    // Check every 30 seconds for nearby PWD locations
    _checkTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_currentLocation != null) {
        await _checkForNearbyPWDLocations();
      }
    });
  }

  void stopLocationMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _notifiedLocations.clear();
  }

  Future<void> _checkForNearbyPWDLocations() async {
    if (_currentLocation == null) return;

    try {
      print('Fetching PWD locations...');
      final locations = await getPwdFriendlyLocations();
      print('Fetched ${locations.length} PWD locations');

      for (final location in locations) {
        // Debug: Print the type and value of notificationRadius
        final radiusValue = location['notificationRadius'];

        final distance = _calculateDistance(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          location['latitude'],
          location['longitude'],
        );

        // FIX: Handle both double and string types for notificationRadius
        final radius = _parseNotificationRadius(location['notificationRadius']);
        final locationId = location['id'];

        if (distance <= radius && !_notifiedLocations.contains(locationId)) {
          await _showLocationNotification(location);
          _notifiedLocations.add(locationId);
        } else if (distance > radius * 1.5) {
          // Remove from notified set when user leaves the area
          _notifiedLocations.remove(locationId);
        }
      }
    } catch (e, stackTrace) {
      print('Error checking for PWD locations: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // NEW: Helper method to parse notification radius from various types
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

  Future<void> _showLocationNotification(Map<String, dynamic> location) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'pwd_location_alerts',
      'PWD Location Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'PWD-Friendly Location Nearby!',
      'You\'re near ${location['name']}. ${location['details'] ?? ''}',
      platformChannelSpecifics,
    );
  }

  double _calculateDistance(
      dynamic lat1, dynamic lon1, dynamic lat2, dynamic lon2) {
    // Convert all inputs to double to handle any type issues
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

// Helper method to parse any type to double
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
