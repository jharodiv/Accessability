import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerPlaceWidget extends StatelessWidget {
  const ShimmerPlaceWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Base and highlight colors for shimmer effect
    final baseColor = Colors.grey.shade300;
    final highlightColor = Colors.grey.shade100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:
          MainAxisSize.min, // Let the column shrink to fit its children
      children: [
        // Shimmer list for places (using a fixed count for placeholder items)
        Flexible(
          fit: FlexFit.loose,
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: 5, // Display 5 placeholder items
            itemBuilder: (context, index) {
              return Column(
                children: [
                  ListTile(
                    leading: Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF6750A4),
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.place, color: Color(0xFF6750A4)),
                        ),
                      ),
                    ),
                    title: Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: Container(
                        width: double.infinity,
                        height: 16.0,
                        color: Colors.white,
                      ),
                    ),
                    trailing: Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF6750A4), // Match leading icon color
                      ),
                    ),
                  ),
                  if (index < 4)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Divider(height: 1, thickness: 0.8),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
