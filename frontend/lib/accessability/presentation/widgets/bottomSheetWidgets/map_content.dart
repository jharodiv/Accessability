import 'package:flutter/material.dart';

class MapContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Centers vertically as well
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Map Content',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center, // Centers horizontally
            children: [
              _buildLegendItem(Icons.hotel, 'Hotels'),
              _buildLegendItem(Icons.restaurant, 'Restaurants'),
              _buildLegendItem(Icons.directions_bus, 'Bus'),
              _buildLegendItem(Icons.shopping_bag, 'Shopping'),
              _buildLegendItem(Icons.shopping_cart, 'Groceries'),
              _buildLegendItem(Icons.accessible, 'PWD Services'),
            ],
          ),
          SizedBox(height: 20),
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min, // Avoids stretching
              children: [
                const Text(
                  'Wheel Chair Friendly Route',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 10),
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

  Widget _buildLegendItem(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }
}
