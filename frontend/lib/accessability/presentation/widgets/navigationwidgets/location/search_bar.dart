import 'package:flutter/material.dart';

class SearchBar extends StatelessWidget {
  const SearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Text to Speech, Speech to Text',
              hintStyle: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF6750A4)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.mic,
                  color: Color(0xFF6750A4),
                ),
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}
