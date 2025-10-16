import 'dart:async';

import 'package:accessability/accessability/backgroundServices/place_notification_service.dart';
import 'package:accessability/accessability/backgroundServices/space_member_notification_service.dart';
import 'package:accessability/accessability/backgroundServices/distance_notification_service.dart';
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:accessability/accessability/backgroundServices/pwd_location_notification_service.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'location_updates',
      initialNotificationTitle: 'Location Updates',
      initialNotificationContent: 'Tracking your location in the background',
      foregroundServiceNotificationId: 1,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );

  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();

    final pwdNotificationService = PWDLocationNotificationService();
    await pwdNotificationService.initialize();

    final placeNotificationService = PlaceNotificationService();
    await placeNotificationService.initialize();

    final spaceMemberNotificationService = SpaceMemberNotificationService();
    await spaceMemberNotificationService.initialize();

    final distanceNotificationService = DistanceNotificationService();
    await distanceNotificationService.initialize();

    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title: "Location Tracking",
        content: "Your location is being updated.",
      );
      service.setAsForegroundService();
    }

    // Check if the user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      service.invoke('stopService');
      return;
    }

    // Initialize ChatService for expiration checking
    final chatService = ChatService();

    // Initialize location service
    final location = Location();

    // Timer for periodic expiration checks (every 5 minutes)
    Timer.periodic(Duration(minutes: 5), (timer) async {
      try {
        await chatService.checkAndExpireRequests();
        print('Completed expiration check cycle');
      } catch (e) {
        print('Error in expiration check timer: $e');
      }
    });

    print('Background service initialized successfully');

    // // 🧪 TEST MODE - Set this to true to test with static data
    // final bool testMode = false; // Change to true when testing

    // if (testMode) {
    //   print('🧪 TEST MODE: Starting static location test sequence');
    //   await _runStaticLocationTest(distanceNotificationService, user.uid);
    //   print('🧪 TEST MODE: Static location test completed');
    //   return; // Stop real location updates during test
    // }

    // Listen for location updates (REAL MODE)
    location.onLocationChanged.listen((LocationData locationData) async {
      if (locationData.latitude == null || locationData.longitude == null) {
        return;
      }

      final latLng = LatLng(locationData.latitude!, locationData.longitude!);

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('UserLocations')
          .doc(user.uid)
          .set({
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'timestamp': DateTime.now(),
      });

      // Check for nearby PWD locations
      print('Checking for PWD locations...');
      pwdNotificationService.checkLocationForNotifications(latLng);

      // Check for nearby regular places
      print('Checking for regular places...');
      placeNotificationService.checkLocationForNotifications(latLng);

      // Check for significant movement and notify space members
      print('Checking for significant movement...');
      distanceNotificationService.checkLocationForNotifications(latLng);

      service.invoke('update', {
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
      });
    });

    // Start monitoring for all services
    pwdNotificationService.startLocationMonitoring();
    placeNotificationService.startLocationMonitoring();
    distanceNotificationService.startLocationMonitoring();
    print('Location monitoring started');

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Keep alive
    while (service is AndroidServiceInstance &&
        await service.isForegroundService()) {
      await Future.delayed(const Duration(seconds: 5));
    }
  } catch (e) {
    print('Error in background service: $e');
  }
}

// 🧪 TEST METHOD: Run static location test sequence
// Future<void> _runStaticLocationTest(
//     DistanceNotificationService distanceService, String userId) async {
//   try {
//     // Test locations (use coordinates that are >5km apart)
//     final testLocations = [
//       {
//         'name': 'Singapore Start',
//         'latLng': LatLng(1.3521, 103.8198),
//         'description': 'Initial position'
//       },
//       {
//         'name': 'North Singapore',
//         'latLng': LatLng(1.4500, 103.8500),
//         'description': '11km away - should trigger notification'
//       },
//       {
//         'name': 'South Singapore',
//         'latLng': LatLng(1.2903, 103.8515),
//         'description': '7km from previous - should trigger'
//       },
//       {
//         'name': 'Far West',
//         'latLng': LatLng(1.3521, 103.6000),
//         'description': '24km from start - should trigger'
//       },
//     ];

//     print('🧪 TEST: Starting with ${testLocations.length} test locations');

//     for (int i = 0; i < testLocations.length; i++) {
//       final location = testLocations[i];
//       final latLng = location['latLng'] as LatLng;

//       print('🧪 TEST [${i + 1}/${testLocations.length}]: ${location['name']}');
//       print('   📍 Coordinates: ${latLng.latitude}, ${latLng.longitude}');
//       print('   📝 ${location['description']}');

//       // Update Firestore with test location
//       await FirebaseFirestore.instance
//           .collection('UserLocations')
//           .doc(userId)
//           .set({
//         'latitude': latLng.latitude,
//         'longitude': latLng.longitude,
//         'timestamp': DateTime.now(),
//         'is_test_data': true, // Mark as test data
//       });

//       // Trigger distance check
//       await distanceService.checkLocationForNotifications(latLng);

//       // Wait before next test location
//       if (i < testLocations.length - 1) {
//         print('🧪 TEST: Waiting 10 seconds before next location...');
//         await Future.delayed(Duration(seconds: 10));
//       }
//     }

//     print('🧪 TEST: All test locations completed!');
//     print(
//         '🧪 CHECK: Look for notifications on this device and other space members devices');
//   } catch (e) {
//     print('❌ TEST ERROR: $e');
//   }
// }

// Helper method: Get user's spaces
Future<List<String>> _getUserSpaces(String userId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('Spaces')
        .where('members', arrayContains: userId)
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  } catch (e) {
    print('Error getting user spaces: $e');
    return [];
  }
}
