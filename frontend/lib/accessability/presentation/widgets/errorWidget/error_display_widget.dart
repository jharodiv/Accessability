import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';

class ErrorDisplayWidget extends StatelessWidget {
  final String title;
  final String message;

  /// Primary (right) button label and callback.
  final String? primaryLabel;
  final VoidCallback? primaryOnPressed;

  /// Secondary (left) button label and callback.
  final String? secondaryLabel;
  final VoidCallback? secondaryOnPressed;

  const ErrorDisplayWidget({
    required this.title,
    required this.message,
    this.primaryLabel,
    this.primaryOnPressed,
    this.secondaryLabel,
    this.secondaryOnPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    final bool isLegacyMode = (primaryLabel == null && secondaryLabel == null);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 5),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 24),

                // Button area
                if (isLegacyMode)
                  // Single OK button (purple)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6750A4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else
                  // Two buttons (Cancel-style + Confirm-style)
                  Row(
                    children: [
                      if (secondaryLabel != null)
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode
                                  ? Colors.grey[700]
                                  : Colors.grey[300],
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: secondaryOnPressed ??
                                () => Navigator.of(context).pop(),
                            child: Text(
                              secondaryLabel!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      if (secondaryLabel != null) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6750A4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: primaryOnPressed ??
                              () => Navigator.of(context).pop(),
                          child: Text(
                            primaryLabel ?? 'OK',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
              ],
            ),
          ),

          // Top floating icon
          Positioned(
            top: -40,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
              child: Image.asset(
                'assets/images/authentication/authenticationImage.png',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
