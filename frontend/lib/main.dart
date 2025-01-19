import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/accessability/router/app_router.dart';
import 'package:frontend/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

var kColorScheme = ColorScheme.fromSeed(seedColor: Colors.white);
var kDarkColorScheme = ColorScheme.fromSeed(seedColor: Colors.black);

class MyApp extends StatelessWidget {
  final AppRouter _appRouter = AppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      theme: _buildLightTheme(context),
      darkTheme: _buildDarkTheme(context), // Add dark theme here
      themeMode: ThemeMode.system, // Switches based on system theme
      onGenerateRoute: _appRouter.onGenerateRoute,
    );
  }
}

ThemeData _buildLightTheme(BuildContext context) {
  return ThemeData(
    primaryColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color.fromARGB(255, 255, 255, 255),
    ),
    useMaterial3: true,
    listTileTheme: const ListTileThemeData(
      textColor: Colors.black,
      iconColor: Colors.black,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      backgroundColor: Colors.white,
    ),
    textTheme: _buildHelveticaTextTheme(),
  );
}

ThemeData _buildDarkTheme(BuildContext context) {
  return ThemeData(
    primaryColor: Colors.black,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color.fromARGB(255, 0, 0, 0),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    listTileTheme: const ListTileThemeData(
      textColor: Colors.white,
      iconColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    ),
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      backgroundColor: Colors.black,
    ),
    textTheme: _buildHelveticaTextTheme().apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
  );
}

TextTheme _buildHelveticaTextTheme() {
  return const TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
    displaySmall: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 20,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 18,
      fontWeight: FontWeight.normal,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 16,
      fontWeight: FontWeight.normal,
    ),
    bodySmall: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 14,
      fontWeight: FontWeight.normal,
    ),
    labelLarge: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
    labelMedium: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 14,
      fontWeight: FontWeight.bold,
    ),
    labelSmall: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 12,
      fontWeight: FontWeight.bold,
    ),
  );
}
