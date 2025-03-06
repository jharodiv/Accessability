import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/gps.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/checkIn/send_location_screen.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/logic/firebase_logic/SignupModel.dart';
import 'package:AccessAbility/accessability/presentation/screens/authScreens/login_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/authScreens/signup_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/authScreens/onboarding_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/authscreens/upload_profile_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/chat_system/inbox_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/add_new_place.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settings_screen.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/sos/sos_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/splash_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/account_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/biometric/biometric_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/chat_with_support_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/preferences_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/privacy_security_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/about_screen.dart';
import 'package:AccessAbility/accessability/presentation/widgets/chatWidgets/chat_convo_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppRouter {
  Route<dynamic>? onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case '/':
        return _buildRoute(const SplashScreen(), clearStack: true);
      case SignupScreen.routeName:
        return _buildRoute(const SignupScreen());
      case '/login':
        return _buildRoute(const LoginScreen(), clearStack: true);
      case '/uploadProfilePicture':
        final args = routeSettings.arguments as SignUpModel;
        return _buildRoute(UploadProfileScreen(signUpModel: args),
            clearStack: true);
      case '/addPlace':
        return _buildRoute(const AddNewPlaceScreen());
      case '/onboarding':
        return _buildRoute(const OnboardingScreen(), clearStack: true);
      case '/homescreen':
        return _buildRoute(const GpsScreen(), clearStack: true);
      case '/account':
        return _buildRoute(const AccountScreen());
      case '/preferences':
        return _buildRoute(const PreferencesScreen());
      case '/privacy':
        return _buildRoute(const PrivacySecurity());
      case '/chatsupport':
        return _buildRoute(const ChatAndSupport());
      case '/biometric':
        return _buildRoute(const BiometricScreen());
      case '/settings':
        return _buildRoute(const SettingsScreen());
      case '/inbox':
        return _buildRoute(const InboxScreen());
      case '/sos':
        return _buildRoute(SOSScreen());
      case '/about':
        return _buildRoute(const AboutScreen());
      
      case '/send-location':
        final args = routeSettings.arguments as Map<String, dynamic>?;
        if (args == null) {
          throw ArgumentError('Arguments must not be null for /send-location route');
        }
        final currentLocation = args['currentLocation'] as LatLng;
        final isSpaceChat = args['isSpaceChat'] as bool? ?? false; // Add isSpaceChat flag
        return MaterialPageRoute(
          builder: (context) => SendLocationScreen(
            currentLocation: currentLocation,
            isSpaceChat: isSpaceChat, // Pass the isSpaceChat flag
          ),
        );

      case '/chatconvo':
        final args = routeSettings.arguments as Map<String, dynamic>?;
        if (args == null) {
          throw ArgumentError('Arguments must not be null for /chatconvo route');
        }
        final receiverUsername = args['receiverUsername'] as String;
        final receiverID = args['receiverID'] as String;
        final isSpaceChat = args['isSpaceChat'] as bool? ?? false; // Add isSpaceChat flag
        final receiverProfilePicture = args['receiverProfilePicture'] as String? ?? 'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.appspot.com/o/profile_pictures%2Fdefault_profile.png?alt=media&token=bc7a75a7-a78e-4460-b816-026a8fc341ba'; // Default image if none
        return MaterialPageRoute(
          builder: (context) => ChatConvoScreen(
            receiverUsername: receiverUsername,
            receiverID: receiverID,
            isSpaceChat: isSpaceChat, // Pass the isSpaceChat flag
          ),
          settings: routeSettings, // Pass the route settings
        );
    }
    return null;
  }

  MaterialPageRoute<Map<String, dynamic>?> _buildRoute(Widget child,
      {bool clearStack = false}) {
    return MaterialPageRoute<Map<String, dynamic>?>(
      builder: (context) {
        if (clearStack) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<Map<String, dynamic>?>(
                builder: (_) => child,
              ),
              (route) => false,
            );
          });
          return const SizedBox.shrink();
        }
        return child;
      },
    );
  }
}
