import 'package:flutter/material.dart';

class Accessabilityfooter extends StatefulWidget {
  final Function(bool) onOverlayChange;
  final GlobalKey locationKey;
  final GlobalKey youKey;
  final GlobalKey securityKey;
  final Function(int) onTap; // Add this line

  const Accessabilityfooter({
    super.key,
    required this.onOverlayChange,
    required this.locationKey,
    required this.youKey,
    required this.securityKey,
    required this.onTap, // Add this line
  });

  @override
  State<Accessabilityfooter> createState() => AccessabilityfooterState();
}

class AccessabilityfooterState extends State<Accessabilityfooter> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      currentIndex: currentIndex,
      onTap: (index) {
        setState(() {
          currentIndex = index;
          widget.onTap(index); // Notify parent widget of the selected index
          widget.onOverlayChange(true); // Show overlay
        });
      },
      selectedItemColor: const Color(0xFF6750A4),
      unselectedItemColor: Colors.grey,
      items: [
        BottomNavigationBarItem(
          icon: GestureDetector(
            key: widget.locationKey,
            child: const Icon(Icons.location_on),
          ),
          label: 'Location',
        ),
        BottomNavigationBarItem(
          icon: GestureDetector(
            key: widget.youKey,
            child: const Icon(Icons.bookmark),
          ),
          label: 'Favorite',
        ),
        BottomNavigationBarItem(
          icon: GestureDetector(
            key: widget.securityKey,
            child: const Icon(Icons.security_outlined),
          ),
          label: 'Safety',
        ),
      ],
    );
  }
}
