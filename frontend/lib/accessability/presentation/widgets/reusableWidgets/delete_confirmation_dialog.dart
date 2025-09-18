import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

/// Reusable confirmation dialog styled like your LogoutConfirmationDialogWidget.
class DeleteConfirmationDialogWidget extends StatelessWidget {
  final String contactName;
  final VoidCallback onConfirm;

  const DeleteConfirmationDialogWidget({
    Key? key,
    required this.contactName,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // grab dark-mode flag
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    // Build the message using translation with args, with a fallback if missing.
    String buildMessage() {
      // Preferred: localized string with placeholder, e.g. "Contact name is {0}"
      // Make sure to add an entry to your translations like:
      // "contact_name_is": "Contact name is {0}"
      final key = 'contact_name_is';
      final localized = key.tr(args: [contactName]);
      // If the localization step returns the key itself (i.e., no translation),
      // fall back to a safe literal:
      if (localized == key) {
        return 'Contact name is $contactName';
      }
      return localized;
    }

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
                  'confirm_delete'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),

                // <-- Updated message here -->
                Text(
                  buildMessage(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDarkMode ? Colors.grey[700] : Colors.grey[300],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          'cancel'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6750A4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          // call confirm callback, then pop with true
                          try {
                            onConfirm();
                          } catch (_) {}
                          Navigator.of(context).pop(true);
                        },
                        child: Text(
                          'confirm'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // floating avatar/image
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
