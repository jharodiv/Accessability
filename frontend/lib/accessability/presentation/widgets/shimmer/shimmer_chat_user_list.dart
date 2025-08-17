// chat_users_list_shimmer.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerChatUserList extends StatelessWidget {
  final bool isDarkMode;
  final int itemCount;
  final bool showSectionHeaders;
  final bool showTopTitle;
  final double topTitleWidth;
  final EdgeInsetsGeometry padding;

  const ShimmerChatUserList({
    Key? key,
    this.isDarkMode = false,
    this.itemCount = 6,
    this.showSectionHeaders = true,
    this.showTopTitle = true,
    this.topTitleWidth = 160,
    this.padding = const EdgeInsets.symmetric(vertical: 8.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final baseColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[500]! : Colors.grey[100]!;

    final totalCount = itemCount + (showTopTitle ? 1 : 0);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.separated(
        padding: padding,
        itemCount: totalCount,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          // Top shimmer title
          if (showTopTitle && index == 0) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: topTitleWidth,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          }

          // Adjust index if top title is shown
          final tileIndex = showTopTitle ? index - 1 : index;

          // Optionally insert a section header before the middle item
          if (showSectionHeaders && tileIndex == (itemCount ~/ 2)) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // section header shimmer
                  Container(
                    width: 120,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _shimmerListTile(context),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: _shimmerListTile(context),
          );
        },
      ),
    );
  }

  Widget _shimmerListTile(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double titleWidth = screenWidth * 0.45;
    final double subtitleWidth = screenWidth * 0.35;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar circle
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        // Title + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title placeholder
              Container(
                width: titleWidth,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle placeholder
              Container(
                width: subtitleWidth,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Trailing time placeholder
        Container(
          width: 48,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
