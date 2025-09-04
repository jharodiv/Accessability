import 'dart:async';

import 'package:accessability/accessability/backgroundServices/space_member_notification_service.dart';
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart'; // ADD THIS IMPORT
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

    final spaceMemberNotificationService = SpaceMemberNotificationService();
    await spaceMemberNotificationService.initialize();

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

    // Listen for location updates
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
      pwdNotificationService.checkLocationForNotifications(latLng);

      service.invoke('update', {
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
      });
    });

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
