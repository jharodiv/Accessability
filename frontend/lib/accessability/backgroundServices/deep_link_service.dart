import 'dart:async';
import 'dart:io'; // Add this import for Platform
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart'; // For Platform and MethodChannel
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  Uri? _pendingUri;
  String? _pendingSessionCode;

  late GlobalKey<NavigatorState> navigatorKey;
  bool _deepLinkHandled = false;

  Future<void> initialize(GlobalKey<NavigatorState> key) async {
    navigatorKey = key;
    debugPrint("🔗 DeepLinkService initialized with navigatorKey");

    // Handle both types of cold starts
    // await _handleSessionColdStart(); // APK installation intent
    await _handleDeepLinkColdStart(); // Traditional deep link

    // Hot links while running
    _sub = _appLinks.uriLinkStream.listen((uri) {
      debugPrint("📡 [HOT] Runtime deep link received: $uri");
      _handleLink(uri);
    });
  }

  // Handle traditional deep link cold start (accessability://)
  Future<void> _handleDeepLinkColdStart() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint("❄️ [DEEP LINK COLD START] Detected: $initialUri");
        _pendingUri = initialUri;
      } else {
        debugPrint("❄️ [DEEP LINK COLD START] No deep link found");
      }
    } catch (e) {
      debugPrint("❌ Error in deep link cold start: $e");
    }
  }

  // CORRECTED: Handle session-based cold start from APK installation
  Future<void> _handleSessionColdStart() async {
    try {
      if (!Platform.isAndroid) return;

      debugPrint("📱 Checking for APK installation intent...");

      // Use app_links to get the initial link
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint("📦 Initial URI: $initialUri");

        // Check if this is a GitHub APK URL with session parameter
        if (_isGitHubApkUrl(initialUri)) {
          final sessionId = initialUri.queryParameters['session'];
          if (sessionId != null && sessionId.startsWith('session_')) {
            debugPrint("🔍 Found session ID from APK install: $sessionId");
            _pendingSessionCode = sessionId;
          }
        }
      } else {
        debugPrint("ℹ️ No initial URI found for session cold start");
      }
    } catch (e) {
      debugPrint("❌ Error checking session cold start: $e");
    }
  }

  // Helper method to process session from URI
  void _processSessionFromUri(Uri uri) {
    final sessionId = uri.queryParameters['session'];
    if (sessionId != null && sessionId.startsWith('session_')) {
      debugPrint("🔍 Found session ID from APK install: $sessionId");
      // Store session ID for later retrieval
      _pendingSessionCode = sessionId;
    }
  }

  // Check if URL is a GitHub APK download URL
  bool _isGitHubApkUrl(Uri uri) {
    return uri.scheme == 'https' &&
        uri.host == 'github.com' &&
        uri.path.contains('Montilla007') &&
        uri.path.contains('3Y2AAPWD') &&
        uri.path.contains('app-release.apk');
  }

  // NEW: Method to retrieve code from session (call this when needed)
  Future<String?> retrieveCodeFromPendingSession() async {
    if (_pendingSessionCode == null) return null;

    final sessionId = _pendingSessionCode!;
    debugPrint("🔐 Retrieving code for session: $sessionId");

    try {
      final code = await _getCodeFromSession(sessionId);
      if (code != null) {
        debugPrint("✅ Retrieved code from session: $code");
        _pendingSessionCode = null; // Clear after successful retrieval
        return code;
      }
    } catch (e) {
      debugPrint("❌ Error retrieving code: $e");
    }
    return null;
  }

  Future<String?> _getCodeFromSession(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('https://3-y2-aapwd-xqeh.vercel.app/api/get-code/$sessionId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['code'];
        }
      } else if (response.statusCode == 404) {
        debugPrint("❌ Session expired or not found");
      }
      return null;
    } catch (e) {
      debugPrint('Error getting code from session: $e');
      return null;
    }
  }

  void _handleLink(Uri uri) {
    if (_deepLinkHandled) return;
    if (navigatorKey.currentState == null) {
      debugPrint("⏳ Navigator not ready, queuing URI: $uri");
      _pendingUri = uri;
      return;
    }

    _deepLinkHandled = true;
    debugPrint("➡️ Handling deep link now: $uri");
    Future.delayed(const Duration(milliseconds: 300), () => _navigate(uri));
  }

  void consumePendingLinkIfAny() {
    // For session-based cold start, we need to retrieve the code first
    if (_pendingSessionCode != null && navigatorKey.currentState != null) {
      debugPrint("🚀 Consuming pending session: $_pendingSessionCode");
      // We'll retrieve the code when needed, not here
      return;
    }

    // Traditional deep link handling
    if (_pendingUri != null &&
        navigatorKey.currentState != null &&
        !_deepLinkHandled) {
      debugPrint("🚀 Consuming pending deep link: $_pendingUri");
      final uriToNavigate = _pendingUri!;
      _pendingUri = null;
      _deepLinkHandled = true;
      Future.delayed(
          const Duration(milliseconds: 300), () => _navigate(uriToNavigate));
    } else {
      debugPrint("ℹ️ No pending link to consume");
    }
  }

  void _navigate(Uri uri) {
    if (navigatorKey.currentState == null) return;
    debugPrint("➡️ Navigating based on URI: $uri");

    if (uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first.toLowerCase() == "joinspace") {
      final code = uri.queryParameters['code'];
      _navigateToJoinSpace(code);
    } else {
      navigatorKey.currentState!.pushNamed('/home');
    }
  }

  void _navigateToJoinSpace(String? code) {
    if (navigatorKey.currentState == null) return;

    if (code != null) {
      debugPrint("🎯 Navigating to join space with code: $code");
      navigatorKey.currentState!.pushNamed(
        '/joinSpace',
        arguments: {'inviteCode': code},
      );
    } else {
      debugPrint("🎯 Navigating to join space without code");
      navigatorKey.currentState!.pushNamed('/joinSpace');
    }
  }

  void dispose() {
    debugPrint("🧹 Disposing DeepLinkService");
    _sub?.cancel();
  }
}
