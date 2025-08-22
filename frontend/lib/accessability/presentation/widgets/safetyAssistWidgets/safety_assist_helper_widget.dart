import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class SafetyAssistHelperWidget extends StatelessWidget {
  final VoidCallback onBack;
  const SafetyAssistHelperWidget({Key? key, required this.onBack})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    return Container(
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Back arrow and title row
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: textColor),
                  onPressed: onBack,
                ),
                Expanded(
                  child: Text(
                    'safety_assist'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                GestureDetector(
                  onTap: onBack,
                  child: Icon(
                    Icons.help_outline,
                    color: isDarkMode ? Colors.white : const Color(0xFF6750A4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Image asset that covers full width
            Image.asset(
              'assets/images/others/safetyassist.png',
              width: double.infinity,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            // Paragraph 1
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'safety_assist_description_1'.tr(),
                style: TextStyle(fontSize: 16, color: textColor),
                textAlign: TextAlign.justify,
              ),
            ),
            const SizedBox(height: 16),
            // Paragraph 2
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'safety_assist_description_2'.tr(),
                style: TextStyle(fontSize: 16, color: textColor),
                textAlign: TextAlign.justify,
              ),
            ),
            const SizedBox(height: 16),
            // Paragraph 3
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'safety_assist_description_3'.tr(),
                style: TextStyle(fontSize: 16, color: textColor),
                textAlign: TextAlign.justify,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
