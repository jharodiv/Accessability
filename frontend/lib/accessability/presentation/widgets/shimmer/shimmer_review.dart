import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ReviewShimmer extends StatelessWidget {
  const ReviewShimmer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(3, (index) => _buildShimmerReviewItem()),
      ),
    );
  }

  Widget _buildShimmerReviewItem() {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Shimmer avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shimmer username
                      Container(
                        width: 120,
                        height: 16,
                        color: Colors.white,
                      ),
                      SizedBox(height: 4),
                      // Shimmer stars
                      Container(
                        width: 80,
                        height: 16,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                // Shimmer date
                Container(
                  width: 60,
                  height: 12,
                  color: Colors.white,
                ),
              ],
            ),
            SizedBox(height: 8),
            // Shimmer comment lines
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 12,
                  color: Colors.white,
                ),
                SizedBox(height: 4),
                Container(
                  width: 200,
                  height: 12,
                  color: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
