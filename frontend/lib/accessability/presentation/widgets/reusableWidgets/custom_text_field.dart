import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final FocusNode? focusNode;
  final bool isDarkMode;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.focusNode,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      focusNode: focusNode,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black, // Text color
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600], // Hint text color
        ),
        filled: true,
        fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200], // Background color
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey, // Border color
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(
            color: isDarkMode ? const Color(0xFF6750A4) : Colors.blue, // Focused border color
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
      ),
    );
  }
}