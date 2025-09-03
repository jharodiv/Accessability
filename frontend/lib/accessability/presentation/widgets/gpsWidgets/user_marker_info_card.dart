// lib/presentation/widgets/user_marker_info_card.dart
import 'package:flutter/material.dart';

class UserMarkerInfoCard extends StatelessWidget {
  final String username;
  final String address;
  final double distanceKm;
  final String profileUrl;

  // telemetry fields are nullable now (real values expected from phone/Firestore)
  final int? batteryPercent; // 0..100 or null if unknown
  final double? speedKmh; // e.g. 12.5 (km/h) or null if unknown
  final DateTime? timestamp; // nullable

  final VoidCallback? onClose;

  // Optional width & height so caller can control layout
  final double width;
  final double? height;

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
    this.width = 300,
    this.height,
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
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor ?? Colors.grey[700]),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _batteryWidget() {
    if (batteryPercent == null) {
      return _chip(icon: Icons.battery_unknown, label: '—');
    }

    final p = batteryPercent!.clamp(0, 100);
    final Color color = p >= 50
        ? Colors.green.shade700
        : (p >= 20 ? Colors.orange : Colors.red);
    final IconData icon;
    if (p >= 80) {
      icon = Icons.battery_full;
    } else if (p >= 50) {
      icon = Icons.battery_std;
    } else {
      icon = Icons.battery_alert;
    }

    return _chip(icon: icon, label: '$p%', iconColor: color);
  }

  Widget _speedWidget() {
    final label =
        speedKmh != null ? '${speedKmh!.toStringAsFixed(0)} km/h' : '—';
    return _chip(icon: Icons.speed, label: label);
  }

  bool get _isOnline {
    if (timestamp == null) return false;
    final diff = DateTime.now().difference(timestamp!);
    // treat as online if reported within last 3 minutes
    return diff.inMinutes < 3;
  }

  Widget _leftColumn(BuildContext context) {
    // New layout: small circular status icon + "Online"/"Offline" in a single row,
    // then the enlarged centered avatar.
    const double leftColumnWidth = 96;
    const double avatarSize = 84;

    // small status dot widget so we can control size & color precisely
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

    return SizedBox(
      width: leftColumnWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // status row at the very top (dot icon + Online/Offline)
          Padding(
            padding: const EdgeInsets.only(top: 2.0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statusDot(_isOnline),
                const SizedBox(width: 6),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // larger avatar centered
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: profileUrl.isNotEmpty
                  ? Image.network(profileUrl,
                      width: avatarSize, height: avatarSize, fit: BoxFit.cover)
                  : Image.asset('assets/images/others/default_profile.png',
                      width: avatarSize, height: avatarSize, fit: BoxFit.cover),
            ),
          ),

          const SizedBox(height: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTimestampShort(timestamp);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        height: height, // use supplied height to match overlay calc
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 10, offset: Offset(0, 6))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: status at top + big avatar (centered)
            _leftColumn(context),

            const SizedBox(width: 12),

            // right column (info)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TOP ROW: timestamp at left, close at right (single row)
                  Row(
                    children: [
                      // timestamp chip (left)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(timeLabel,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // close icon (right)
                      GestureDetector(
                        onTap: onClose,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 2),
                          child: Icon(Icons.close,
                              size: 18, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // NAME (own row)
                  Text(
                    username,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // distance + address (two-line)
                  Text(
                    '${distanceKm.toStringAsFixed(1)} km · $address',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),

                  const SizedBox(height: 10),

                  // chips row: battery | speed
                  Row(
                    children: [
                      _batteryWidget(),
                      const SizedBox(width: 8),
                      _speedWidget(),
                      const Spacer(),
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

  /// Helper: show the card as a full-screen overlay/dialog.
  /// Tapping anywhere outside the card will dismiss immediately.
  /// alignment controls where the card sits (e.g. Alignment.topCenter).
  static Future<void> showOverlay(
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
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true, // tapping outside dismisses immediately
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // Tap on barrier (outside card) -> dismiss immediately
            Navigator.of(ctx).pop();
          },
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Stack(
                children: [
                  // Align the card where caller wants it
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
                        onClose: () {
                          Navigator.of(ctx).pop();
                        },
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
