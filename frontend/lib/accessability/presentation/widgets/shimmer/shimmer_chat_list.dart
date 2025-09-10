import 'package:flutter/material.dart';

/// ChatListShimmer
/// - mimics the "Select Chat Rooms or Spaces" header (with right pill)
/// - Space Chats header with purple vertical bar
/// - rows: avatar circle, title, subtitle, "Space" chip (right-aligned), checkbox placeholder
/// - safe for constrained/short areas (uses LayoutBuilder + SingleChildScrollView to avoid overflow)
class ChatListShimmer extends StatefulWidget {
  final int spaceCount;
  final int peopleCount;
  final double rowHeight;
  final Color? baseColor;
  final Color? highlightColor;
  final Color accentPurple;

  const ChatListShimmer({
    Key? key,
    this.spaceCount = 4,
    this.peopleCount = 3,
    this.rowHeight = 76.0,
    this.baseColor,
    this.highlightColor,
    this.accentPurple = const Color(0xFF6750A4),
    required int itemCount,
  }) : super(key: key);

  @override
  State<ChatListShimmer> createState() => _ChatListShimmerState();
}

class _ChatListShimmerState extends State<ChatListShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Color baseColor(BuildContext ctx) =>
      widget.baseColor ??
      (Theme.of(ctx).brightness == Brightness.dark
          ? const Color(0xFF2B2B2B)
          : const Color(0xFFEAEAEA));

  Color highColor(BuildContext ctx) =>
      widget.highlightColor ??
      (Theme.of(ctx).brightness == Brightness.dark
          ? const Color(0xFF3A3A3A)
          : const Color(0xFFF6F6F6));

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Returns a Shader that slides horizontally
  Shader _slidingShader(Rect rect, BuildContext ctx) {
    final base = baseColor(ctx);
    final high = highColor(ctx);

    final double slide = rect.width * (_controller.value * 1.4 - 0.2);
    final Rect shaderRect =
        Rect.fromLTWH(slide, 0, rect.width * 1.6, rect.height);

    return LinearGradient(
      colors: [base, high, base],
      stops: const [0.18, 0.48, 0.78],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(shaderRect);
  }

  // Widget _topHeader(BuildContext ctx, double width) {
  //   final base = baseColor(ctx);
  //   return Padding(
  //     padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
  //     child: Row(
  //       children: [
  //         // left text placeholder
  //         Expanded(
  //           child: Container(
  //             height: 22,
  //             decoration: BoxDecoration(
  //               color: base,
  //               borderRadius: BorderRadius.circular(6),
  //             ),
  //           ),
  //         ),
  //         const SizedBox(width: 12),
  //         // right pill placeholder (rounded)
  //         Container(
  //           width: mathMin(110, width * 0.34),
  //           height: 34,
  //           decoration: BoxDecoration(
  //             color: base,
  //             borderRadius: BorderRadius.circular(28),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _spaceHeader(BuildContext ctx) {
    final base = baseColor(ctx);
    // small purple vertical bar + text placeholder next to it
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 8.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 28,
            decoration: BoxDecoration(
              color: widget.accentPurple,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 110,
            height: 18,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerRow(BuildContext ctx, {required bool withSpaceChip}) {
    final base = baseColor(ctx);

    return SizedBox(
      height: widget.rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Row(
          children: [
            // avatar circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: base,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // text column
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // subtitle short
                  Container(
                    height: 12,
                    width: MediaQuery.of(context).size.width * 0.45,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // "Space" chip placeholder OR invisible space
            if (withSpaceChip)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(16),
                ),
                width: 62,
                height: 32,
              )
            else
              const SizedBox(width: 62),
            const SizedBox(width: 12),
            // checkbox placeholder
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Avoid overflow: render content inside a SingleChildScrollView but limit min/max heights
  Widget _buildShimmerColumn(BuildContext ctx) {
    final children = <Widget>[];

    // // top header row
    // children.add(
    //   ShaderMask(
    //     shaderCallback: (rect) => _slidingShader(rect, ctx),
    //     blendMode: BlendMode.srcATop,
    //     child: LayoutBuilder(
    //       builder: (context, constraints) =>
    //           _topHeader(ctx, constraints.maxWidth),
    //     ),
    //   ),
    // );

    // Space Chats header
    children.add(
      ShaderMask(
        shaderCallback: (rect) => _slidingShader(rect, ctx),
        blendMode: BlendMode.srcATop,
        child: _spaceHeader(ctx),
      ),
    );

    // space rows
    for (int i = 0; i < widget.spaceCount; i++) {
      children.add(
        ShaderMask(
          shaderCallback: (rect) => _slidingShader(rect, ctx),
          blendMode: BlendMode.srcATop,
          child: _shimmerRow(ctx, withSpaceChip: true),
        ),
      );
      // spacing instead of heavy divider (matches design)
      children.add(const SizedBox(height: 2));
    }

    // small gap before People
    children.add(const SizedBox(height: 6));

    // People header (shimmer)
    children.add(
      ShaderMask(
        shaderCallback: (rect) => _slidingShader(rect, ctx),
        blendMode: BlendMode.srcATop,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
          child: Container(
            width: 110,
            height: 18,
            decoration: BoxDecoration(
              color: baseColor(ctx),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );

    // people rows
    for (int i = 0; i < widget.peopleCount; i++) {
      children.add(
        ShaderMask(
          shaderCallback: (rect) => _slidingShader(rect, ctx),
          blendMode: BlendMode.srcATop,
          child: _shimmerRow(ctx, withSpaceChip: false),
        ),
      );
      if (i < widget.peopleCount - 1) children.add(const SizedBox(height: 2));
    }

    // bottom padding
    children.add(const SizedBox(height: 12));

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  @override
  Widget build(BuildContext context) {
    // limit overall height usage so parent can lay it out safely.
    return LayoutBuilder(builder: (context, constraints) {
      // choose a max height: either available or a sane default
      final maxHeight =
          constraints.maxHeight.isFinite ? constraints.maxHeight : 520.0;

      return SizedBox(
        height: maxHeight,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (ctx, _) {
            // Wrap in scroll view to avoid overflow when container is small on smaller screens.
            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: _buildShimmerColumn(ctx),
            );
          },
        ),
      );
    });
  }
}

/// small helper to avoid importing dart:math at top-level more than once
double mathMin(double a, double b) => a < b ? a : b;
