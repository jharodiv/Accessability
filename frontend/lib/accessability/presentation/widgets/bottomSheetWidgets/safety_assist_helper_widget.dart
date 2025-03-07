import 'package:flutter/material.dart';

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
          // Center the children horizontally
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
                    'Safety Assist',
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
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 16),
            // Paragraph 1 with added padding and left text alignment
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'AccessAbility prioritizes your safety and peace of mind by offering a feature that allows you to designate safety contacts within the app. These contacts can be trusted family members, friends, or caregivers who will be notified in case of an emergency. The app allows you to easily add, update, or remove safety contacts, ensuring that the people who matter most to you are always informed and ready to assist when needed.',
                style: TextStyle(fontSize: 16, color: textColor),
                textAlign: TextAlign.left,
              ),
            ),
            const SizedBox(height: 16),
            // Paragraph 2 with added padding and left text alignment
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'In the event of an emergency, you can quickly activate the SOS feature, which sends an instant alert to all your designated safety contacts. This alert includes your real-time location and any other critical information that can help your contacts respond quickly. By keeping your safety contacts updated, you ensure that help is just a few taps away, no matter where you are.',
                style: TextStyle(fontSize: 16, color: textColor),
                textAlign: TextAlign.left,
              ),
            ),
            const SizedBox(height: 16),
            // Paragraph 3 with added padding and left text alignment
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'The SOS feature offers peace of mind by ensuring that everyone under your safety contact list receives the alert when activated. This means that in case of an emergency, all your contacts are informed simultaneously, allowing for a coordinated response. With AccessAbility, your safety is always a priority, and the app helps you stay connected to those who can provide support in critical moments.',
                style: TextStyle(fontSize: 16, color: textColor),
                textAlign: TextAlign.left,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
