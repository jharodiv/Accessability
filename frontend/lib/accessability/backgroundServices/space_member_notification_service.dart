import 'dart:async';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SpaceMemberNotificationService {
  static final SpaceMemberNotificationService _instance =
      SpaceMemberNotificationService._internal();

  factory SpaceMemberNotificationService() => _instance;

  SpaceMemberNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Set<String> _notifiedMembers = {};
  Timer? _checkTimer;
  LatLng? _currentLocation;
  String _activeSpaceId = '';

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notifications.initialize(initializationSettings);

    // Create notification channel for space member alerts
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'space_member_alerts',
      'Space Member Alerts',
      importance: Importance.high,
      description: 'Notifications for nearby space members',
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Method to update current location and check for nearby members
  Future<void> checkForNearbyMembers(LatLng location, String spaceId) async {
    _currentLocation = location;
    _activeSpaceId = spaceId;
    await _checkForNearbySpaceMembers();
  }

  void startMemberMonitoring() {
    // Check every 30 seconds for nearby space members
    _checkTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_currentLocation != null && _activeSpaceId.isNotEmpty) {
        await _checkForNearbySpaceMembers();
      }
    });
  }

  void stopMemberMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _notifiedMembers.clear();
  }

  void updateActiveSpace(String spaceId) {
    _activeSpaceId = spaceId;
    _notifiedMembers.clear(); // Reset notifications for new space
  }

  Future<void> _checkForNearbySpaceMembers() async {
    if (_currentLocation == null || _activeSpaceId.isEmpty) return;

    try {
      // Get all members of the active space
      final spaceDoc =
          await _firestore.collection('Spaces').doc(_activeSpaceId).get();
      final members = List<String>.from(spaceDoc['members'] ?? []);

      // Remove current user from the list
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId != null) {
        members.remove(currentUserId);
      }

      if (members.isEmpty) return;

      // Get locations of all space members
      final locationsSnapshot = await _firestore
          .collection('UserLocations')
          .where(FieldPath.documentId, whereIn: members)
          .get();

      for (final doc in locationsSnapshot.docs) {
        final memberId = doc.id;
        final data = doc.data();

        if (data['latitude'] == null || data['longitude'] == null) continue;

        final memberLocation = LatLng(
          _parseDouble(data['latitude']),
          _parseDouble(data['longitude']),
        );

        final distance = _calculateDistance(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          memberLocation.latitude,
          memberLocation.longitude,
        );

        // Notify if member is within 100 meters and hasn't been notified yet
        if (distance <= 100.0 && !_notifiedMembers.contains(memberId)) {
          await _showMemberNotification(memberId, distance);
          _notifiedMembers.add(memberId);
        } else if (distance > 150.0) {
          // Remove from notified set when member moves away
          _notifiedMembers.remove(memberId);
        }
      }
    } catch (e, stackTrace) {
      print('Error checking for nearby space members: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _showMemberNotification(String memberId, double distance) async {
    try {
      // Get member details
      final memberDoc =
          await _firestore.collection('Users').doc(memberId).get();
      final username = memberDoc['username'] ?? 'Space Member';
      final distanceKm = (distance / 1000).toStringAsFixed(2);

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'space_member_alerts',
        'Space Member Alerts',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        'Space Member Nearby!',
        '$username is ${distanceKm}km away from you',
        platformChannelSpecifics,
      );
    } catch (e) {
      print('Error showing member notification: $e');
    }
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
}
