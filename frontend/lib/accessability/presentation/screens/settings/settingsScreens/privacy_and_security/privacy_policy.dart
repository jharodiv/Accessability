import 'package:flutter/material.dart';

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white, // Set the AppBar background color
            boxShadow: [
              BoxShadow(
                color: Colors.black26, // Shadow color
                offset: Offset(0, 1), // Horizontal and Vertical offset
                blurRadius: 2, // How much to blur the shadow
              ),
            ],
          ),
          child: AppBar(
            elevation: 0, // Remove default elevation
            leading: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4),
            ),
            title: const Text(
              'Privacy & Security',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.grey,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accessability commits to security and transparency',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                      'When you choose to use AccessAbility, you place your trust in us to handle your personal information responsibly, and we take that trust very seriously. We understand that sharing your information is a significant decision, and we are committed to upholding your confidence through our actions and policies. Transparency is at the core of everything we do, and we want to ensure you have a clear understanding of how we collect, use, and safeguard your data. \n\nOur Privacy Policy is designed to provide you with detailed insights into the information we collect, the reasons behind our data collection practices, and how this information helps us enhance your experience. Additionally, it outlines the tools and options available to you for updating, managing, and controlling your information, ensuring that you remain in charge of your data at all times. By providing clear and accessible information about our privacy practices, we aim to empower you with the knowledge needed to make informed decisions while using AccessAbility.')
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
