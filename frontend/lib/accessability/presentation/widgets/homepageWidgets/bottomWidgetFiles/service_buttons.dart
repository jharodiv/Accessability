import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/checkIn/send_location_screen.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class ServiceButtons extends StatelessWidget {
  final Function(String) onButtonPressed;
  final LatLng? currentLocation;
  final VoidCallback? onMapViewPressed; // Added callback for Map View

  const ServiceButtons({
    super.key,
    required this.onButtonPressed,
    this.currentLocation,
    this.onMapViewPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

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
                'isSpaceChat': false,
              },
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Unable to fetch current location.')),
            );
          }
        }, isDarkMode),
        _buildServiceButton(Icons.warning, 'SOS', () {
          onButtonPressed('SOS');
        }, isDarkMode),
        _buildServiceButton(Icons.map, 'Map View', () {
          // Use the provided callback if available
          if (onMapViewPressed != null) {
            onMapViewPressed!();
          } else {
            Navigator.pushNamed(context, '/mapviewsettings');
          }
        }, isDarkMode),
      ],
    );
  }

  Widget _buildServiceButton(
      IconData icon, String label, VoidCallback onTap, bool isDarkMode) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.white,
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
              color: isDarkMode ? Colors.white : const Color(0xFF6750A4),
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isDarkMode ? Colors.white : const Color(0xFF6750A4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
