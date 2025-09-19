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
    debugPrint("🔗 [DeepLinkService] Initialized with navigatorKey ✅");

    // Handle cold start
    await _handleDeepLinkColdStart();

    // Listen for runtime deep links (hot start)
    _sub = _appLinks.uriLinkStream.listen((uri) {
      debugPrint("🔗 [DeepLinkService] 📡 HOT deep link received: $uri");
      _handleLink(uri);
    });
  }

  /// Handle cold start deep links
  Future<void> _handleDeepLinkColdStart() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint("🔗 [DeepLinkService] ❄️ COLD START detected: $initialUri");

        if (_deepLinkHandled) {
          debugPrint("🔗 [DeepLinkService] ⏩ Already handled, skipping.");
          return;
        }

        _pendingUri = initialUri;
      } else {
        debugPrint("🔗 [DeepLinkService] ❄️ No deep link found on cold start.");
      }
    } catch (e) {
      debugPrint("🔗 [DeepLinkService] ❌ Error during cold start: $e");
    }
  }

  Future<void> _handleClipboard() async {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthenticatedLogin &&
            authState.hasCompletedOnboarding) {
          debugPrint(
              "🔗 [DeepLinkService] ✅ User has completed onboarding — skipping clipboard check.");
          return;
        }
      }

      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text ?? "";

      if (!text.startsWith("session_")) {
        debugPrint(
            "🔗 [DeepLinkService] 📋 Clipboard does not contain sessionId.");
        return;
      }

      debugPrint("🔗 [DeepLinkService] 📋 Clipboard contains sessionId: $text");

      if (_deepLinkHandled) {
        debugPrint(
            "🔗 [DeepLinkService] ⏩ Deep link already handled, skipping clipboard.");
        return;
      }

      final inviteCode = await _getCodeFromSession(text);

      if (inviteCode != null) {
        debugPrint(
            "🔗 [DeepLinkService] ✅ Invite code retrieved from clipboard session: $inviteCode");

        _deepLinkHandled = true;
        _pendingUri = Uri(
          path: 'joinspace',
          queryParameters: {'code': text},
        );

        debugPrint(
            "🔗 [DeepLinkService] 🔄 Triggered navigation using clipboard session.");
      } else {
        debugPrint(
            "🔗 [DeepLinkService] ⚠️ No invite code found for clipboard session.");
      }
    } catch (e) {
      debugPrint("🔗 [DeepLinkService] ❌ Error checking clipboard: $e");
    }
  }

  /// ✅ Public method to trigger clipboard check externally
  Future<void> checkClipboardForSession() async {
    debugPrint("🔗 [DeepLinkService] 📋 Checking clipboard for session...");
    return _handleClipboard();
  }

  /// Called whenever a link is received (cold or hot)
  void _handleLink(Uri uri) {
    if (_deepLinkHandled) {
      debugPrint("🔗 [DeepLinkService] ⏩ Link already handled, ignoring: $uri");
      return;
    }
    if (navigatorKey.currentState == null) {
      debugPrint(
          "🔗 [DeepLinkService] ⏳ Navigator not ready, queuing URI: $uri");
      _pendingUri = uri;
      return;
    }

    _deepLinkHandled = true;
    debugPrint("🔗 [DeepLinkService] ➡️ Handling deep link now: $uri");

    final context = navigatorKey.currentContext;
    if (context != null) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthenticatedLogin) {
        debugPrint(
            "🔗 [DeepLinkService] ✅ User is authenticated, navigating...");
        Future.delayed(const Duration(milliseconds: 300), () => _navigate(uri));
      } else {
        debugPrint(
            "🔗 [DeepLinkService] ⏳ User not authenticated — storing pending URI.");
        _pendingUri = uri;
        _deepLinkHandled = false;
      }
    } else {
      debugPrint(
          "🔗 [DeepLinkService] ⚠️ No context available — storing pending URI.");
      _pendingUri = uri;
      _deepLinkHandled = false;
    }
  }

  /// Call this from main.dart once the navigator is ready
  void consumePendingLinkIfAny() {
    debugPrint("🔗 [DeepLinkService] 📢 consumePendingLinkIfAny() CALLED");
    if (_pendingUri != null && navigatorKey.currentState != null) {
      debugPrint(
          "🔗 [DeepLinkService] 🚀 Consuming pending deep link: $_pendingUri");
      final uriToNavigate = _pendingUri!;
      _pendingUri = null;
      _deepLinkHandled = true;
      Future.delayed(
          const Duration(milliseconds: 300), () => _navigate(uriToNavigate));
    } else {
      debugPrint("🔗 [DeepLinkService] ℹ️ No pending link to consume.");
    }
  }

  /// Navigation logic
  void _navigate(Uri uri) async {
    if (navigatorKey.currentState == null) return;
    debugPrint("🔗 [DeepLinkService] ➡️ Navigating based on URI: $uri");

    if (uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first.toLowerCase() == "joinspace") {
      final sessionId = uri.queryParameters['code'];
      if (sessionId != null) {
        debugPrint("🔗 [DeepLinkService] 🔑 Found sessionId: $sessionId");

        final inviteCode = await _getCodeFromSession(sessionId);
        if (inviteCode != null) {
          _navigateToJoinSpace(inviteCode);
        } else {
          debugPrint(
              "🔗 [DeepLinkService] ⚠️ No invite code found for $sessionId");
          _navigateToJoinSpace(null);
        }
      } else {
        debugPrint("🔗 [DeepLinkService] ⚠️ No sessionId present.");
        _navigateToJoinSpace(null);
      }
    } else {
      debugPrint("🔗 [DeepLinkService] 🏠 Navigating to /home");
      navigatorKey.currentState!.pushNamed('/home');
    }
  }

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
            debugPrint(
                "🔗 [DeepLinkService] ✅ Code retrieved: ${data['code']}");
            return data['code'];
          }
        } else if (response.statusCode == 404) {
          debugPrint(
              "🔗 [DeepLinkService] ❌ Attempt $attempt: Session not found.");
        }
      } catch (e) {
        debugPrint("🔗 [DeepLinkService] ❌ Attempt $attempt: $e");
      }

      if (attempt < maxRetries) {
        debugPrint("🔗 [DeepLinkService] ⏳ Retrying in 300ms...");
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    return null;
  }

  void _navigateToJoinSpace(String? code) {
    if (navigatorKey.currentState == null) return;

    if (code != null) {
      debugPrint(
          "🔗 [DeepLinkService] 🎯 Navigating to JoinSpace with code: $code");
      navigatorKey.currentState!.pushNamed(
        '/joinSpace',
        arguments: {'inviteCode': code},
      ).then((_) => _deepLinkHandled = false);
    } else {
      debugPrint(
          "🔗 [DeepLinkService] 🎯 Navigating to JoinSpace WITHOUT code.");
      navigatorKey.currentState!
          .pushNamed('/joinSpace')
          .then((_) => _deepLinkHandled = false);
    }
  }

  void clearPendingData() {
    debugPrint("🔗 [DeepLinkService] 🧹 Clearing pending data.");
    _pendingUri = null;
    _deepLinkHandled = false;
  }

  void dispose() {
    debugPrint("🔗 [DeepLinkService] 🧹 Disposing DeepLinkService.");
    _sub?.cancel();
  }
}
