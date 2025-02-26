import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class MarkerHelper {
  static final List<Map<String, dynamic>> pwdFriendlyLocations = [
    {
      "name": "Dagupan City Hall",
      "latitude": 16.04361106008402,
      "longitude": 120.33531522527143,
      "details":
          "Wheelchair ramps, accessible restrooms, and reserved parking.",
    },
    {
      "name": "Nepo Mall Dagupan",
      "latitude": 16.051224004022384,
      "longitude": 120.34170650545146,
      "details": "Elevators, ramps, and PWD-friendly restrooms.",
    },
    {
      "name": "Dagupan Public Market",
      "latitude": 16.043166316470707,
      "longitude": 120.33608116388851,
      "details": "Wheelchair-friendly pathways and accessible stalls.",
    },
    {
      "name": "PHINMA University of Pangasinan",
      "latitude": 16.047254394614715,
      "longitude": 120.34250043932526,
      "details": "Wheelchair accessible entrances and parking lots."
    }
  ];

  static Future<Set<Marker>> createPWDMarkers(
      List<Map<String, dynamic>> locations) async {
    final BitmapDescriptor customIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(24, 24)),
      'assets/images/others/accessabilitylogo.png',
    );
    return locations.map((location) {
      return Marker(
        markerId: MarkerId("pwd_${location["name"]}"),
        position: LatLng(location["latitude"], location["longitude"]),
        infoWindow: InfoWindow(
          title: location["name"],
          snippet: location["details"],
        ),
        icon: customIcon,
      );
    }).toSet();
  }

  static Set<Polygon> createPolygons(List<Map<String, dynamic>> locations) {
    final Set<Polygon> polygons = {};
    for (var location in locations) {
      final center = LatLng(location["latitude"], location["longitude"]);
      final List<LatLng> points = [];
      for (double angle = 0; angle <= 360; angle += 10) {
        final double radians = angle * (pi / 180);
        final double latOffset = 0.0005 * cos(radians);
        final double lngOffset = 0.0005 * sin(radians);
        points.add(
            LatLng(center.latitude + latOffset, center.longitude + lngOffset));
      }
      polygons.add(Polygon(
        polygonId: PolygonId(location["name"]),
        points: points,
        strokeColor: Colors.green,
        fillColor: Colors.green.withOpacity(0.2),
        strokeWidth: 2,
      ));
    }
    return polygons;
  }

  static Future<BitmapDescriptor> createCustomMarkerIcon(String imageUrl,
      {bool isSelected = false}) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load image');
      }
      final profileBytes = response.bodyBytes;
      final profileCodec = await ui.instantiateImageCodec(profileBytes);
      final profileFrame = await profileCodec.getNextFrame();
      final profileImage = profileFrame.image;

      final markerShapeAsset = isSelected
          ? 'assets/images/others/marker_shape_selected.png'
          : 'assets/images/others/marker_shape.png';
      final markerShapeBytes = await rootBundle.load(markerShapeAsset);
      final markerShapeCodec =
          await ui.instantiateImageCodec(markerShapeBytes.buffer.asUint8List());
      final markerShapeFrame = await markerShapeCodec.getNextFrame();
      final markerShapeImage = markerShapeFrame.image;

      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);

      final markerWidth = markerShapeImage.width.toDouble();
      final markerHeight = markerShapeImage.height.toDouble();

      canvas.drawImage(markerShapeImage, Offset.zero, Paint());

      final profileSize = 100.0;
      final profileOffset = Offset((markerWidth - profileSize) / 1.8, 11);

      final clipPath = Path()
        ..addOval(Rect.fromCircle(
          center: Offset(profileOffset.dx + profileSize / 2,
              profileOffset.dy + profileSize / 2),
          radius: profileSize / 2,
        ));
      canvas.clipPath(clipPath);

      canvas.drawImageRect(
        profileImage,
        Rect.fromLTWH(0, 0, profileImage.width.toDouble(),
            profileImage.height.toDouble()),
        Rect.fromLTWH(
            profileOffset.dx, profileOffset.dy, profileSize, profileSize),
        Paint(),
      );

      final picture = pictureRecorder.endRecording();
      final imageMarker =
          await picture.toImage(markerWidth.toInt(), markerHeight.toInt());
      final byteData =
          await imageMarker.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }
      return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
    } catch (e) {
      throw Exception('Failed to create custom marker icon: $e');
    }
  }
}
