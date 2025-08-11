// lib/presentation/widgets/shimmer/shimmer_space_selection.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerSpaceSelection extends StatelessWidget {
  final bool isDark;
  final int itemCount;

  /// Optional per-tile avatar counts (1,2,3...); used only for appearance.
  final List<int>? avatarCounts;

  const ShimmerSpaceSelection({
    Key? key,
    this.isDark = false,
    this.itemCount = 4,
    this.avatarCounts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int count = math.max(0, math.min(itemCount, 4));

    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    const period = Duration(milliseconds: 1200);

    Widget _shimmerBox(
            {double height = 12, double radius = 6, double? width}) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    /// Avatar cluster that matches the real _avatarStack:
    /// - shows up to 3 avatar circles left-to-right overlapping
    /// - shows a +N badge to the right if total > 3
    Widget _avatarClusterPlaceholder(double size, int total) {
      final displayCount = math.min(total, 3);
      final overlap = size * 0.45;
      final width = size + (displayCount - 1) * (size - overlap) + 8;

      Widget _circle(double s) => Container(
            width: s,
            height: s,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          );

      return SizedBox(
        width: width,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < displayCount; i++)
              Positioned(
                left: i * (size - overlap),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: _circle(size),
                ),
              ),
            if (total > displayCount)
              Positioned(
                left: displayCount * (size - overlap),
                child: Container(
                  width: size * 0.78,
                  height: size * 0.78,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(size * 0.39),
                    border: Border.all(color: Colors.grey.shade200, width: 1.6),
                  ),
                  child: Center(
                    child: Text(
                      '+${total - displayCount}',
                      style: TextStyle(
                        fontSize: size * 0.32,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // NOTE: parent renders header pill and Create/Join buttons. This widget renders only list area.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        // "My Space" placeholder (short title)
        Padding(
          padding: const EdgeInsets.only(left: 0.0),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            leading: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              period: period,
              child: _avatarClusterPlaceholder(
                48,
                avatarCounts != null && avatarCounts!.isNotEmpty
                    ? avatarCounts![0].clamp(1, 99)
                    : 3,
              ),
            ),
            title: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              period: period,
              // shorter title width for realism
              child: Row(children: [
                _shimmerBox(height: 16, radius: 6, width: 140),
                const SizedBox(width: 8),
              ]),
            ),
          ),
        ),
        Divider(color: dividerColor, height: 1, thickness: 0.5),

        // list area — parent should wrap this widget with Expanded
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: count,
            separatorBuilder: (_, __) => Column(
              children: [
                const SizedBox(height: 4),
                Divider(height: 1, thickness: 0.5, color: dividerColor),
              ],
            ),
            itemBuilder: (context, index) {
              final pretendCount =
                  (avatarCounts != null && avatarCounts!.length > index)
                      ? math.max(1, avatarCounts![index])
                      : [3, 1, 2, 4][index % 4];

              return ListTile(
                minVerticalPadding: 0,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                leading: Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  period: period,
                  child: _avatarClusterPlaceholder(44, pretendCount),
                ),
                // short/shrunk title to match real layout (not full width)
                title: Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  period: period,
                  child: Row(children: [
                    _shimmerBox(height: 16, radius: 6, width: 120),
                    const SizedBox(width: 8),
                  ]),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}
