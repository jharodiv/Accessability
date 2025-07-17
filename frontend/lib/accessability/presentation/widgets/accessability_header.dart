import 'package:flutter/material.dart';

class Accessabilityheader extends StatelessWidget {
  const Accessabilityheader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 10, bottom: 50),
      child: Center(
        child: Text(
          'ACCESSABILITY',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 24,
            color: Color(0xFF6750A4),
          ),
        ),
      ),
    );
  }
}
