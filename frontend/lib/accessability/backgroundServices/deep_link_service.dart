import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  late GlobalKey<NavigatorState> navigatorKey;
  Uri? _pendingUri;
  bool _deepLinkHandled = false; // prevents double handling

  /// Callback when a deep link is detected
  void Function(Uri uri, bool isColdStart)? onLinkDetected;

  /// Initialize the service
  Future<void> initialize(GlobalKey<NavigatorState> key) async {
    navigatorKey = key;
    debugPrint("🔗 DeepLinkService initialized");

    // Cold start: app launched via deep link
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleLink(initialUri, true);
    } else {
      debugPrint("❄️ [COLD START] No deep link found");
    }

    // Hot start: app is running and receives a deep link
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri, false);
    });
  }

  Future<void> checkWebStoredDeepLink() async {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse("https://deep-link-test-red.vercel.app"));

      // Wait until page loads
      await controller.setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) async {
          final result = await controller.runJavaScriptReturningResult(
              "localStorage.getItem('pending_deeplink');");

          if (result != null && result != "null") {
            final link = (result as String).replaceAll('"', '');
            debugPrint("🌐 [AUTO CHECK] Found stored deep link: $link");
            _handleLink(Uri.parse(link), true);

            // Clear so it doesn't trigger again
            await controller
                .runJavaScript("localStorage.removeItem('pending_deeplink');");
          } else {
            debugPrint("🌐 [AUTO CHECK] No pending deep link found");
          }
        },
      ));
    } catch (e) {
      debugPrint("⚠️ Failed to check web stored deep link: $e");
    }
  }

  void _handleLink(Uri uri, bool isColdStart) {
    if (_deepLinkHandled) {
      debugPrint("⚠️ Link already handled, ignoring: $uri");
      return;
    }

    _deepLinkHandled = true;
    debugPrint(
        "${isColdStart ? '❄️ [COLD START]' : '📡 [HOT]'} Handling deep link: $uri");

    // Call the optional callback
    onLinkDetected?.call(uri, isColdStart);

    // For now, just log instead of navigating
    _navigate(uri);
  }

  void _navigate(Uri uri) {
    final nav = navigatorKey.currentState;

    if (nav == null) {
      // Navigator not ready yet, store URI for later
      _pendingUri = uri;
      debugPrint("⏳ Navigator not ready, storing pending URI: $uri");
      return;
    }

    debugPrint("➡️ Navigating based on URI: $uri");

    if (uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first.toLowerCase() == "joinspace") {
      final code = uri.queryParameters['code'];
      debugPrint("📝 Detected joinspace link. Invite code: ${code ?? 'none'}");
      nav.pushNamed(
        '/joinSpace',
        arguments: code != null ? {'inviteCode': code} : null,
      );
    } else {
      debugPrint("📝 Detected other link, navigating to /home");
      nav.pushNamed('/home');
    }
  }

  void consumePendingLinkIfAny() {
    if (_pendingUri != null && navigatorKey.currentState != null) {
      debugPrint("🚀 Consuming pending deep link: $_pendingUri");
      final uriToNavigate = _pendingUri!;
      _pendingUri = null;
      _navigate(uriToNavigate); // actually navigate now
    }
  }

  void dispose() {
    debugPrint("🧹 Disposing DeepLinkService");
    _sub?.cancel();
  }
}
