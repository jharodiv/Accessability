import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';

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
}

void onStart(ServiceInstance service) async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();

    // Check if the user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      service.invoke('stopService');
      return;
    }

    // Initialize location service
    final location = Location();

    // Listen for location updates
    location.onLocationChanged.listen((LocationData locationData) async {
      // Update the user's location in Firestore
      await FirebaseFirestore.instance
          .collection('UserLocations')
          .doc(user.uid)
          .set({
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'timestamp': DateTime.now(),
      });

      // Optionally, send data to the UI (if needed)
      service.invoke('update', {
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
      });
    });

    // Handle service lifecycle
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  } catch (e) {
    print('Error in background service: $e');
  }
}