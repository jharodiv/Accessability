import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerMemberList extends StatelessWidget {
  final bool isDark;
  final int itemCount; // number of member rows to show as placeholders

  const ShimmerMemberList({
    Key? key,
    this.isDark = false,
    this.itemCount = 3,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    Widget _line(double w, double h, {double radius = 6}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    Widget _avatar(double size) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // -- Header / "current user" skeleton matching design --
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.0),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            leading: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              period: const Duration(milliseconds: 1200),
              child: _avatar(48),
            ),
            title: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              period: const Duration(milliseconds: 1200),
              child: _line(200, 18),
            ),
            subtitle: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              period: const Duration(milliseconds: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _line(double.infinity, 12),
                  const SizedBox(height: 6),
                  _line(160, 12),
                  const SizedBox(height: 6),
                  _line(120, 12),
                ],
              ),
            ),
          ),
        ),
        Divider(color: dividerColor),

        // -- Member rows skeleton --
        Flexible(
          fit: FlexFit.loose,
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              return Column(
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16.0),
                    leading: Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      period: const Duration(milliseconds: 1200),
                      child: _avatar(44),
                    ),
                    title: Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      period: const Duration(milliseconds: 1200),
                      child: _line(180, 16),
                    ),
                    subtitle: Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      period: const Duration(milliseconds: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _line(double.infinity, 12),
                          const SizedBox(height: 6),
                          _line(140, 12),
                          const SizedBox(height: 6),
                          _line(90, 12), // updated: small width
                        ],
                      ),
                    ),
                    trailing: Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      period: const Duration(milliseconds: 1200),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (index < itemCount - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Divider(
                          height: 1, thickness: 0.8, color: dividerColor),
                    ),
                ],
              );
            },
          ),
        ),

        // -- Add a person CTA skeleton that visually matches the design --
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            children: [
              Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                period: const Duration(milliseconds: 1200),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  period: const Duration(milliseconds: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _line(160, 18),
                      const SizedBox(height: 8),
                      _line(220, 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
