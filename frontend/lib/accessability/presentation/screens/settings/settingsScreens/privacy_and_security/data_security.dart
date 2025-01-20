import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/privacy_security_screen.dart';

class DataSecurity extends StatelessWidget {
  const DataSecurity({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: AppBar(
          leading: IconButton(
            onPressed: () {
              Navigator.pop(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PrivacySecurity()));
            },
            icon: const Icon(Icons.arrow_back),
            color: const Color(0xFF6750A4),
          ),
          title: const Text(
            'Privacy & Security',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 2,
          shadowColor: Colors.black,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Security ',
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
                    'At Accessability, data security \ncomes standard',
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
                      'At AccessAbility, your security is our top priority, and our dedicated 24/7 security team works tirelessly around the clock to safeguard you and your data. We recognize that security is a multifaceted challenge that demands robust protections across every layer of our systems. From mobile devices and communication networks to the servers that power our platform and every location where your data is stored, we take a comprehensive approach to ensure your information remains safe. To achieve this, AccessAbility implements a multi-layered security framework that combines both administrative and technical safeguards. This includes advanced 256-bit encryption to protect your data during storage and transmission, role-based access controls to ensure that only authorized personnel can handle sensitive information, and two-factor authentication to add an extra layer of protection for our internal tools. Additionally, our team undergoes regular training to stay ahead of evolving security threats, ensuring our protocols and defenses remain robust and effective. With these measures in place, we are committed to providing you with a secure and trustworthy environment for all your needs.')
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
