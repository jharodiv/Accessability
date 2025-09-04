import 'dart:math' as math;

import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/checkIn/send_location_screen.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
// FontAwesome import for lifebuoy icon
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ServiceButtons extends StatelessWidget {
  final Function(String) onButtonPressed;
  final LatLng? currentLocation;
  final VoidCallback? onMapViewPressed; // Callback for Map View
  final VoidCallback? onCenterPressed; // Callback for center-on-me / GPS

  const ServiceButtons({
    super.key,
    required this.onButtonPressed,
    this.currentLocation,
    this.onMapViewPressed,
    this.onCenterPressed,
  });

  static const Color _purple = Color(0xFF6750A4);

  // pill height (keeps left side size)
  static const double _pillHeight = 60;

  // small circle size used for the RIGHT column so two stacked circles fit inside _pillHeight
  static const double _smallCircleSize = 40.0;
  static const double _smallIconSize = 25.0;
  static const double _rightIconsGap = 6.0;

  // <-- increase this to raise the right column (positive value moves it up)
  static const double _rightColumnLift = 25.0;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    final Color pillBg = isDarkMode ? Colors.grey[850]! : Colors.white;
    final Color circleBg =
        isDarkMode ? Colors.grey[850]! : Colors.white.withOpacity(0.95);

    // compute heights so parent can accommodate the taller side
    final double rightColumnHeight = _smallCircleSize * 2 + _rightIconsGap;
    final double contentHeight = math.max(_pillHeight, rightColumnHeight);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: SizedBox(
        // make container tall enough for either side
        height: contentHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // LEFT group: check-in + SOS
            Row(
              children: [
                // CHECK-IN button (keeps original behavior)
                _buildServiceButton(
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
                          content: Text('locationFetchError'.tr()),
                        ),
                      );
                    }
                  },
                  isDarkMode,
                ),

                const SizedBox(width: 12),

                // SOS pill using FaIcon, with Material + InkWell for reliable taps
                _buildPillButton(
                  context,
                  iconWidget: const FaIcon(FontAwesomeIcons.lifeRing, size: 18),
                  label: 'sos'.tr(),
                  background: pillBg,
                  iconColor: _purple,
                  onTap: () {
                    debugPrint('SOS pressed');
                    try {
                      onButtonPressed('SOS');
                    } catch (e) {
                      debugPrint('onButtonPressed threw: $e');
                    }
                    Navigator.pushNamed(context, '/sos');
                  },
                ),
              ],
            ),

            // RIGHT group: vertically centered but slightly lifted to align with SOS
            Transform.translate(
              // negative Y to lift the column up; tweak _rightColumnLift to suit
              offset: const Offset(0, -_rightColumnLift),
              child: SizedBox(
                height: contentHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        debugPrint(
                            'mapView icon tapped; scheduling parent callback or route');
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (onMapViewPressed != null) {
                            try {
                              onMapViewPressed!();
                            } catch (e, st) {
                              debugPrint('onMapViewPressed threw: $e\n$st');
                            }
                          } else {
                            try {
                              Navigator.pushNamed(context, '/mapviewsettings');
                            } catch (e, st) {
                              debugPrint(
                                  'Navigator.pushNamed(/mapviewsettings) threw: $e\n$st');
                            }
                          }
                        });
                      },
                      child: _buildCircularIcon(
                        context,
                        icon: Icons.layers,
                        tooltip: 'mapView'.tr(),
                        background: circleBg,
                        iconColor: _purple,
                        onTap: null,
                        size: _smallCircleSize,
                        iconSize: _smallIconSize,
                      ),
                    ),
                    const SizedBox(height: _rightIconsGap),
                    _buildCircularIcon(
                      context,
                      icon: Icons.gps_fixed,
                      tooltip: 'centerOnMe'.tr(),
                      background: circleBg,
                      iconColor: _purple,
                      onTap: () {
                        debugPrint('center pressed');
                        if (onCenterPressed != null) onCenterPressed!();
                      },
                      size: _smallCircleSize,
                      iconSize: _smallIconSize,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ORIGINAL service button implementation (kept visually similar)
  Widget _buildServiceButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
    bool isDarkMode,
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
      ),
    );
  }

  /// New pill builder using Material + InkWell for dependable taps
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
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  child: IconTheme(
                    data: IconThemeData(color: iconColor, size: 18),
                    child: iconWidget,
                  ),
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

  /// Circular icon builder with configurable size (used for the compact right column)
  Widget _buildCircularIcon(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required Color background,
    required Color iconColor,
    required VoidCallback? onTap,
    double size = 44.0,
    double iconSize = 24.0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: (size / 2) + 6,
        containedInkWell: true,
        highlightShape: BoxShape.circle,
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
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }
}
