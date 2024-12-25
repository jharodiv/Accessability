import 'package:flutter/material.dart';

class AuthenticationImage extends StatelessWidget {
  const AuthenticationImage({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    double imageHeight = screenHeight * 0.3;
    double imageWidth = screenWidth * 0.8; 

    return SizedBox(
      width: screenWidth,
      height: imageHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left Circle
          Positioned(
            top: 20,
            left: -(screenWidth * 0.15), 
            child: Container(
              width: screenWidth * 0.3,
              height: screenWidth * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6750A4),
              ),
            ),
          ),
          // Top Right Circle
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: screenWidth * 0.25,
              height: screenWidth * 0.25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6750A4),
              ),
            ),
          ),
          // Right Circle
          Positioned(
            top: imageHeight * 0.7,
            right: -30,
            child: Container(
              width: screenWidth * 0.2,
              height: screenWidth * 0.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6750A4),
              ),
            ),
          ),
          Positioned(
            top: 5,
            child: Image.asset(
              'assets/images/authentication/authenticationImage.png',
              width: imageWidth,
              height: imageHeight,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
