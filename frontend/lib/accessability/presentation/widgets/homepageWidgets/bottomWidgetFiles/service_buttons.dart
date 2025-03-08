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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribute space evenly
      children: [
        _buildServiceButton(
          context,
          Icons.check_circle,
          'Check-in',
          () {
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
                  content: Text('Unable to fetch current location.'),
                ),
              );
            }
          },
          isDarkMode,
        ),
        _buildServiceButton(
          context,
          Icons.warning,
          'SOS',
          () {
            onButtonPressed('SOS');
          },
          isDarkMode,
        ),
        _buildServiceButton(
          context,
          Icons.map,
          'Map View',
          () {
            // Use the provided callback if available
            if (onMapViewPressed != null) {
              onMapViewPressed!();
            } else {
              Navigator.pushNamed(context, '/mapviewsettings');
            }
          },
          isDarkMode,
        ),
      ],
    );
  }

  Widget _buildServiceButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
    bool isDarkMode,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), // Adjust padding
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
            mainAxisAlignment: MainAxisAlignment.center, // Center content
            children: [
              Icon(
                icon,
                color: isDarkMode ? Colors.white : const Color(0xFF6750A4),
                size: 18,
              ),
              const SizedBox(width: 8), // Reduce spacing between icon and text
              Text(
                label,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : const Color(0xFF6750A4),
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // Adjust font size for smaller screens
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}