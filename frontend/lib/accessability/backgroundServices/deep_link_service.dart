import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  Uri? _pendingUri;

  late GlobalKey<NavigatorState> navigatorKey;
  bool _deepLinkHandled = false; // prevent double navigation

  Future<void> initialize(GlobalKey<NavigatorState> key) async {
    navigatorKey = key;
    debugPrint("🔗 DeepLinkService initialized with navigatorKey");

    // Cold start
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      debugPrint("❄️ [COLD START] Deep link detected: $initialUri");
      _pendingUri = initialUri;
    } else {
      debugPrint("❄️ [COLD START] No deep link found");
    }

    // Hot links while running
    _sub = _appLinks.uriLinkStream.listen((uri) {
      debugPrint("📡 [HOT] Runtime deep link received: $uri");
      _handleLink(uri);
    });
  }

  void _handleLink(Uri uri) {
    if (_deepLinkHandled) return; // already handled
    if (navigatorKey.currentState == null) {
      debugPrint("⏳ Navigator not ready, queuing URI: $uri");
      _pendingUri = uri;
      return;
    }

    _deepLinkHandled = true;
    debugPrint("➡️ Handling deep link now: $uri");

    // Small delay to allow UI to settle
    Future.delayed(const Duration(milliseconds: 300), () => _navigate(uri));
  }

  void consumePendingLinkIfAny() {
    if (_pendingUri != null &&
        navigatorKey.currentState != null &&
        !_deepLinkHandled) {
      debugPrint("🚀 Consuming pending deep link (cold start): $_pendingUri");
      final uriToNavigate = _pendingUri!;
      _pendingUri = null;
      _deepLinkHandled = true;
      Future.delayed(
          const Duration(milliseconds: 300), () => _navigate(uriToNavigate));
    } else {
      debugPrint("ℹ️ No pending link to consume or navigator not ready");
    }
  }

  void _navigate(Uri uri) {
    if (navigatorKey.currentState == null) return;

    debugPrint("➡️ Navigating based on URI: $uri");

    if (uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first.toLowerCase() == "joinspace") {
      final code = uri.queryParameters['code'];
      navigatorKey.currentState!.pushNamed(
        '/joinSpace',
        arguments: code != null ? {'inviteCode': code} : null,
      );
    } else {
      navigatorKey.currentState!.pushNamed('/home');
    }
  }

  void dispose() {
    debugPrint("🧹 Disposing DeepLinkService");
    _sub?.cancel();
  }
}
