// lib/presentation/widgets/user_marker_info_card.dart
import 'package:flutter/material.dart';

class UserMarkerInfoCard extends StatelessWidget {
  final String username;
  final String address;
  final double distanceKm;
  final String profileUrl;
  final int? batteryPercent;
  final double? speedKmh;
  final DateTime? timestamp;
  final VoidCallback? onClose;
  final VoidCallback? onNavigate;
  final double width;
  final double? height;
  final bool isCurrentUser;

  const UserMarkerInfoCard({
    Key? key,
    required this.username,
    required this.address,
    required this.distanceKm,
    required this.profileUrl,
    this.batteryPercent,
    this.speedKmh,
    this.timestamp,
    this.onClose,
    this.onNavigate,
    this.width = 300,
    this.height,
    this.isCurrentUser = false,
  }) : super(key: key);

  String _formatTimestampShort(DateTime? ts) {
    if (ts == null) return 'Unknown';
    final now = DateTime.now();
    final sameDay =
        now.year == ts.year && now.month == ts.month && now.day == ts.day;

    final hour = ts.hour % 12 == 0 ? 12 : ts.hour % 12;
    final minute = ts.minute.toString().padLeft(2, '0');
    final ampm = ts.hour >= 12 ? 'PM' : 'AM';

    if (sameDay) return 'Today · $hour:$minute $ampm';
    final y = ts.year;
    final m = ts.month.toString().padLeft(2, '0');
    final d = ts.day.toString().padLeft(2, '0');
    return '$y-$m-$d · $hour:$minute $ampm';
  }

  Widget _chip({
    required BuildContext context,
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color:
                  iconColor ?? (isDark ? Colors.grey[300] : Colors.grey[700])),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, color: isDark ? Colors.grey[200] : Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _navigationIconButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: 'Navigate to user',
      child: GestureDetector(
        onTap: () {
          // Use the onNavigate callback if provided
          if (onNavigate != null) {
            onNavigate!();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? Colors.blue[700] : Colors.blue,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isDark ? Colors.blue[600]! : Colors.blue.shade300),
          ),
          child: Icon(Icons.navigation, size: 12, color: Colors.white),
        ),
      ),
    );
  }

  Widget _batteryWidget(BuildContext context) {
    if (batteryPercent == null) {
      return _smartChip(
          context: context, icon: Icons.battery_unknown, label: '—');
    }

    final p = batteryPercent!.clamp(0, 100);
    final Color color = p >= 50
        ? Colors.green.shade600
        : (p >= 20 ? Colors.orange : Colors.red);
    final IconData icon;

    // Use simpler icons to save space
    if (p >= 80) {
      icon = Icons.battery_full;
    } else if (p >= 50) {
      icon = Icons.battery_std;
    } else if (p >= 20) {
      icon = Icons.battery_alert;
    } else {
      icon = Icons.battery_alert; // Critical battery
    }

    // Use shorter label for better fit
    final String label = p >= 100 ? '100%' : '$p%';

    return _smartChip(
        context: context, icon: icon, label: label, iconColor: color);
  }

  Widget _speedWidget(BuildContext context) {
    if (speedKmh == null) {
      return _smartChip(context: context, icon: Icons.speed, label: '—');
    }

    // Use shorter format for speed
    final String label;
    if (speedKmh! < 1) {
      label = '0';
    } else if (speedKmh! < 10) {
      label = '${speedKmh!.toStringAsFixed(0)}'; // No decimal for low speeds
    } else {
      label = speedKmh != null ? '${speedKmh!.toStringAsFixed(0)} km/h' : '—';
    }

    return _smartChip(context: context, icon: Icons.speed, label: label);
  }

  Widget _smartChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxWidth: 60, // Maximum width to prevent overflow
        minWidth: 30, // Minimum width for very short content
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 12,
              color:
                  iconColor ?? (isDark ? Colors.grey[300] : Colors.grey[700])),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[200] : Colors.black),
              overflow: TextOverflow.clip, // Prevent text overflow
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  bool get _isOnline {
    if (timestamp == null) return false;
    final diff = DateTime.now().difference(timestamp!);
    return diff.inMinutes < 3;
  }

  Widget _leftColumn(BuildContext context) {
    const double leftColumnWidth = 96;
    const double avatarSize = 84;

    Widget _statusDot(bool online) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: online ? Colors.green : Colors.grey,
          shape: BoxShape.circle,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: leftColumnWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statusDot(_isOnline),
                const SizedBox(width: 6),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: profileUrl.isNotEmpty
                  ? Image.network(profileUrl, fit: BoxFit.cover)
                  : Image.asset(
                      'assets/images/others/default_profile.png',
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeLabel = _formatTimestampShort(timestamp);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black45 : Colors.black26,
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _leftColumn(context),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row with timestamp and close button
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[850]
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time,
                                  size: 14,
                                  color:
                                      isDark ? Colors.grey[400] : Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  timeLabel,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.black),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: 'Close Button',
                        child: GestureDetector(
                          onTap: onClose,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.close,
                                size: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700]),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Username
                  Text(
                    username,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Distance and address
                  Text(
                    '${distanceKm.toStringAsFixed(1)} km · $address',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),

                  // Bottom row with status chips and navigation button
                  Row(
                    children: [
                      Flexible(
                        flex: 1,
                        child: _batteryWidget(context),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        flex: 1,
                        child: _speedWidget(context),
                      ),
                      const SizedBox(width: 4),
                      // NEW: Conditionally show navigation button
                      if (!isCurrentUser) _navigationIconButton(context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<String?> showOverlay(
    BuildContext context, {
    required String username,
    required String address,
    required double distanceKm,
    required String profileUrl,
    int? batteryPercent,
    double? speedKmh,
    DateTime? timestamp,
    double width = 300,
    double? height,
    Alignment alignment = Alignment.topCenter,
    bool isCurrentUser = false,
  }) {
    return showDialog<String?>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(ctx).pop('close'),
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Stack(
                children: [
                  Align(
                    alignment: alignment,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: UserMarkerInfoCard(
                        username: username,
                        address: address,
                        distanceKm: distanceKm,
                        profileUrl: profileUrl,
                        batteryPercent: batteryPercent,
                        speedKmh: speedKmh,
                        timestamp: timestamp,
                        width: width,
                        height: height,
                        isCurrentUser: isCurrentUser,
                        onClose: () => Navigator.of(ctx).pop('close'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
