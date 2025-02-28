import 'package:flutter/material.dart';

class MapContent extends StatelessWidget {
  final Function(String) onCategorySelected; // New callback

  const MapContent({super.key, required this.onCategorySelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Map Content',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendItem(Icons.hotel, 'Hotel'),
              _buildLegendItem(Icons.restaurant, 'Restaurant'),
              _buildLegendItem(Icons.directions_bus, 'Bus'),
              _buildLegendItem(Icons.shopping_bag, 'Shopping'),
              _buildLegendItem(Icons.shopping_cart, 'Groceries'),
              _buildLegendItem(Icons.accessible, 'PWD Services'),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Wheel Chair Friendly Route',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 30,
                  height: 10,
                  color: const Color(0xFF6750A4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Updated to wrap with GestureDetector and call onCategorySelected
  Widget _buildLegendItem(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        // Call the callback with the label, assuming label matches the category in fetch logic.
        onCategorySelected(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF6750A4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
