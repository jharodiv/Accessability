import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/checkIn/send_location_screen.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

class ServiceButtons extends StatelessWidget {
  final Function(String) onButtonPressed;
  final LatLng? currentLocation;
  final VoidCallback? onMapViewPressed; // Callback for Map View

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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildServiceButton(
          context,
          Icons.check_circle,
          'checkIn'.tr(), // Localized text
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
                SnackBar(
                  content: Text('locationFetchError'.tr()),
                ),
              );
            }
          },
          isDarkMode,
        ),
        _buildServiceButton(
          context,
          Icons.warning,
          'sos'.tr(), // Localized text
          () {
            onButtonPressed('SOS');
          },
          isDarkMode,
        ),
        _buildServiceButton(
          context,
          Icons.map,
          'mapView'.tr(), // Localized text
          () {
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isDarkMode ? Colors.white : const Color(0xFF6750A4),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : const Color(0xFF6750A4),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
