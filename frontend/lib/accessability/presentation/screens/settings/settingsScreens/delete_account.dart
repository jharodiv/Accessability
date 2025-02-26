import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/privacy_security_screen.dart';

class DeleteAccount extends StatefulWidget {
  const DeleteAccount({super.key});

  @override
  State<DeleteAccount> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends State<DeleteAccount> {
  bool _isConfirmed = false;

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
            'Delete Account',
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
              'Account Deletion Confirmation',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will delete your entire account and remove you from all Space on Accessability',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'By checking the box below, I confirm:',
                    style: TextStyle(fontSize: 10),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '⚫Deleting my Accessability account is permanent, cannot be undone, and will log me out of this application.\n\n⚫I will be irrevocably removed from any Space that I am a member of and my location will no longer be shared with my Space\n\n⚫Accessability will send an email with a link that must be clicked to confirm your deletion request. The email will be sent to the email address associated with your account and should arrive momentarily. The link will be active for a limited time. Please check your spam folder.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Checkbox(
                        value: _isConfirmed,
                        onChanged: (value) {
                          setState(() {
                            _isConfirmed = value!;
                          });
                        },
                      ),
                      const Text(
                        'Yes, I confirm the above',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: _isConfirmed
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Account deletion initiated'),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
