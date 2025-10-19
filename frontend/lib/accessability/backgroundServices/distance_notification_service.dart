import 'dart:async';
import 'dart:math';
import 'package:accessability/accessability/backgroundServices/userposition_data.dart';
import 'package:accessability/accessability/data/model/place.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accessability/accessability/utils/map_utils.dart';

class DistanceNotificationService {
  static final DistanceNotificationService _instance =
      DistanceNotificationService._internal();

  factory DistanceNotificationService() => _instance;

  DistanceNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Set<String> _notifiedMovements = {};
  Timer? _checkTimer;
  LatLng? _currentLocation;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  SharedPreferences? _sharedPrefs;
  String? _currentUserId;

  // Track positions and timestamps
  final Map<String, UserPositionData> _lastKnownPositions = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, double> _lastReportedHomeDistances = {};

  // Configuration
  static const double _distanceThresholdKm = 5.0; // 5 km threshold
  static const Duration _debounceDuration =
      Duration(minutes: 5); // Prevent spam

  Future<void> initialize() async {
    // Initialize SharedPreferences
    _sharedPrefs = await SharedPreferences.getInstance();
    _currentUserId = _sharedPrefs?.getString('user_userId');

    print(
        'DistanceNotificationService initialized with user ID: $_currentUserId');

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notifications.initialize(initializationSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'distance_alerts',
      'Distance Alerts',
      importance: Importance.high,
      description: 'Notifications when space members move significantly',
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Method to update current location and check for significant movement
  Future<void> checkLocationForNotifications(LatLng location) async {
    _currentLocation = location;
    await _checkForSignificantMovement();
  }

  void startLocationMonitoring() {
    // Check every 30 seconds for significant movement
    _checkTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_currentLocation != null) {
        await _checkForSignificantMovement();
      }
    });
  }

  void stopLocationMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _notifiedMovements.clear();

    // Clean up debounce timers and position data
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _lastKnownPositions.clear();
  }

  Future<void> _checkForSignificantMovement() async {
    if (_currentLocation == null) {
      print('❌ No current location available for distance notifications');
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('❌ No user logged in for distance notifications');
      return;
    }

    print('📍 Checking for significant movement for user: ${currentUser.uid}');

    try {
      // Get user's spaces
      final userSpaces = await _getUserSpaces(currentUser.uid);
      print('📋 User is in ${userSpaces.length} spaces');

      if (userSpaces.isEmpty) {
        print('ℹ️ User is not a member of any spaces');
        return;
      }

      for (final spaceId in userSpaces) {
        await _checkMovementForSpace(
            currentUser.uid, _currentLocation!, spaceId);
      }

      print('✅ Distance notification check completed');
    } catch (e, stackTrace) {
      print('❌ Error checking for significant movement: $e');
      print('StackTrace: $stackTrace');
    }
  }

  /// Check if a user has moved significantly and notify OTHER space members
  Future<void> checkSignificantMovement(
      String userId, LatLng newLocation, String activeSpaceId) async {
    if (activeSpaceId.isEmpty) return;

    // Debounce check to prevent spam
    final debounceKey = '$userId-$activeSpaceId';
    if (_debounceTimers.containsKey(debounceKey)) {
      return;
    }

    // Get user's spaces
    final userSpaces = await _getUserSpaces(userId);
    if (userSpaces.isEmpty) return;

    for (final spaceId in userSpaces) {
      await _checkMovementForSpace(userId, newLocation, spaceId);
    }

    // Set debounce timer
    _debounceTimers[debounceKey] = Timer(_debounceDuration, () {
      _debounceTimers.remove(debounceKey);
    });
  }

  /// Get all spaces where the user is a member
  Future<List<String>> _getUserSpaces(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('Spaces')
          .where('members', arrayContains: userId)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('❌ Error getting user spaces: $e');
      return [];
    }
  }

  /// Check movement for a specific space and notify OTHER members if threshold exceeded
  Future<void> _checkMovementForSpace(
      String movingUserId, LatLng newLocation, String spaceId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final key = '$movingUserId-$spaceId';
    final lastPositionData = _lastKnownPositions[key];

    // If this is the first position recorded, just store it
    if (lastPositionData == null) {
      _lastKnownPositions[key] =
          UserPositionData(position: newLocation, timestamp: DateTime.now());
      print(
          '📍 Stored initial position for user $movingUserId in space $spaceId');
      return;
    }

    final lastLocation = lastPositionData.position;
    final distanceKm = MapUtils.calculateDistanceKm(lastLocation, newLocation);

    print(
        '📊 User $movingUserId moved ${distanceKm.toStringAsFixed(2)} km in space $spaceId');
    print('   📍 From: ${lastLocation.latitude}, ${lastLocation.longitude}');
    print('   📍 To: ${newLocation.latitude}, ${newLocation.longitude}');

    // Check if movement exceeds threshold
    if (distanceKm >= _distanceThresholdKm) {
      final movementKey =
          '$movingUserId-$spaceId-${DateTime.now().millisecondsSinceEpoch}';

      if (!_notifiedMovements.contains(movementKey)) {
        print(
            '🎯 SIGNIFICANT MOVEMENT: User moved ${distanceKm.toStringAsFixed(1)} km');

        // ✅ FIXED: Only notify OTHER space members, not the moving user
        if (movingUserId != currentUser.uid) {
          // This is for when we're notified about OTHER users' movements
          await _showDistanceNotificationToOtherMembers(
              movingUserId, spaceId, newLocation, distanceKm);
        } else {
          // This is when CURRENT USER moves - notify other members in the space
          await _notifyOtherSpaceMembers(
              movingUserId, spaceId, newLocation, distanceKm);
        }

        _notifiedMovements.add(movementKey);
      } else {
        print('ℹ️ Already notified about this movement');
      }

      // Update last known position
      _lastKnownPositions[key] =
          UserPositionData(position: newLocation, timestamp: DateTime.now());
    } else {
      print(
          'ℹ️ Movement below threshold (${distanceKm.toStringAsFixed(2)} km < $_distanceThresholdKm km)');
    }
  }

  /// ✅ NEW METHOD: Notify OTHER space members when current user moves
  Future<void> _notifyOtherSpaceMembers(String movingUserId, String spaceId,
      LatLng newLocation, double distanceKm) async {
    try {
      // Get moving user info
      final userDoc =
          await _firestore.collection('Users').doc(movingUserId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final displayName = _getDisplayName(userData);

      // Get space info
      final spaceDoc = await _firestore.collection('Spaces').doc(spaceId).get();
      final spaceName =
          spaceDoc.exists ? (spaceDoc.data()?['name'] ?? 'Space') : 'Space';

      // Get address for the new location
      final address = await _getAddressFromLatLng(newLocation);

      // Get all OTHER members in the space (excluding the moving user)
      final otherMembers = await _getOtherSpaceMembers(spaceId, movingUserId);

      print(
          '📢 Notifying ${otherMembers.length} other members in space $spaceName');

      // Send FCM notifications to OTHER members' devices
      for (final memberId in otherMembers) {
        await _sendFCMNotificationToMember(memberId, movingUserId, displayName,
            spaceId, spaceName, distanceKm, address, newLocation);
      }

      print(
          '✅ FCM notifications sent to ${otherMembers.length} members about $displayName movement');
    } catch (e) {
      print('❌ Error notifying other space members: $e');
    }
  }

  Future<void> _sendFCMNotificationToMember(
      String targetMemberId,
      String movingUserId,
      String movingUserName,
      String spaceId,
      String spaceName,
      double distanceKm,
      String address,
      LatLng newLocation) async {
    try {
      // Get target member's FCM token
      final targetMemberDoc =
          await _firestore.collection('Users').doc(targetMemberId).get();
      if (!targetMemberDoc.exists) return;

      final targetMemberData = targetMemberDoc.data() as Map<String, dynamic>;
      final fcmToken = targetMemberData['fcmToken'];

      if (fcmToken == null || fcmToken.isEmpty) {
        print('   ⚠️ No FCM token for member: $targetMemberId');
        return;
      }

      // Create a notification document in Firestore to trigger the Cloud Function
      await _firestore.collection('DistanceNotifications').add({
        'targetUserId': targetMemberId,
        'targetFCMToken': fcmToken,
        'movingUserId': movingUserId,
        'movingUserName': movingUserName,
        'spaceId': spaceId,
        'spaceName': spaceName,
        'distanceKm': distanceKm,
        'address': address,
        'latitude': newLocation.latitude,
        'longitude': newLocation.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'distance_alert',
      });

      print('   📲 FCM notification queued for member: $targetMemberId');
    } catch (e) {
      print('❌ Error sending FCM notification to member $targetMemberId: $e');
    }
  }

  /// ✅ NEW METHOD: Get all space members EXCEPT the moving user
  Future<List<String>> _getOtherSpaceMembers(
      String spaceId, String excludeUserId) async {
    try {
      final spaceDoc = await _firestore.collection('Spaces').doc(spaceId).get();
      if (!spaceDoc.exists) return [];

      final members = List<String>.from(spaceDoc.data()?['members'] ?? []);
      // Return all members except the moving user
      return members.where((memberId) => memberId != excludeUserId).toList();
    } catch (e) {
      print('❌ Error getting other space members: $e');
      return [];
    }
  }

  /// ✅ NEW METHOD: Show notification to a specific member
  Future<void> _showNotificationToMember(String memberId, String movingUserName,
      String spaceName, double distanceKm, String address) async {
    try {
      // In a real scenario, you'd use FCM to send push notifications to other devices
      // For now, we'll simulate it by storing in Firestore for other clients to pick up

      await _firestore.collection('DistanceNotifications').add({
        'targetUserId': memberId,
        'movingUserId': _auth.currentUser!.uid,
        'movingUserName': movingUserName,
        'spaceId': spaceName,
        'distanceKm': distanceKm,
        'address': address,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      print('   📲 Notification queued for member: $memberId');
    } catch (e) {
      print('❌ Error showing notification to member $memberId: $e');
    }
  }

  /// Show local notification to OTHER members about movement
  Future<void> _showDistanceNotificationToOtherMembers(String movingUserId,
      String spaceId, LatLng newLocation, double distanceKm) async {
    try {
      // Get moving user info
      final userDoc =
          await _firestore.collection('Users').doc(movingUserId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final displayName = _getDisplayName(userData);

      // Get space info
      final spaceDoc = await _firestore.collection('Spaces').doc(spaceId).get();
      final spaceName =
          spaceDoc.exists ? (spaceDoc.data()?['name'] ?? 'Space') : 'Space';

      // Get address for the new location
      final address = await _getAddressFromLatLng(newLocation);

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'distance_alerts',
        'Distance Alerts',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🚀 $displayName Moved ${distanceKm.toStringAsFixed(1)} km!',
        'In $spaceName • $address',
        platformChannelSpecifics,
      );

      print(
          '✅ Local notification shown about $displayName movement in $spaceName');
    } catch (e) {
      print('❌ Error showing distance notification: $e');
    }
  }

  /// Get display name from user data
  String _getDisplayName(Map<String, dynamic> userData) {
    final firstName = userData['firstName']?.toString() ?? '';
    final lastName = userData['lastName']?.toString() ?? '';
    final username = userData['username']?.toString() ?? 'A member';

    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }
    return username;
  }

  /// Get address from coordinates
  Future<String> _getAddressFromLatLng(LatLng location) async {
    try {
      // Use your existing geocoding service here
      return 'Near ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
    } catch (e) {
      return 'Near ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
    }
  }

  /// Clean up when a user leaves a space
  Future<void> userLeftSpace(String userId, String spaceId) async {
    final key = '$userId-$spaceId';
    _lastKnownPositions.remove(key);
    _debounceTimers.remove(key)?.cancel();

    // Remove any notified movements for this user in this space
    _notifiedMovements.removeWhere(
        (movementKey) => movementKey.startsWith('$userId-$spaceId-'));

    print(
        '✅ Cleared distance tracking data for user $userId in space $spaceId');
  }

  Future<void> checkHomeDistance(
      LatLng currentLocation, String activeSpaceId) async {
    if (activeSpaceId.isEmpty) return;

    try {
      // Get all home markers in the current user's spaces
      final homePlaces = await _getHomePlacesInSpace(activeSpaceId);

      for (final homePlace in homePlaces) {
        final distanceKm = MapUtils.calculateDistanceKm(
          currentLocation,
          LatLng(homePlace.latitude, homePlace.longitude),
        );

        // Check if we've crossed a 5km threshold
        final homeKey = 'home_${homePlace.id}';
        final lastDistance = _lastReportedHomeDistances[homeKey] ?? 0.0;

        if ((lastDistance - distanceKm).abs() >= 5.0) {
          await _sendHomeDistanceNotification(
              homePlace, distanceKm, activeSpaceId);
          _lastReportedHomeDistances[homeKey] = distanceKm;
        }
      }
    } catch (e) {
      print('Error checking home distance: $e');
    }
  }

  // Helper to get home places in a space
  Future<List<Place>> _getHomePlacesInSpace(String spaceId) async {
    try {
      // Get all members in the space
      final spaceDoc = await _firestore.collection('Spaces').doc(spaceId).get();
      if (!spaceDoc.exists) return [];

      final members = List<String>.from(spaceDoc.data()?['members'] ?? []);
      final homePlaces = <Place>[];

      // Get home places for each member
      for (final memberId in members) {
        final homeQuery = await _firestore
            .collection('Places')
            .where('userId', isEqualTo: memberId)
            .where('isHome', isEqualTo: true)
            .limit(1)
            .get();

        if (homeQuery.docs.isNotEmpty) {
          final homePlace = Place.fromMap(
              homeQuery.docs.first.id, homeQuery.docs.first.data());
          homePlaces.add(homePlace);
        }
      }

      return homePlaces;
    } catch (e) {
      print('Error getting home places in space: $e');
      return [];
    }
  }

  // Send home distance notification
  Future<void> _sendHomeDistanceNotification(
      Place homePlace, double distanceKm, String spaceId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get home owner info
      final homeOwnerDoc =
          await _firestore.collection('Users').doc(homePlace.userId).get();

      if (!homeOwnerDoc.exists) return;

      final homeOwnerData = homeOwnerDoc.data() as Map<String, dynamic>;
      final homeOwnerName = _getDisplayName(homeOwnerData);

      // Get current user info
      final currentUserDoc =
          await _firestore.collection('Users').doc(currentUser.uid).get();

      if (!currentUserDoc.exists) return;

      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      final currentUserName = _getDisplayName(currentUserData);

      // Get other members in the space to notify them
      final otherMembers =
          await _getOtherSpaceMembers(spaceId, currentUser.uid);

      for (final memberId in otherMembers) {
        await _sendHomeFCMNotification(
          memberId,
          homePlace,
          homeOwnerName,
          currentUserName,
          distanceKm,
          spaceId,
        );
      }

      print(
          '📢 Home distance notification sent: ${distanceKm.toStringAsFixed(1)} km from $homeOwnerName\'s Home');
    } catch (e) {
      print('❌ Error sending home distance notification: $e');
    }
  }

  // Send FCM notification for home distance
  Future<void> _sendHomeFCMNotification(
      String targetMemberId,
      Place homePlace,
      String homeOwnerName,
      String movingUserName,
      double distanceKm,
      String spaceId) async {
    try {
      // Get target member's FCM token
      final targetMemberDoc =
          await _firestore.collection('Users').doc(targetMemberId).get();
      if (!targetMemberDoc.exists) return;

      final targetMemberData = targetMemberDoc.data() as Map<String, dynamic>;
      final fcmToken = targetMemberData['fcmToken'];

      if (fcmToken == null || fcmToken.isEmpty) {
        print('   ⚠️ No FCM token for member: $targetMemberId');
        return;
      }

      // Create notification document to trigger Cloud Function
      await _firestore.collection('DistanceNotifications').add({
        'targetUserId': targetMemberId,
        'targetFCMToken': fcmToken,
        'homePlaceId': homePlace.id,
        'homeOwnerName': homeOwnerName,
        'movingUserId': _auth.currentUser!.uid,
        'movingUserName': movingUserName,
        'spaceId': spaceId,
        'distanceKm': distanceKm,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'home_distance_alert',
        'message': distanceKm <
                (_lastReportedHomeDistances['home_${homePlace.id}'] ??
                    double.infinity)
            ? '$movingUserName is getting closer to $homeOwnerName\'s Home - ${distanceKm.toStringAsFixed(1)} km away'
            : '$movingUserName is moving away from $homeOwnerName\'s Home - ${distanceKm.toStringAsFixed(1)} km away',
      });

      print('   📲 Home FCM notification queued for member: $targetMemberId');
    } catch (e) {
      print(
          '❌ Error sending home FCM notification to member $targetMemberId: $e');
    }
  }

  void updateUserId(String? userId) {
    _currentUserId = userId;
    if (userId != null) {
      _sharedPrefs?.setString('user_userId', userId);
      print('✅ Updated DistanceNotificationService user ID: $userId');
    } else {
      _sharedPrefs?.remove('user_userId');
      _notifiedMovements.clear();
      print('✅ Cleared DistanceNotificationService user ID');
    }
  }

  /// Clean up when service is disposed
  void dispose() {
    stopLocationMonitoring();

    // Cancel all debounce timers
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _lastKnownPositions.clear();

    print('✅ DistanceNotificationService disposed');
  }
}
