// sos_screen.dart
import 'dart:async';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/sos/slide_to_cancel.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/location_handler.dart';
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
  Timer? _timer;
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OpenStreetMapGeocodingService _geocodingService =
      OpenStreetMapGeocodingService();
  final LocationHandler _locationHandler = LocationHandler(
    onMarkersUpdated: (markers) {
      // Handle marker updates if needed
    },
  );

  void _startHoldEffect() {
    setState(() {
      _isHolding = true;
    });
  }

  void _stopHoldEffect() {
    setState(() {
      _isHolding = false;
    });
  }

  void _startCountdown() {
    if (_isCounting) return;

    setState(() {
      _isCounting = true;
      _countdown = 10;
      _isHolding = false; // Reset effect when starting countdown
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        setState(() {
          _isActivated = true;
          _isCounting = false;
        });
        _timer?.cancel();
        _sendSOSLocation(); // Send SOS location when countdown ends
      }
    });
  }

  void _cancelSOS() {
    _timer?.cancel();
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

      // Fetch the user's current location using the LocationHandler.
      final currentLocation = await _locationHandler.getUserLocationOnce();
      if (currentLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('unable_to_fetch_location'.tr())),
        );
        return;
      }

      // Fetch the address using GeocodingService.
      final String address =
          await _geocodingService.getAddressFromLatLng(currentLocation);

      // Create an alarming SOS message using localization with interpolation.
      final String sosMessage = tr("sos_alert_message", namedArgs: {
        "displayName": user.displayName ?? "A user",
        "address": address,
        "latitude": currentLocation.latitude.toString(),
        "longitude": currentLocation.longitude.toString(),
      });

      // Fetch all space chat rooms the user is part of.
      final userSpaces = await _firestore
          .collection('Spaces')
          .where('members', arrayContains: user.uid)
          .get();

      // Send the SOS message to all space chat rooms.
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isActivated
          ? Colors.red
          : _isCounting
              ? const Color(0xFF6750A4)
              : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.8,
        shadowColor: Colors.black.withOpacity(1),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'sos'.tr(),
          style:
              const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
    return GestureDetector(
      onTap: _startCountdown,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onLongPress: _startCountdown,
            onLongPressStart: (_) => _startHoldEffect(),
            onLongPressEnd: (_) => _stopHoldEffect(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isHolding ? 180 : 0,
                  height: _isHolding ? 180 : 0,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6750A4).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                InkWell(
                  onTap: _startCountdown,
                  borderRadius: BorderRadius.circular(80),
                  splashColor: const Color(0xFF6750A4),
                  child: CircleAvatar(
                    radius: 90,
                    backgroundColor: const Color(0xFF6750A4),
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
              ],
            ),
          ),
          const SizedBox(height: 100),
          Text(
            'sos_sent_info'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500),
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
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'sos_countdown_info'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              color: Colors.white,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 100,
                  backgroundColor: Colors.red,
                  child: _countdown > 0
                      ? Text(
                          '$_countdown',
                          style: const TextStyle(
                              fontSize: 40, color: Colors.white),
                        )
                      : const Icon(
                          Icons.warning,
                          size: 40,
                          color: Colors.white,
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
              // Call your cancel method
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
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'sos_activated_info'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              color: Colors.white,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 100,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.warning, color: Colors.red, size: 50),
                ),
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
}
