// lib/presentation/screens/gpsscreen/widgets/navigation_controls.dart
import 'package:flutter/material.dart';

class NavigationControls extends StatelessWidget {
  final bool isWheelchair;
  final bool isRouted; // optional
  final VoidCallback onReset;
  final VoidCallback onToggleFollow;
  final VoidCallback onToggleWheelchair;
  final bool isFollowing; // controls icon for follow/overview

  const NavigationControls({
    super.key,
    required this.isWheelchair,
    required this.onReset,
    required this.onToggleFollow,
    required this.onToggleWheelchair,
    required this.isFollowing,
    this.isRouted = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isRouted) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          _circularButton(Icons.close, onReset, tooltip: 'Exit navigation'),
          const SizedBox(height: 10),
          _circularButton(
            isFollowing ? Icons.zoom_out_map : Icons.navigation,
            onToggleFollow,
            tooltip: isFollowing ? 'Show overview' : 'Follow my position',
          ),
          const SizedBox(height: 10),
          _circularButton(
            isWheelchair ? Icons.accessible : Icons.accessible_forward,
            onToggleWheelchair,
            tooltip: isWheelchair
                ? 'Using wheelchair-friendly route'
                : 'Switch to wheelchair-friendly route',
            foreground: isWheelchair ? Colors.green : Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _circularButton(IconData icon, VoidCallback onTap,
      {String? tooltip, Color? foreground}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        color: foreground ?? Colors.black,
        onPressed: onTap,
        tooltip: tooltip,
      ),
    );
  }
}
