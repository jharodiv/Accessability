import 'package:accessability/accessability/backgroundServices/deep_link_service.dart';
import 'package:accessability/accessability/backgroundServices/distance_notification_service.dart';
import 'package:accessability/accessability/backgroundServices/place_notification_service.dart';
import 'package:accessability/accessability/backgroundServices/pwd_location_notification_service.dart';
import 'package:accessability/accessability/backgroundServices/space_member_notification_service.dart';
import 'package:accessability/accessability/data/repositories/emergency_repository.dart';
import 'package:accessability/accessability/data/repositories/place_repository.dart';
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:accessability/accessability/firebaseServices/emergency/emergency_service.dart';
import 'package:accessability/accessability/firebaseServices/place/place_service.dart';
import 'package:accessability/accessability/logic/bloc/emergency/bloc/emergency_bloc.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:accessability/accessability/services/global_tts_tap_listener.dart';
import 'package:accessability/accessability/services/semantics_app_wrapper.dart';
import 'package:accessability/accessability/services/tts_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:accessability/accessability/backgroundServices/background_service.dart';
import 'package:accessability/accessability/data/repositories/auth_repository.dart';
import 'package:accessability/accessability/data/repositories/user_repository.dart';
import 'package:accessability/accessability/firebaseServices/chat/fcm_service.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_event.dart';
import 'package:accessability/accessability/logic/bloc/user/user_bloc.dart';
import 'package:provider/provider.dart';
import 'package:accessability/accessability/router/app_router.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:accessability/firebase_options.dart';
import 'package:accessability/accessability/firebaseServices/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:accessability/accessability/backgroundServices/location_notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initializeService();
  await createNotificationChannel();

  final pwdNotificationService = PWDLocationNotificationService();
  await pwdNotificationService.initialize();

  final spaceMemberNotificationService = SpaceMemberNotificationService();
  await spaceMemberNotificationService.initialize();

  final placeNotificationService = PlaceNotificationService();
  await placeNotificationService.initialize();
  placeNotificationService.startLocationMonitoring();

  final DistanceNotificationService distanceNotificationService =
      DistanceNotificationService();
  await distanceNotificationService.initialize();
  distanceNotificationService.startLocationMonitoring();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final chatService = ChatService();
      await chatService.checkAndExpireRequests();
      print('Completed initial expiration check on app startup');
    } catch (e) {
      print('Error in initial expiration check: $e');
    }
  });

  await EasyLocalization.ensureInitialized();

  // Initialize SharedPreferences.
  final SharedPreferences sharedPreferences =
      await SharedPreferences.getInstance();

  // Load environment variables.
  try {
    await dotenv.load(fileName: '.env');
    print("Loaded API Key: ${dotenv.env['GOOGLE_API_KEY']}");
  } catch (e) {
    print("Error loading .env file: $e");
  }

  // Initialize date formatting.
  await initializeDateFormatting();

  // Initialize FCMService.
  final FCMService fcmService = FCMService(navigatorKey: navigatorKey);
  fcmService.initializeFCMListeners();

  // Initialize DeepLinkService (handles cold + warm starts)
  await DeepLinkService().initialize(navigatorKey);

  final AuthService authService = AuthService();
  final PlaceService placeService = PlaceService();

  await Future.delayed(const Duration(milliseconds: 300));
  await TtsService.instance.init(language: 'en-US', rate: 0.45);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fil'), Locale('pag')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => ThemeProvider(sharedPreferences),
          ),
          // Removed LocaleProvider since EasyLocalization now manages locale.
        ],
        child: SemanticsAppWrapper(
          child: GlobalTtsTapListener(
            requireSemantics: false,
            child: MyApp(
              sharedPreferences: sharedPreferences,
              navigatorKey: navigatorKey,
              fcmService: fcmService,
              authService: authService,
              placeService: placeService,
            ),
          ),
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppRouter _appRouter = AppRouter();
  final SharedPreferences sharedPreferences;
  final GlobalKey<NavigatorState> navigatorKey;
  final FCMService fcmService;
  final AuthService authService;
  final PlaceService placeService;

  MyApp({
    super.key,
    required this.sharedPreferences,
    required this.navigatorKey,
    required this.fcmService,
    required this.authService,
    required this.placeService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<UserBloc>(
          create: (context) => UserBloc(
            userRepository: UserRepository(
              FirebaseFirestore.instance,
              sharedPreferences,
              authService,
              placeService,
            ),
          ),
        ),
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            authRepository: AuthRepository(
              authService,
              UserRepository(
                FirebaseFirestore.instance,
                sharedPreferences,
                authService,
                placeService,
              ),
            ),
            userRepository: UserRepository(
              FirebaseFirestore.instance,
              sharedPreferences,
              authService,
              placeService,
            ),
            userBloc: context.read<UserBloc>(),
            authService: authService,
          ),
        ),
        BlocProvider<PlaceBloc>(
          create: (context) => PlaceBloc(
            placeRepository: PlaceRepository(placeService: placeService),
          ),
        ),
        BlocProvider<EmergencyBloc>(
          create: (context) => EmergencyBloc(
            emergencyRepository: EmergencyRepository(
              emergencyService: EmergencyService(),
            ),
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          Widget app = MaterialApp(
            key: ValueKey(context.locale),
            navigatorKey: navigatorKey,
            navigatorObservers: [routeObserver],
            debugShowCheckedModeBanner: false,
            locale: context.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('fil'),
              Locale('pag'),
            ],
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              ...context.localizationDelegates,
            ],
            localeResolutionCallback: (locale, supportedLocales) {
              if (locale != null &&
                  supportedLocales
                      .map((e) => e.languageCode)
                      .contains(locale.languageCode)) {
                if (locale.languageCode == 'pag') {
                  return const Locale('en'); // fallback for system UI
                }
                return locale;
              }
              return const Locale('en');
            },
            theme: _buildLightTheme(context),
            darkTheme: _buildDarkTheme(context),
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: '/',
            onGenerateRoute: _appRouter.onGenerateRoute,
            builder: (context, child) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final authBloc = context.read<AuthBloc>();
                authBloc.add(CheckAuthStatus());
              });

              // Wrap every route's widget with WillPopScope so all back actions are detected:
              return WillPopScope(
                onWillPop: () async {
                  // Speak a short phrase when the user triggers a Back (button, swipe, or hardware)
                  try {
                    TtsService.instance.speak('Going back');
                  } catch (_) {}
                  // Allow the pop to continue. Return true to let Navigator pop.
                  return true;
                },
                child: child!,
              );
            },
          );

          app = SemanticsAppWrapper(child: app);

          // Protanopia color filter matrix
          const List<double> protanopiaMatrix = [
            0.567,
            0.433,
            0,
            0,
            0,
            0.558,
            0.442,
            0,
            0,
            0,
            0,
            0.242,
            0.758,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ];

          if (themeProvider.isColorBlindMode) {
            app = ColorFiltered(
              colorFilter: const ColorFilter.matrix(protanopiaMatrix),
              child: app,
            );
          }
          return app;
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
      foregroundColor: Colors.white,
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
