import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final IconData icon;
  final int index;
  final int activeIndex;
  final ValueChanged<int> onPressed;

  const CustomButton({
    Key? key,
    required this.icon,
    required this.index,
    required this.activeIndex,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isActive = activeIndex == index;
    return SizedBox(
      width: 100,
      child: ElevatedButton(
        onPressed: () => onPressed(index),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? const Color(0xFF6750A4)
              : const Color.fromARGB(255, 211, 198, 248),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFF6750A4),
        ),
      ),
    );
  }
}
