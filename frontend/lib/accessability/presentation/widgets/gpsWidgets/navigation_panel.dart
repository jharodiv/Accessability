// lib/presentation/screens/gpsscreen/widgets/navigation_info_panel.dart
import 'package:flutter/material.dart';

class NavigationInfoPanel extends StatelessWidget {
  final double bottomOffset;
  final bool isWheelchair;
  final Future<String> Function() getDestinationName;
  final Future<double> Function() getRemainingKm;
  final void Function(double delta) onDragUpdate;
  final VoidCallback onDragReset;

  const NavigationInfoPanel({
    Key? key,
    required this.bottomOffset,
    required this.isWheelchair,
    required this.getDestinationName,
    required this.getRemainingKm,
    required this.onDragUpdate,
    required this.onDragReset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Note: bottomOffset is provided for parent to position this widget;
    // this widget itself doesn't reposition via bottomOffset (parent does).
    return GestureDetector(
      onVerticalDragUpdate: (details) => onDragUpdate(details.delta.dy),
      onVerticalDragEnd: (_) => onDragReset(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // small drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Route type row
            Row(
              children: [
                Icon(
                  isWheelchair ? Icons.accessible : Icons.directions_car,
                  color: isWheelchair ? Colors.green : const Color(0xFF6750A4),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isWheelchair
                        ? 'Wheelchair-friendly route'
                        : 'Standard route',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color:
                          isWheelchair ? Colors.green : const Color(0xFF6750A4),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Destination name
            FutureBuilder<String>(
              future: getDestinationName(),
              builder: (context, snapshot) {
                final text = snapshot.connectionState == ConnectionState.waiting
                    ? 'Calculating...'
                    : (snapshot.hasData && snapshot.data!.isNotEmpty
                        ? snapshot.data!
                        : 'Destination');
                return Text(
                  text,
                  style: const TextStyle(fontSize: 14),
                );
              },
            ),

            const SizedBox(height: 8),

            // Remaining distance
            FutureBuilder<double>(
              future: getRemainingKm(),
              builder: (context, snapshot) {
                final txt = (snapshot.connectionState ==
                        ConnectionState.waiting)
                    ? 'Calculating...'
                    : (snapshot.hasData
                        ? 'Distance remaining: ${snapshot.data!.toStringAsFixed(1)} km'
                        : 'Distance remaining: —');
                return Text(
                  txt,
                  style: const TextStyle(fontSize: 14),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
