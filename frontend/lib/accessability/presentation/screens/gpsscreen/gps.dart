import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/widgets/accessability_footer.dart';
import 'package:frontend/accessability/presentation/widgets/homepagewidgets/top_widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GpsScreen extends StatefulWidget {
  const GpsScreen({super.key});

  @override
  _GpsScreenState createState() => _GpsScreenState();
}

class _GpsScreenState extends State<GpsScreen> {
  OverlayEntry? _overlayEntry;
  static const LatLng _pDagupan = LatLng(16.0430, 120.3333);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Dummy Map Representation
          const GoogleMap(
            initialCameraPosition: CameraPosition(target: _pDagupan, zoom: 13),
          ),
          Topwidgets(
            onOverlayChange: (isVisible) {
              setState(() {
                if (isVisible) {
                  _showOverlay(context);
                } else {
                  _removeOverlay();
                }
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: const Accessabilityfooter(),
    );
  }

  void _showOverlay(BuildContext context) {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        top: 70,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Column(
              children:
                  ['Circle One', 'Circle Two', 'Circle Three'].map((option) {
                return GestureDetector(
                  onTap: () {
                    debugPrint('$option selected');
                    _removeOverlay();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Text(
                      option,
                      style: const TextStyle(
                        color: Color(0xFF6750A4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
