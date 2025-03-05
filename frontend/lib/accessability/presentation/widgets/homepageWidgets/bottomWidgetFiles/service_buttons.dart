import 'package:flutter/material.dart';

class ServiceButtons extends StatelessWidget {
  final Function(String) onButtonPressed;

  const ServiceButtons({super.key, required this.onButtonPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildServiceButton(Icons.check_circle, 'Check-in'),
        _buildServiceButton(Icons.warning, 'SOS'),
        _buildServiceButton(Icons.accessibility, 'PWD'),
      ],
    );
  }

  Widget _buildServiceButton(IconData icon, String label) {
    return GestureDetector(
      onTap: () => onButtonPressed(label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF6750A4),
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6750A4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}