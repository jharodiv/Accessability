import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/accessability/data/repositories/auth_repository.dart';
import 'package:frontend/accessability/data/repositories/user_repository.dart';
import 'package:frontend/accessability/firebaseServices/chat/fcm_service.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_event.dart';
import 'package:frontend/accessability/logic/bloc/user/user_bloc.dart';
import 'package:provider/provider.dart';
import 'package:frontend/accessability/router/app_router.dart';
import 'package:frontend/accessability/themes/theme_provider.dart';
import 'package:frontend/firebase_options.dart';
import 'package:frontend/accessability/firebaseServices/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize SharedPreferences
  final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
  

   try {
    await dotenv.load(fileName: '.env'); // Use absolute path for testing
    print("Loaded API Key: ${dotenv.env['GOOGLE_API_KEY']}");
  } catch (e) {
    print("Error loading .env file: $e");
  }

  await initializeDateFormatting();

  final FCMService fcmService = FCMService(navigatorKey: navigatorKey);
    fcmService.initializeFCMListeners(); // Pass the navigatorKey

  // Initialize ThemeProvider
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: MyApp(sharedPreferences: sharedPreferences,
      navigatorKey: navigatorKey),
    ),
    
  );
}

class MyApp extends StatelessWidget {
  final AppRouter _appRouter = AppRouter();
  final SharedPreferences sharedPreferences;
    final GlobalKey<NavigatorState> navigatorKey;

  MyApp({super.key, required this.sharedPreferences, required this.navigatorKey});

   @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<UserBloc>(
          create: (context) => UserBloc(UserRepository(sharedPreferences)),
        ),
        BlocProvider(
          create: (context) => AuthBloc(
            AuthRepository(AuthService()),
            context.read<UserBloc>(), AuthService()
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        initialRoute: '/',
        onGenerateRoute: _appRouter.onGenerateRoute,
        builder: (context, child) {
          // Ensure the navigation stack is properly initialized
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final authBloc = context.read<AuthBloc>();
            authBloc.add(CheckAuthStatus());
          });
          return child!;
        },
      ),
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
    textTheme: _buildHelveticaTextTheme(),
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