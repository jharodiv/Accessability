import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class MapContent extends StatelessWidget {
  final Function(String) onCategorySelected;

  const MapContent({super.key, required this.onCategorySelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header text localized (removed 'const' so .tr() works)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'mapContentHeader'.tr(),
              style: const TextStyle(
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
              _buildLegendItem(Icons.hotel, 'legendHotel', 'Hotel'),
              _buildLegendItem(
                  Icons.restaurant, 'legendRestaurant', 'Restaurant'),
              _buildLegendItem(Icons.directions_bus, 'legendBus', 'Bus'),
              _buildLegendItem(
                  Icons.shopping_bag, 'legendShopping', 'Shopping'),
              _buildLegendItem(
                  Icons.shopping_cart, 'legendGroceries', 'Groceries'),
              _buildLegendItem(
                  Icons.accessible, 'legendPWDServices', 'PWD Services'),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'wheelChairFriendlyRoute'.tr(),
                  style: const TextStyle(
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

  // This method takes both a translation key and a fallback value.
  // The displayed text is localized, but the callback receives the fallback.
  Widget _buildLegendItem(
      IconData icon, String translationKey, String fallback) {
    return GestureDetector(
      onTap: () {
        onCategorySelected(fallback); // Pass the fallback (original value)
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
              translationKey.tr(),
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
