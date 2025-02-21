import 'package:flutter/material.dart';

class Accessabilityfooter extends StatefulWidget {
  final Function(bool) onOverlayChange;
  final GlobalKey locationKey;
  final GlobalKey youKey;
  final GlobalKey securityKey;

  const Accessabilityfooter({
    super.key,
    required this.onOverlayChange,
    required this.locationKey,
    required this.youKey,
    required this.securityKey,
  });

  @override
  State<Accessabilityfooter> createState() => AccessabilityfooterState();
}

class AccessabilityfooterState extends State<Accessabilityfooter> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.white, // Set background to white
      currentIndex: currentIndex,
      onTap: (index) {
        setState(() {
          currentIndex = index;
          widget.onOverlayChange(true); // Show overlay
        });
      },
      selectedItemColor: const Color(0xFF6750A4),
      unselectedItemColor: Colors.grey,
      items: [
        BottomNavigationBarItem(
          icon: GestureDetector(
            key: widget.locationKey, // Assign the key here
            child: const Icon(Icons.location_on),
          ),
          label: 'Location',
        ),
        BottomNavigationBarItem(
          icon: GestureDetector(
            key: widget.youKey, // Assign the key here
            child: const Icon(Icons.person),
          ),
          label: 'You',
        ),
        BottomNavigationBarItem(
          icon: GestureDetector(
            key: widget.securityKey, // Assign the key here
            child: const Icon(Icons.security),
          ),
          label: 'Security',
        ),
      ],
    );
  }
}
