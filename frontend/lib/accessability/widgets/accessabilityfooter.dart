import 'package:flutter/material.dart';

class Accessabilityfooter extends StatefulWidget {
  const Accessabilityfooter({super.key});

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
        });
      },
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
        )
      ],
    );
  }
}
