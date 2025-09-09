// lib/presentation/widgets/shimmer/shimmer_remove_members.dart
import 'package:flutter/material.dart';

/// Lightweight shimmer (package-free) reused for remove-members screen.
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
  const ShimmerBlock({
    Key? key,
    required this.height,
    this.width = double.infinity,
    this.radius = 8.0,
  }) : super(key: key);

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

/// small row shimmer that matches RemoveMemberListTile layout
class ShimmerRemoveMemberRow extends StatelessWidget {
  final double avatarSize;
  final EdgeInsets padding;
  const ShimmerRemoveMemberRow({
    Key? key,
    this.avatarSize = 44,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  }) : super(key: key);

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
                  radius: avatarSize / 2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBlock(height: 14, width: double.infinity, radius: 6),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: 0.55,
                  child: ShimmerBlock(height: 12, radius: 6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ShimmerBlock(height: 28, width: 28, radius: 14),
        ],
      ),
    );
  }
}

/// Full screen shimmer used while member data loads inside RemoveMembersScreen.
class ShimmerRemoveMembers extends StatelessWidget {
  final int rows;
  const ShimmerRemoveMembers({Key? key, this.rows = 6}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final items = List<Widget>.generate(
      rows,
      (_) => const ShimmerRemoveMemberRow(),
    );
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const SizedBox(height: 14),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemBuilder: (_, i) => items[i % items.length],
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: rows,
          ),
        ),
      ],
    );
  }
}
