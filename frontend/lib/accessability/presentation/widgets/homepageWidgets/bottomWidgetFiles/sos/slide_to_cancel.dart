import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// A compact slide-to-cancel widget with the "Slide to cancel" label centered.
///
/// Usage:
/// SlideToCancel(
///   width: 300,
///   height: 56,
///   onCancel: () => _cancelSOS(),
/// );
class SlideToCancel extends StatefulWidget {
  final double width;
  final double height;
  final VoidCallback onCancel;
  final double cancelThreshold; // 0..1 (fraction of dragable area)

  const SlideToCancel({
    Key? key,
    required this.width,
    required this.height,
    required this.onCancel,
    this.cancelThreshold = 0.6,
  }) : super(key: key);

  @override
  SlideToCancelState createState() => SlideToCancelState();
}

class SlideToCancelState extends State<SlideToCancel> {
  // normalized position 0..1
  double _pos = 0.0;
  bool _isCancelling = false;

  void _updateFromDelta(double dx, double maxDrag) {
    final deltaNorm = dx / maxDrag;
    setState(() {
      _pos = (_pos + deltaNorm).clamp(0.0, 1.0);
    });
  }

  Future<void> _handlePanEnd() async {
    if (_pos >= widget.cancelThreshold) {
      setState(() => _pos = 1.0);
      // brief visual confirmation before calling cancel
      await Future.delayed(const Duration(milliseconds: 220));
      if (mounted) {
        setState(() => _isCancelling = true);
        widget.onCancel();
      }
      // reset after short delay so the widget can be reused
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _isCancelling = false;
          _pos = 0.0;
        });
      }
    } else {
      // animate back to start (simple immediate reset - AnimatedPositioned handles visual)
      setState(() => _pos = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final handleSize = widget.height - 8.0; // small padding
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final maxDrag =
            (totalWidth - handleSize - 12.0).clamp(1.0, double.infinity);
        final handleLeft = 6.0 + (_pos * maxDrag);
        final pillColor = Color.lerp(Colors.black, Colors.red, _pos)!;

        // label opacity reduces as user slides
        final labelOpacity = (1.0 - (_pos * 1.1)).clamp(0.0, 1.0);

        return GestureDetector(
          onPanUpdate: (details) {
            if (_isCancelling) return;
            _updateFromDelta(details.delta.dx, maxDrag);
          },
          onPanEnd: (_) {
            if (_isCancelling) return;
            _handlePanEnd();
          },
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // pill background (color transitions to red as you slide)
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: totalWidth,
                height: widget.height,
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
                // center label is anchored in the center of the pill
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: labelOpacity,
                    child: Text(
                      'slide_to_cancel'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              // when fully slid show a centered cancel label (optional visual)
              if (_pos > 0.95 || _isCancelling)
                Positioned.fill(
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: (_pos > 0.95 || _isCancelling) ? 1 : 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.close, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'cancel_sos'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // draggable circular handle
              AnimatedPositioned(
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                left: handleLeft,
                top: 4,
                child: Container(
                  width: handleSize,
                  height: handleSize,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      _pos > widget.cancelThreshold
                          ? Icons.check
                          : Icons.arrow_forward,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
