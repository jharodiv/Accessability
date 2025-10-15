import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final IconData icon;
  final int index;
  final int activeIndex;
  final ValueChanged<int> onPressed;

  /// Optional overrides for accessibility labels/hints
  final String? semanticsLabel;
  final String? semanticsHint;

  const CustomButton({
    Key? key,
    required this.icon,
    required this.index,
    required this.activeIndex,
    required this.onPressed,
    this.semanticsLabel,
    this.semanticsHint,
  }) : super(key: key);

  String _defaultLabelForIndex(int i) {
    switch (i) {
      case 0:
        return 'Space members tab';
      case 1:
        return 'Places tab';
      case 2:
        return 'Map Content tab';
      default:
        return 'Tab $i';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = activeIndex == index;
    final String label = semanticsLabel ?? _defaultLabelForIndex(index);
    final String hint = semanticsHint ?? 'Double tap to switch to $label';

    return Semantics(
      container: true,
      button: true,
      label: label,
      hint: hint,
      // selected will be reported by many screen readers as the current state
      selected: isActive,
      onTapHint: 'Activate $label',
      child: SizedBox(
        width: 100,
        child: ElevatedButton(
          onPressed: () => onPressed(index),
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive
                ? const Color(0xFF6750A4)
                : const Color.fromARGB(255, 211, 198, 248),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(16),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : const Color(0xFF6750A4),
          ),
        ),
      ),
    );
  }
}
