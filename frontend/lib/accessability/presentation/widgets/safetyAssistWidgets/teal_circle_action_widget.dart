import 'package:flutter/material.dart';

class TealCircleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor; // new - color of the icon inside the circle
  final Color backgroundColor; // circle bg color
  final double size;

  const TealCircleAction({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.iconColor,
    this.backgroundColor = const Color(0xFFEFFAF8),
    this.size = 44,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF6750A4), width: 1),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}
