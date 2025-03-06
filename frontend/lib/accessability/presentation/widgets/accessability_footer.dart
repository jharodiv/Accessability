import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart'; // Import ThemeProvider

class Accessabilityfooter extends StatefulWidget {
  final Function(bool) onOverlayChange;
  final GlobalKey locationKey;
  final GlobalKey youKey;
  final GlobalKey securityKey;
  final Function(int) onTap;

  const Accessabilityfooter({
    super.key,
    required this.onOverlayChange,
    required this.locationKey,
    required this.youKey,
    required this.securityKey,
    required this.onTap,
  });

  @override
  State<Accessabilityfooter> createState() => AccessabilityfooterState();
}

class AccessabilityfooterState extends State<Accessabilityfooter> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return BottomNavigationBar(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      currentIndex: currentIndex,
      onTap: (index) {
        setState(() {
          currentIndex = index;
          widget.onTap(index); // Notify parent widget of the selected index
          widget.onOverlayChange(true); // Show overlay
        });
      },
      selectedItemColor: const Color(0xFF6750A4),
      unselectedItemColor: isDarkMode ? Colors.grey[400] : Colors.grey,
      items: [
        BottomNavigationBarItem(
          icon: GestureDetector(
            key: widget.locationKey,
            child: Icon(
              Icons.location_on,
              color: currentIndex == 0
                  ? const Color(0xFF6750A4)
                  : (isDarkMode ? Colors.grey[400] : Colors.grey),
            ),
          ),
          label: 'Location',
        ),
        BottomNavigationBarItem(
          icon: GestureDetector(
            key: widget.youKey,
            child: Icon(
              Icons.bookmark,
              color: currentIndex == 1
                  ? const Color(0xFF6750A4)
                  : (isDarkMode ? Colors.grey[400] : Colors.grey),
            ),
          ),
          label: 'Favorite',
        ),
        BottomNavigationBarItem(
          icon: GestureDetector(
            key: widget.securityKey,
            child: Icon(
              Icons.security_outlined,
              color: currentIndex == 2
                  ? const Color(0xFF6750A4)
                  : (isDarkMode ? Colors.grey[400] : Colors.grey),
            ),
          ),
          label: 'Safety',
        ),
      ],
    );
  }
}