import 'dart:math' as math;
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ServiceButtons extends StatelessWidget {
  final Function(String) onButtonPressed;
  final LatLng? currentLocation;
  final VoidCallback? onCenterPressed; // reset location / center on me
  final Future<void> Function()? onMapViewPressed;

  const ServiceButtons({
    super.key,
    required this.onButtonPressed,
    this.currentLocation,
    this.onMapViewPressed,
    this.onCenterPressed,
  });

  static const Color _purple = Color(0xFF6750A4);

  // sizes (tweak if you want scale changes)
  static const double _pillHeight = 64.0;
  static const double _smallCircleSize = 48.0;
  static const double _smallIconSize = 24.0;
  static const double _rowGap = 8.0;
  static const double _pillSpacing = 12.0;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final Color cardColor = isDarkMode ? Colors.grey[800]! : Colors.white;
    final Color iconColor = isDarkMode ? Colors.white : _purple;

    final double contentHeight =
        _pillHeight + _smallCircleSize + _rowGap + 12.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: SizedBox(
        height: contentHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- TOP ROW: MapView button ---
            SizedBox(
              height: _smallCircleSize,
              child: Row(
                children: [
                  const Spacer(),
                  Semantics(
                    label: 'Map view button',
                    hint: 'Double tap to open map view settings',
                    button: true,
                    child: Tooltip(
                      message: 'mapView'.tr(),
                      child: _buildCircularIcon(
                        context,
                        iconWidget: const Icon(Icons.layers_outlined),
                        tooltip: 'mapView'.tr(),
                        background: cardColor,
                        iconColor: iconColor,
                        onTap: () async {
                          if (onMapViewPressed != null) {
                            try {
                              await onMapViewPressed!();
                            } catch (e, st) {
                              debugPrint('onMapViewPressed threw: $e\n$st');
                            }
                          } else {
                            Navigator.pushNamed(context, '/mapviewsettings');
                          }
                        },
                        size: _smallCircleSize,
                        iconSize: _smallIconSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: _rowGap),

            // --- BOTTOM ROW: Check-in + SOS + Center ---
            SizedBox(
              height: _pillHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: 'Check-in button',
                        hint: 'Double tap to share your current location',
                        button: true,
                        child: _buildServiceButton(
                          context,
                          Icons.check_circle,
                          'checkIn'.tr(),
                          () {
                            if (currentLocation != null) {
                              Navigator.pushNamed(
                                context,
                                '/send-location',
                                arguments: {
                                  'currentLocation':
                                      currentLocation ?? const LatLng(0, 0),
                                  'isSpaceChat': false,
                                },
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('locationFetchError'.tr())),
                              );
                            }
                          },
                          cardColor,
                          iconColor,
                        ),
                      ),
                      SizedBox(width: _pillSpacing),
                      Semantics(
                        label: 'SOS button',
                        hint: 'Double tap to send an emergency alert',
                        button: true,
                        child: _buildPillButton(
                          context,
                          iconWidget:
                              const FaIcon(FontAwesomeIcons.lifeRing, size: 18),
                          label: 'sos'.tr(),
                          background: cardColor,
                          iconColor: iconColor,
                          onTap: () {
                            try {
                              onButtonPressed('SOS');
                            } catch (e) {
                              debugPrint('onButtonPressed threw: $e');
                            }
                            Navigator.pushNamed(context, '/sos');
                          },
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Semantics(
                    label: 'Reset Location',
                    hint: 'Double tap to focus on your current location',
                    button: true,
                    child: _buildCircularIcon(
                      context,
                      iconWidget: const Icon(Icons.gps_fixed_outlined),
                      tooltip: 'centerOnMe'.tr(),
                      background: cardColor,
                      iconColor: iconColor,
                      onTap: () {
                        if (onCenterPressed != null) onCenterPressed!();
                      },
                      size: _smallCircleSize,
                      iconSize: _smallIconSize,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Button builders below ---
  Widget _buildServiceButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
    Color background,
    Color iconColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: background,
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
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton(
    BuildContext context, {
    required Widget iconWidget,
    required String label,
    required Color background,
    required Color iconColor,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: background,
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
                IconTheme(
                  data: IconThemeData(color: iconColor, size: 18),
                  child: iconWidget,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularIcon(
    BuildContext context, {
    required Widget iconWidget,
    required String tooltip,
    required Color background,
    required Color iconColor,
    required VoidCallback? onTap,
    double size = 44.0,
    double iconSize = 24.0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: IconTheme(
              data: IconThemeData(color: iconColor, size: iconSize),
              child: iconWidget,
            ),
          ),
        ),
      ),
    );
  }
}
