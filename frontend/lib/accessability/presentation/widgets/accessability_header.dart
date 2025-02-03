import 'package:flutter/material.dart';

class Accessabilityheader extends StatelessWidget {
  const Accessabilityheader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 10, bottom: 100),
      child: Center(
        child: Text(
          'Accessability',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF6750A4),
          ),
        ),
      ),
    );
  }
}
