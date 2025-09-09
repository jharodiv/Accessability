// lib/presentation/widgets/shimmer/shimmer_change_admin_status.dart
import 'package:flutter/material.dart';

/// Lightweight shimmer (package-free).
class _Shimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final LinearGradient gradient;
  const _Shimmer({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 1100),
    this.gradient = const LinearGradient(
      colors: [Color(0xFFEEEEEE), Color(0xFFDDDDDD), Color(0xFFEEEEEE)],
      stops: [0.1, 0.5, 0.9],
      begin: Alignment(-1.0, -0.3),
      end: Alignment(1.0, 0.3),
    ),
  }) : super(key: key);

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final dx = _ctrl.value * bounds.width * 2 - bounds.width;
            return widget.gradient.createShader(
              Rect.fromLTWH(-dx, 0, bounds.width * 3, bounds.height),
            );
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

/// simple rounded rectangle block that shimmers
class ShimmerBlock extends StatelessWidget {
  final double height;
  final double width;
  final double radius;
  const ShimmerBlock(
      {Key? key,
      required this.height,
      this.width = double.infinity,
      this.radius = 8.0})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    final base = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFECECEC),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return _Shimmer(child: base);
  }
}

/// Row that mimics a member row (avatar + name + subtitle)
class ShimmerMemberRow extends StatelessWidget {
  final double avatarSize;
  final EdgeInsets padding;
  const ShimmerMemberRow(
      {Key? key,
      this.avatarSize = 44,
      this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12)})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          ClipOval(
              child: SizedBox(
                  width: avatarSize,
                  height: avatarSize,
                  child: ShimmerBlock(
                      height: avatarSize,
                      width: avatarSize,
                      radius: avatarSize / 2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBlock(height: 14, width: double.infinity, radius: 6),
                const SizedBox(height: 8),
                FractionallySizedBox(
                    widthFactor: 0.55,
                    child: ShimmerBlock(height: 12, radius: 6)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // right-side toggle/chip placeholder
          ShimmerBlock(height: 26, width: 46, radius: 13),
        ],
      ),
    );
  }
}

/// A full-screen shimmer matching the ChangeAdminStatus layout
class ShimmerChangeAdminStatus extends StatelessWidget {
  final bool showAppBar; // allow using it as a body-only shimmer
  const ShimmerChangeAdminStatus({Key? key, this.showAppBar = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final purple = const Color(0xFF6750A4);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: showAppBar
          ? PreferredSize(
              preferredSize: const Size.fromHeight(65),
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[900]
                    : Colors.white,
                child: AppBar(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  leading: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Container(
                        width: 36,
                        height: 36,
                        child: ShimmerBlock(height: 36, width: 36, radius: 8)),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      // title shimmer
                      SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          // header row similar to your grey header
          Container(
            width: double.infinity,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[850]
                : Colors.grey[100],
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: ShimmerBlock(height: 18, width: 160, radius: 6),
          ),
          // content area with card shimmer + member rows
          Expanded(
            child: Column(
              children: [
                // top card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 18.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            height: 48,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: const [
                                Positioned(
                                    left: 28,
                                    child: ShimmerBlock(
                                        height: 32, width: 32, radius: 16)),
                                Positioned(
                                    left: 14,
                                    child: ShimmerBlock(
                                        height: 32, width: 32, radius: 16)),
                                ShimmerBlock(height: 32, width: 32, radius: 16),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                ShimmerBlock(
                                    height: 14,
                                    width: double.infinity,
                                    radius: 6),
                                SizedBox(height: 6),
                                ShimmerBlock(
                                    height: 12,
                                    width: double.infinity,
                                    radius: 6),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // a few list tiles shimmers
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemBuilder: (c, i) {
                      // first one mimic owner row with small chip on right
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                  child: ShimmerBlock(height: 14, radius: 6)),
                              const SizedBox(width: 12),
                              // owner chip placeholder
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                child: const ShimmerBlock(
                                    height: 14, width: 48, radius: 12),
                              ),
                            ],
                          ),
                        );
                      }
                      return const ShimmerMemberRow();
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: 7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
