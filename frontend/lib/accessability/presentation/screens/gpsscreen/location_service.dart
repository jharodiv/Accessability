import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationService {
  static void getUserLocation(Location location,
      {required Function(LatLng, LocationData) onLocationChanged}) async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }
    PermissionStatus permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
      if (permission != PermissionStatus.granted) return;
    }
    location.onLocationChanged.listen((LocationData data) {
      final newLocation = LatLng(data.latitude!, data.longitude!);
      onLocationChanged(newLocation, data);
    });
  }

  static Future<void> updateUserLocation(LatLng location) async {
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
}
