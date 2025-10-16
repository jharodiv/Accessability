import 'package:google_maps_flutter/google_maps_flutter.dart';

class UserPositionData {
  final LatLng position;
  final DateTime timestamp;

  UserPositionData({required this.position, required this.timestamp});
}
