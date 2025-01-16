import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/privacy_and_security/additional_data_rights.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/privacy_and_security/data_security.dart';
import 'package:frontend/accessability/presentation/screens/settings/settingsScreens/privacy_and_security/privacy_policy.dart';
import 'package:frontend/accessability/presentation/screens/settings/settings_screen.dart';

class Privacysecurity extends StatelessWidget {
  const Privacysecurity({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Navigator.pop(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()));
            },
            icon: const Icon(Icons.arrow_back)),
        title: const Text(
          'Privacy & Security',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        margin: const EdgeInsets.all(15),
        child: ListView(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.grey,
                    blurRadius: 2,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
              child: Container(
                  margin: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                image: const DecorationImage(
                                  image: AssetImage(
                                      'assets/images/settings/privacy_and_security.png'),
                                  fit: BoxFit.cover,
                                )),
                          )),
                      const Expanded(
                          child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Your privacy is our priority',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'We prioritize your privacy and security by securely storing your information, using it responsibly, and implementing advanced encryption and safeguards to protect against unauthorized access',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w300),
                          ),
                        ],
                      ))
                    ],
                  )),
            ),
            const SizedBox(height: 10),
            ListTile(
              title: const Text(
                'Data Security',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DataSecurity()));
              },
            ),
            const Divider(
              height: 0.1,
              color: Colors.black12,
            ),
            ListTile(
              title: const Text(
                'Additional Data Rights',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdditionalDataRights()));
              },
            ),
            const Divider(
              height: 0.1,
              color: Colors.black12,
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PrivacyPolicy()));
              },
              child: const ListTile(
                title: Text(
                  'Privacy Policy',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
