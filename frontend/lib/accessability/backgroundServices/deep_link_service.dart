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

  // For navigation
  late GlobalKey<NavigatorState> navigatorKey;

  Future<void> initialize(GlobalKey<NavigatorState> key) async {
    navigatorKey = key;
    debugPrint("🔗 DeepLinkService initialized with navigatorKey");

    // Cold start
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      debugPrint("❄️ Cold start link detected: $initialUri");
      _handleLink(initialUri);
    } else {
      debugPrint("❄️ No cold start link found");
    }

    // While running
    _sub = _appLinks.uriLinkStream.listen((uri) {
      debugPrint("📡 Runtime deep link received: $uri");
      _handleLink(uri);
    });
  }

  void _handleLink(Uri uri) {
    debugPrint("📌 Handling deep link: $uri");

    if (navigatorKey.currentState == null) {
      debugPrint("⏳ Navigator not ready, queuing URI: $uri");
      _pendingUri = uri;
      return;
    }

    _navigate(uri);
  }

  void consumePendingLinkIfAny() {
    if (_pendingUri != null && navigatorKey.currentState != null) {
      debugPrint("🚀 Consuming pending link: $_pendingUri");
      _navigate(_pendingUri!);
      _pendingUri = null;
    } else {
      debugPrint("ℹ️ No pending link to consume or navigator still not ready");
    }
  }

  void _navigate(Uri uri) {
    debugPrint("➡️ Navigating based on URI: $uri");
    debugPrint("📂 Path segments: ${uri.pathSegments}");

    if (uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first.toLowerCase() == "joinspace") {
      final code = uri.queryParameters['code'];
      if (code != null) {
        debugPrint("✅ Navigating to /joinSpace with code: $code");
        navigatorKey.currentState!.pushNamed(
          '/joinSpace',
          arguments: {'inviteCode': code},
        );
      } else {
        debugPrint("⚠️ Navigating to /joinSpace without code");
        navigatorKey.currentState!.pushNamed('/joinSpace');
      }
    } else {
      debugPrint("➡️ Navigating to default route: /home");
      navigatorKey.currentState!.pushNamed('/home');
    }
  }

  void dispose() {
    debugPrint(
        "🧹 Disposing DeepLinkService and cancelling stream subscription");
    _sub?.cancel();
  }
}
