import 'dart:async';
import 'dart:convert';
import 'package:accessability/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();

  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Uri? _pendingUri;
  bool _deepLinkHandled = false;
  late GlobalKey<NavigatorState> navigatorKey;

  /// Initialize the deep link listener
  Future<void> initialize(GlobalKey<NavigatorState> key) async {
    navigatorKey = key;
    debugPrint("🔗 DeepLinkService initialized with navigatorKey");

    // Handle cold start
    await _handleDeepLinkColdStart();

    // Listen for runtime deep links (hot start)
    _sub = _appLinks.uriLinkStream.listen((uri) {
      debugPrint("📡 [HOT] Runtime deep link received: $uri");
      _handleLink(uri);
    });
  }

  /// Handle cold start deep links
  Future<void> _handleDeepLinkColdStart() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint("❄️ [COLD START] Deep link detected: $initialUri");

        if (_deepLinkHandled) {
          debugPrint("⏩ Already handled, skipping cold start deep link");
          return;
        }

        _pendingUri = initialUri;
      } else {
        debugPrint("❄️ [COLD START] No deep link found");
      }
    } catch (e) {
      debugPrint("❌ Error during deep link cold start: $e");
    }
  }

  Future<void> _handleClipboard() async {
    try {
      // ✅ Check authentication & onboarding before even reading clipboard
      final context = navigatorKey.currentContext;
      if (context != null) {
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthenticatedLogin &&
            authState.hasCompletedOnboarding) {
          debugPrint(
              "✅ User already completed onboarding — skipping clipboard deep link.");
          return; // ⏩ Skip clipboard logic entirely
        }
      }

      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text ?? "";

      if (!text.startsWith("session_")) {
        debugPrint("📋 Clipboard does not contain a valid session ID.");
        return;
      }

      debugPrint("📋 Clipboard contains sessionId: $text");

      if (_deepLinkHandled) {
        debugPrint("⏩ Deep link already handled, skipping clipboard.");
        return;
      }

      // ✅ Fetch code from API
      final inviteCode = await _getCodeFromSession(text);

      if (inviteCode != null) {
        debugPrint(
            "✅ Invite code retrieved from clipboard session: $inviteCode");

        _deepLinkHandled = true;

        // ✅ Build pending URI like a cold start deep link
        _pendingUri = Uri(
          path: 'joinspace',
          queryParameters: {'code': text},
        );

        // 🔄 Log that Deferred Deep Link is triggered
        debugPrint(
            "🔄 [Deferred Deep Link] Triggered navigation using clipboard session.");
      } else {
        debugPrint("⚠️ No invite code found for clipboard session.");
      }
    } catch (e) {
      debugPrint("❌ Error checking clipboard for deep link: $e");
    }
  }

  /// ✅ Public method to trigger clipboard check externally
  Future<void> checkClipboardForSession() async {
    return _handleClipboard();
  }

  /// Called whenever a link is received (cold or hot)
  void _handleLink(Uri uri) {
    if (_deepLinkHandled) return; // Avoid double handling
    if (navigatorKey.currentState == null) {
      debugPrint("⏳ Navigator not ready yet, queuing URI: $uri");
      _pendingUri = uri;
      return;
    }

    _deepLinkHandled = true;
    debugPrint("➡️ Handling deep link now: $uri");

    // ✅ Check authentication before navigating
    final context = navigatorKey.currentContext;
    if (context != null) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthenticatedLogin) {
        debugPrint("✅ User is authenticated, navigating now...");
        Future.delayed(const Duration(milliseconds: 300), () => _navigate(uri));
      } else {
        debugPrint(
            "⏳ User not authenticated, storing pending URI until login.");
        _pendingUri = uri; // store for later consumption
        _deepLinkHandled = false; // allow handling after login
      }
    } else {
      debugPrint(
          "⚠️ No context available, cannot check auth yet. Storing URI.");
      _pendingUri = uri;
      _deepLinkHandled = false;
    }
  }

  /// Call this from main.dart once the navigator is ready
  void consumePendingLinkIfAny() {
    debugPrint("📢 consumePendingLinkIfAny() CALLED");
    if (_pendingUri != null && navigatorKey.currentState != null) {
      debugPrint("🚀 Consuming pending deep link: $_pendingUri");
      final uriToNavigate = _pendingUri!;
      _pendingUri = null;
      _deepLinkHandled = true;
      Future.delayed(
          const Duration(milliseconds: 300), () => _navigate(uriToNavigate));
    } else {
      debugPrint("ℹ️ No pending link to consume");
    }
    // ✅ Clear clipboard after successful use
    Clipboard.setData(const ClipboardData(text: ""));
    debugPrint("🧹 Clipboard cleared after use.");
  }

  /// Navigation logic
  void _navigate(Uri uri) async {
    if (navigatorKey.currentState == null) return;
    debugPrint("➡️ Navigating based on URI: $uri");

    if (uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first.toLowerCase() == "joinspace") {
      final sessionId = uri.queryParameters['code'];
      if (sessionId != null) {
        debugPrint("🔑 Found sessionId in deep link: $sessionId");

        final inviteCode = await _getCodeFromSession(sessionId);
        if (inviteCode != null) {
          _navigateToJoinSpace(inviteCode);
        } else {
          debugPrint("⚠️ No invite code found for sessionId: $sessionId");
          _navigateToJoinSpace(null); // navigate without code if API fails
        }
      } else {
        debugPrint("⚠️ No sessionId in deep link");
        _navigateToJoinSpace(null);
      }
    } else {
      navigatorKey.currentState!.pushNamed('/home');
    }
  }

  /// Retrieve the real invite code from your API
  Future<String?> _getCodeFromSession(String sessionId) async {
    const int maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(
              'https://3-y2-aapwd-xqeh.vercel.app/api/get-code/$sessionId'),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            debugPrint("✅ Code retrieved from session: ${data['code']}");
            return data['code'];
          }
        } else if (response.statusCode == 404) {
          debugPrint("❌ Attempt $attempt: Session not found");
        }
      } catch (e) {
        debugPrint("❌ Error getting code from session (attempt $attempt): $e");
      }

      if (attempt < maxRetries) {
        debugPrint("⏳ Retrying in 300ms...");
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    return null;
  }

  /// Navigate to JoinSpace screen
  void _navigateToJoinSpace(String? code) {
    if (navigatorKey.currentState == null) return;

    if (code != null) {
      debugPrint("🎯 Navigating to JoinSpace with inviteCode: $code");
      navigatorKey.currentState!.pushNamed(
        '/joinSpace',
        arguments: {'inviteCode': code},
      ).then((_) => _deepLinkHandled = false); // allow next deep link
    } else {
      debugPrint("🎯 Navigating to JoinSpace without code");
      navigatorKey.currentState!
          .pushNamed('/joinSpace')
          .then((_) => _deepLinkHandled = false);
    }
  }

  void clearPendingData() {
    debugPrint("🧹 Clearing pending deep link/session data");
    _pendingUri = null;
    _deepLinkHandled = false; // reset so future deep links can be handled
  }

  void dispose() {
    debugPrint("🧹 Disposing DeepLinkService");
    _sub?.cancel();
  }
}
