import 'package:AccessAbility/accessability/presentation/widgets/safetyAssistWidgets/teal_circle_action_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class DesignServiceRow extends StatelessWidget {
  final String assetPath; // new: path to an asset for the left icon box
  final IconData fallbackIcon;
  final String title;
  final String subtitle;
  final String numbers;
  final String primary;
  final void Function(String) onCall;
  final void Function(String) onSms;
  final Color titleColor;
  final Color subtitleColor;
  final Color numberColor;

  const DesignServiceRow({
    Key? key,
    required this.assetPath,
    required this.fallbackIcon,
    required this.title,
    required this.subtitle,
    required this.numbers,
    required this.primary,
    required this.onCall,
    required this.onSms,
    required this.titleColor,
    required this.subtitleColor,
    required this.numberColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const boxColor = Color.fromARGB(255, 246, 248, 251);

    return Padding(
      // tightened padding
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // ensures spacing
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // left block (icon + texts)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: boxColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // fallback icon if the asset can't be loaded
                          return Icon(fallbackIcon,
                              size: 26, color: const Color(0xFF1E6CBC));
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        numbers,
                        style: TextStyle(
                          color: numberColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // actions on the right
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TealCircleAction(
                icon: Icons.call,
                label: 'call'.tr(),
                onTap: () => onCall(primary),
                iconColor: const Color(0xFF6750A4),
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 8),
              TealCircleAction(
                icon: Icons.message,
                label: 'message'.tr(),
                iconColor: const Color(0xFF6750A4),
                onTap: () => onSms(primary),
                backgroundColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
