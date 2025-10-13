import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:easy_localization/easy_localization.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    final List<Map<String, String>> faqs = [
      {
        "question": "What is this app Designed for?",
        "answer":
            "This app is created to help Persons with Disabilities (PWDs) and their families navigate safely and confidently. It provides wheelchair-friendly routes, real-time GPS navigation, and communication tools for everyday travel and outdoor exploration."
      },
      {
        "question": "How can I find wheelchair-friendly routes?",
        "answer":
            "Simply enable your location, set your destination, and the app will automatically recommend routes verified as accessible — including paths with ramps, elevators, and safe sidewalks."
      },
      {
        "question": "Can I use the app to mark accessible places?",
        "answer":
            "Yes! You can mark and save locations such as PWD-friendly restaurants, restrooms, and parking spots. These marked places also help other users discover accessible locations nearby."
      },
      {
        "question": "What if I need help during a trip?",
        "answer":
            "The app includes an emergency feature that instantly alerts your trusted contacts or local authorities with your live location when activated. This ensures quick assistance during emergencies."
      },
      {
        "question": "Does the app work offline?",
        "answer":
            "Currently, an internet connection is required for real-time navigation and accessibility data. However, you can still view previously saved locations offline."
      },
      {
        "question": "How do I use the communication tools?",
        "answer":
            "You can use text-to-speech to read messages aloud or speech-to-text to send messages hands-free — ideal for users with limited mobility or speech difficulties."
      },
      {
        "question": "Can family members track or assist users?",
        "answer":
            "Yes. With your permission, family members or caregivers can view your location, receive safety alerts, and communicate through the in-app tools."
      },
      {
        "question": "Is my data and location information secure?",
        "answer":
            "Absolutely. All data is encrypted and stored securely. Your personal and location information is never shared without your consent."
      },
      {
        "question": "Can I report inaccessible areas or hazard",
        "answer":
            "Yes. You can report issues directly through the app to help improve the community’s map accuracy and make outdoor navigation safer for everyone."
      },
      {
        "question": "How can I navigate through the app?",
        "answer":
            "Navigating through the app is simple and user-friendly. You can search for destinations, mark locations, and explore wheelchair-friendly routes with ease. We’ve also designed an intelligent navigation AI that assists you in finding the safest and most accessible paths tailored for Persons with Disabilities (PWDs)."
      }
    ];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: AppBar(
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4),
            ),
            title: Text(
              'FAQ'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var faq in faqs)
              _CustomFAQTile(
                question: faq["question"]!,
                answer: faq["answer"]!,
                isDarkMode: isDarkMode,
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomFAQTile extends StatefulWidget {
  final String question;
  final String answer;
  final bool isDarkMode;

  const _CustomFAQTile({
    required this.question,
    required this.answer,
    required this.isDarkMode,
  });

  @override
  State<_CustomFAQTile> createState() => _CustomFAQTileState();
}

class _CustomFAQTileState extends State<_CustomFAQTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Colors.grey,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: widget.isDarkMode
                        ? Colors.white
                        : const Color(0xFF6750A4),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.answer,
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
