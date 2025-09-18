import 'dart:math';
import 'package:flutter/material.dart';

class SquareProfile extends StatelessWidget {
  /// Total square size (height and width)
  final double size;

  /// optional network image URL
  final String? imageUrl;

  /// used when imageUrl is null or fails
  final String initial;

  /// square background (outer area)
  final Color backgroundColor;

  /// main circle color (and outer ring color)
  final Color circleColor;

  /// text style for the initial
  final TextStyle? initialStyle;

  const SquareProfile({
    Key? key,
    required this.size,
    this.imageUrl,
    required this.initial,
    this.backgroundColor = const Color(0xFFEFF7F6),
    this.circleColor = const Color(0xFF01796F), // teal-ish default
    this.initialStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double padding = size * 0.06;
    final double circleDiameter = size * 0.62;
    final double ringWidth = max(4.0, size * 0.06);
    final double pointerSize = max(10.0, size * 0.08);

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(size * 0.08), // slightly rounded square
        child: Container(
          color: backgroundColor,
          padding: EdgeInsets.all(padding),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Center column: circle + pointer
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Circle with same-color outer ring
                  Container(
                    width: circleDiameter + ringWidth,
                    height: circleDiameter + ringWidth,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: circleColor, // outer ring color (same as inner)
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: circleDiameter,
                        height: circleDiameter,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors
                              .white, // inner background for image/initial
                        ),
                        child: ClipOval(
                          child: _buildInnerContent(circleDiameter),
                        ),
                      ),
                    ),
                  ),

                  // small gap between circle and pointer
                  SizedBox(height: pointerSize * 0.1),

                  // diamond pointer (rotated square)
                  Transform.rotate(
                    angle: pi / 4,
                    child: Container(
                      width: pointerSize,
                      height: pointerSize,
                      decoration: BoxDecoration(
                        color: circleColor,
                        // match same-color ring
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInnerContent(double diameter) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _fallbackInitial(diameter);
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
      );
    } else {
      return _fallbackInitial(diameter);
    }
  }

  Widget _fallbackInitial(double diameter) {
    return Container(
      width: diameter,
      height: diameter,
      color: Colors.transparent,
      alignment: Alignment.center,
      child: Text(
        initial.isNotEmpty ? initial[0].toUpperCase() : '',
        style: initialStyle ??
            TextStyle(
              fontSize: diameter * 0.42,
              fontWeight: FontWeight.w600,
              color: circleColor,
            ),
      ),
    );
  }
}
