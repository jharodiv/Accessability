import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/checkIn/send_location_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ServiceButtons extends StatelessWidget {
  final Function(String) onButtonPressed;
  final LatLng? currentLocation;

  const ServiceButtons({
    super.key,
    required this.onButtonPressed,
    this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildServiceButton(Icons.check_circle, 'Check-in', () {
          if (currentLocation != null) {
            Navigator.pushNamed(
                context,
                '/send-location',
                arguments: {
                  'currentLocation': currentLocation ?? const LatLng(0, 0),
                  'isSpaceChat': true,
                },
              );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to fetch current location.')),
            );
          }
        }),
        _buildServiceButton(Icons.warning, 'SOS', () {
          onButtonPressed('SOS');
        }),
        _buildServiceButton(Icons.accessibility, 'PWD', () {
          onButtonPressed('PWD');
        }),
      ],
    );
  }

  Widget _buildServiceButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF6750A4),
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6750A4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}