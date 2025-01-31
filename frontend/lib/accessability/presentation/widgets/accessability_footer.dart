import 'package:flutter/material.dart';

class Accessabilityfooter extends StatefulWidget {
  final Function(bool) onOverlayChange; // Add this line

  const Accessabilityfooter({super.key, required this.onOverlayChange}); // Update constructor

  @override
  State<Accessabilityfooter> createState() => AccessabilityfooterState();
}

class AccessabilityfooterState extends State<Accessabilityfooter> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        setState(() {
          currentIndex = index;
          // Trigger the overlay change when a button is tapped
          widget.onOverlayChange(true); // Show overlay
        });
      },
      selectedItemColor: const Color(0xFF6750A4),
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.location_on),
          label: 'Location',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'You',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.security),
          label: 'Security',
        ),
      ],
    );
  }
}