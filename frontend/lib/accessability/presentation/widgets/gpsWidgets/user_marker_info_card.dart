// lib/presentation/widgets/user_marker_info_card.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  // Optional width/height so caller can control layout
  final double width;
  final double height;

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
    this.width = 280,
    this.height = 120,
  }) : super(key: key);

  String _formatTimestamp(DateTime? ts) {
    if (ts == null) return 'Unknown';
    final now = DateTime.now();
    final sameDay =
        now.year == ts.year && now.month == ts.month && now.day == ts.day;
    final hour = ts.hour % 12 == 0 ? 12 : ts.hour % 12;
    final minute = ts.minute.toString().padLeft(2, '0');
    final ampm = ts.hour >= 12 ? 'PM' : 'AM';
    if (sameDay) return 'Today, $hour:$minute $ampm';
    // short date if not today
    return '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')} $hour:$minute $ampm';
  }

  Widget _batteryWidget() {
    if (batteryPercent == null) {
      return Row(
        children: [
          const Icon(Icons.battery_unknown, size: 18, color: Colors.grey),
          const SizedBox(width: 6),
          const Text('—', style: TextStyle(fontSize: 12)),
        ],
      );
    }

    final p = batteryPercent!.clamp(0, 100);
    final Color color =
        p >= 50 ? Colors.green : (p >= 20 ? Colors.orange : Colors.red);
    final IconData icon;
    if (p >= 80) {
      icon = Icons.battery_full;
    } else if (p >= 50) {
      icon = Icons.battery_charging_full;
    } else if (p >= 20) {
      icon = Icons.battery_alert;
    } else {
      icon = Icons.battery_alert;
    }

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text('$p%', style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTimestamp(timestamp);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            // avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: profileUrl.isNotEmpty
                  ? Image.network(profileUrl,
                      width: 64, height: 64, fit: BoxFit.cover)
                  : Image.asset('assets/images/others/default_profile.png',
                      width: 64, height: 64, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // name + close
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          username,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onClose,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // distance + address (two-line)
                  Text(
                    '${distanceKm.toStringAsFixed(1)} km · $address',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),

                  const SizedBox(height: 8),

                  // small telemetry row: battery | speed | time
                  Row(
                    children: [
                      _batteryWidget(),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          const Icon(Icons.speed, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                              speedKmh != null
                                  ? '${speedKmh!.toStringAsFixed(0)} km/h'
                                  : '—',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(timeLabel,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ACTIONS REMOVED: Navigate & Details removed as requested.
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
