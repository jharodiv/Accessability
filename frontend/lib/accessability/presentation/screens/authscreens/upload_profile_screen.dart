import 'package:flutter/material.dart';

class UploadProfileScreen extends StatefulWidget {
  @override
  State<UploadProfileScreen> createState() => _UploadPictureScreenState();
}

class _UploadPictureScreenState extends State<UploadProfileScreen> {
  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(height: screenHeight * 0.08),
                      Text(
                        'CRYPTOTEL',
                        style: TextStyle(
                          color: const Color.fromARGB(255, 29, 53, 115),
                          fontSize: screenHeight * 0.03,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.25),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                        child: Text(
                          'Please upload your profile picture.',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: screenHeight * 0.018,
                            fontWeight: FontWeight.w300,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.05),
                      _buildProfilePicture(screenHeight),
                      SizedBox(height: screenHeight * 0.03),
                      SizedBox(
                        width: screenWidth * 0.8,
                        height: screenHeight * 0.07,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 29, 53, 115),
                          ),
                          onPressed: () {},
                          child: const Text(
                            'Upload Picture',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.03),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 29, 53, 115),
                  ),
                  onPressed: () {},
                  child: const Text(
                    'Finish',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePicture(double screenHeight) {
    return Container(
      width: screenHeight * 0.18,
      height: screenHeight * 0.18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color.fromARGB(255, 29, 53, 115),
      ),
      child: Icon(
        Icons.person,
        size: screenHeight * 0.1,
        color: const Color.fromARGB(255, 29, 53, 115),
      ),
    );
  }
}
