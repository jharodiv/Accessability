import 'package:flutter/material.dart';

class AdditionalDataRights extends StatelessWidget {
  const AdditionalDataRights({super.key});

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
              'Additional Data Rights',
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
              child: RichText(
                text: const TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    children: [
                      TextSpan(
                          text:
                              'Here you may exercise your additional data rights. You may:\n',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      TextSpan(
                        text:
                            '\n⚫Request to delete your account. To proceed, please the',
                      ),
                      TextSpan(
                        text: ' Delete Your Account ',
                        style: TextStyle(color: Colors.red),
                      ),
                      TextSpan(
                          text:
                              'button. \n\n ⚫You may exercise your rights by emailing us at accessability@gmail.com and including your full account name and phone number and the nature of your request.\n\n⚫You may have additional rights under applicable law. as described in our Privacy Policy.'),
                    ]),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Container(
              color: Colors.red, // Set the background color to red
              child: ListTile(
                onTap: () {
                  // Add your onTap functionality here
                },
                title: const Text(
                  'Delete Account',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white, // Set the text color to white
                  ),
                ),
              ),
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }
}
