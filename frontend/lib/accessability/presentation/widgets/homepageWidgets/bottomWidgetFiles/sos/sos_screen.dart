// sos_screen.dart
import 'dart:async';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/sos/slide_to_cancel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for HapticFeedback
import 'package:vibration/vibration.dart'; // for stronger vibration on Android
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:accessability/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:accessability/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});
  @override
  _SOSScreenState createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  int _countdown = 10;
  bool _isActivated = false;
  bool _isCounting = false;
  bool _isHolding = false;
  bool _isPressed = false;

  Timer? _timer;
  bool _hasVibrator = false;

  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OpenStreetMapGeocodingService _geocodingService =
      OpenStreetMapGeocodingService();
  final LocationHandler _locationHandler = LocationHandler(
    onMarkersUpdated: (markers) {},
  );

  @override
  void initState() {
    super.initState();
    _initVibrator();
  }

  Future<void> _initVibrator() async {
    try {
      final has = await Vibration.hasVibrator();
      if (mounted) setState(() => _hasVibrator = has ?? false);
    } catch (_) {
      if (mounted) setState(() => _hasVibrator = false);
    }
  }

  // Stronger feedback using both system haptics and the vibration package
  Future<void> _performTapFeedback({int durationMs = 40}) async {
    // System haptic (iOS & Android)
    HapticFeedback.selectionClick();

    // Android (and some devices) support vibration patterns; check first
    try {
      if (_hasVibrator) {
        // short vibration pulse; tune duration as needed (40-200ms)
        await Vibration.vibrate(duration: durationMs);
      }
    } catch (_) {
      // ignore vibration API errors
    }

    // small scale animation
    setState(() {
      _isPressed = true;
    });
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() {
          _isPressed = false;
        });
      }
    });
  }

  void _startHoldEffect() {
    setState(() {
      _isHolding = true;
    });
    HapticFeedback.mediumImpact();
  }

  void _stopHoldEffect() {
    setState(() {
      _isHolding = false;
    });
  }

  // Start countdown and vibrate on every second tick (strong vibration)
  Future<void> _startCountdown() async {
    if (_isCounting) return;

    await _performTapFeedback(durationMs: 60);

    setState(() {
      _isCounting = true;
      _countdown = 10;
      _isHolding = false;
    });

    // Immediately vibrate once on start for stronger feedback
    try {
      if (_hasVibrator) {
        Vibration.vibrate(duration: 200); // strong immediate pulse
      }
    } catch (_) {}

    // also a noticeable haptic
    HapticFeedback.heavyImpact();

    // Timer ticks every second; vibrate on each tick (including the last tick before activating)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });

        // vibrate each second tick
        try {
          if (_hasVibrator) {
            Vibration.vibrate(duration: 200); // strong vibration every second
          }
        } catch (_) {}
        HapticFeedback.heavyImpact();
      } else {
        // Final tick: countdown reaches zero -> activate SOS
        setState(() {
          _isActivated = true;
          _isCounting = false;
        });
        _timer?.cancel();

        // final confirmation feedback (longer)
        try {
          if (_hasVibrator) {
            Vibration.vibrate(duration: 300);
          }
        } catch (_) {}
        HapticFeedback.vibrate();

        _sendSOSLocation();
      }
    });
  }

  void _cancelSOS() {
    _timer?.cancel();
    // cancel any ongoing vibration pattern
    try {
      if (_hasVibrator) Vibration.cancel();
    } catch (_) {}
    HapticFeedback.selectionClick();
    setState(() {
      _isCounting = false;
      _isActivated = false;
      _countdown = 10;
    });
  }

  Future<void> _sendSOSLocation() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final currentLocation = await _locationHandler.getUserLocationOnce();
      if (currentLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('unable_to_fetch_location'.tr())),
        );
        return;
      }

      final String address =
          await _geocodingService.getAddressFromLatLng(currentLocation);

      final String sosMessage = tr("sos_alert_message", namedArgs: {
        "displayName": user.displayName ?? "A user",
        "address": address,
        "latitude": currentLocation.latitude.toString(),
        "longitude": currentLocation.longitude.toString(),
      });

      final userSpaces = await _firestore
          .collection('Spaces')
          .where('members', arrayContains: user.uid)
          .get();

      for (final space in userSpaces.docs) {
        final spaceId = space.id;
        await _chatService.sendMessage(
          spaceId,
          sosMessage,
          isSpaceChat: true,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('sos_alert_sent'.tr())),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('failed_to_send_sos_alert'.tr(args: [e.toString()]))),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    try {
      if (_hasVibrator) Vibration.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _isActivated
          ? Colors.red
          : _isCounting
              ? const Color(0xFF6750A4)
              : (isDarkMode ? const Color(0xFF121212) : Colors.white),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: AppBar(
            elevation: 0,
            leading: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4), // purple icon
            ),
            title: Text(
              'sos'
                  .tr(), // update to your screen title (was 'settings' in the example)
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: _isActivated
                    ? _activatedScreen()
                    : _isCounting
                        ? _countdownScreen()
                        : _initialScreen(),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _initialScreen() {
    const innerColor = Color(0xFF6750A4);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        _performTapFeedback();
        _startCountdown();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () async {
              await _performTapFeedback();
              _startCountdown();
            },
            onLongPress: () async {
              await _performTapFeedback();
              _startCountdown();
            },
            onLongPressStart: (_) => _startHoldEffect(),
            onLongPressEnd: (_) => _stopHoldEffect(),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 80),
              scale: _isPressed ? 0.97 : 1.0,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: innerColor.withOpacity(0.12),
                      boxShadow: [
                        BoxShadow(
                          color: innerColor.withOpacity(0.25),
                          blurRadius: 36,
                          spreadRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),

                  // Inner purple button
                  Container(
                    width: 180,
                    height: 180,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: innerColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: tr('tap_to_send_sos') + "\n",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            TextSpan(
                              text: tr('press_and_hold'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  // On hold ring
                  if (_isHolding)
                    Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: innerColor.withOpacity(0.18),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 100),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'sos_sent_info'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countdownScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(
            'slide_to_cancel'.tr(),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white, fontSize: 22),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'sos_countdown_info'.tr(),
            style: const TextStyle(
                fontWeight: FontWeight.w400, color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 80),
                  scale: _isPressed ? 0.97 : 1.0,
                  child: Container(
                    width: 200,
                    height: 200,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _countdown > 0
                          ? Text(
                              '$_countdown',
                              style: const TextStyle(
                                  fontSize: 40, color: Colors.white),
                            )
                          : const Icon(Icons.warning,
                              size: 40, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: SlideToCancel(
            width: 300,
            height: 56,
            onCancel: () {
              _cancelSOS();
            },
          ),
        ),
      ],
    );
  }

  Widget _activatedScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 50),
          child: Text(
            'sos_activated'.tr(),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white, fontSize: 22),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'sos_activated_info'.tr(),
            style: const TextStyle(
                fontWeight: FontWeight.w400, color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        const Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [],
            ),
          ),
        ),

// white circle with warning icon & soft shadow
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.warning, color: Colors.red, size: 50),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: SlideToCancel(
            width: 300,
            height: 56,
            onCancel: () {
              _cancelSOS();
            },
          ),
        ),
      ],
    );
  }
}
