import 'package:flutter/material.dart';

class BottomWidgets extends StatelessWidget {
  final Function(String) onCategorySelected;
  final ScrollController scrollController;

  BottomWidgets({
    required this.onCategorySelected,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            
            children: [
              // Search bar
              TextField(
                decoration: const InputDecoration(
                  labelText: "Search Location",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // The 3 category buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => onCategorySelected("Category 1"),
                    child: Text("Category 1"),
                  ),
                  ElevatedButton(
                    onPressed: () => onCategorySelected("Category 2"),
                    child: Text("Category 2"),
                  ),
                  ElevatedButton(
                    onPressed: () => onCategorySelected("Category 3"),
                    child: Text("Category 3"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Add person button
              ElevatedButton(
                onPressed: () {
                  // Handle add person action here
                },
                child: const Text("Add Person"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}