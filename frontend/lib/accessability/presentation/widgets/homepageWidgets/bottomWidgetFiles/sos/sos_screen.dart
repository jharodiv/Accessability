import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final GeocodingService _geocodingService = GeocodingService();
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
        const SnackBar(content: Text('Unable to fetch current location')),
      );
      return;
    }

    // Fetch the address using GeocodingService.
    final String address = await _geocodingService.getAddressFromLatLng(currentLocation);

    // Create an alarming SOS message.
    final String sosMessage =
        '🚨 **SOS Alert** 🚨\n'
        '${user.displayName ?? "A user"} needs immediate assistance at this location:\n'
        '📍 $address\n'
        'https://www.google.com/maps?q=${currentLocation.latitude},${currentLocation.longitude}\n'
        '**Please call paramedics or emergency services immediately!**';

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
      const SnackBar(content: Text('SOS alert sent to all space chat rooms!')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to send SOS alert: $e')),
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
        title: const Text(
          'SOS',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
            // Add some space at the bottom
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
                  child: const CircleAvatar(
                    radius: 80,
                    backgroundColor: Color(0xFF6750A4),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Tap to \nsend SOS\n',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          TextSpan(
                            text: '(press and hold)',
                            style: TextStyle(
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
          const Text('Your SOS will be sent to all space chat rooms',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _countdownScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between items
      children: [
        // Top text
        const Padding(
          padding: EdgeInsets.only(top: 40), // Add padding at the top
          child: Text(
            'Slide to cancel',
            style: TextStyle(
              fontWeight: FontWeight.bold, // Make it bold
              color: Colors.white, // Set text color to white
              fontSize: 22, // Adjust font size as needed
            ),
          ),
        ),
        const SizedBox(height: 8), // Space between texts
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'After 10 seconds, your SOS and location will be sent to all your space chat rooms',
            style: TextStyle(
              fontWeight: FontWeight.w400, // Set font weight to 400
              color: Colors.white, // Set text color to white
              fontSize: 14, // Adjust font size as needed
            ),
            textAlign: TextAlign.center, // Center align the text
          ),
        ),
        // Centered countdown
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 100, // Increase the radius for a larger circle
                  backgroundColor: Colors.red,
                  child: _countdown > 0
                      ? Text(
                          '$_countdown',
                          style: const TextStyle(fontSize: 40, color: Colors.white),
                        )
                      : const Icon(
                          Icons
                              .warning, // Danger icon when countdown reaches zero
                          size: 40,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        // The cancel button at the bottom
        Padding(
          padding:
              const EdgeInsets.only(bottom: 20), // Add some padding if needed
          child: _cancelButton(),
        ),
      ],
    );
  }

  Widget _activatedScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between items
      children: [
        // Top text
        const Padding(
          padding: EdgeInsets.only(top: 50), // Add padding at the top
          child: Text(
            'SOS Activated!',
            style: TextStyle(
              fontWeight: FontWeight.bold, // Make it bold
              color: Colors.white, // Set text color to white
              fontSize: 22, // Adjust font size as needed
            ),
          ),
        ),
        const SizedBox(height: 8), // Space between texts
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Your SOS and location have been sent to all your space chat rooms.',
            style: TextStyle(
              fontWeight: FontWeight.w400, // Set font weight to 400
              color: Colors.white, // Set text color to white
              fontSize: 14, // Adjust font size as needed
            ),
            textAlign: TextAlign.center, // Center align the text
          ),
        ),
        // Centered SOS Activated message
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
        // The cancel button at the bottom
        Padding(
          padding:
              const EdgeInsets.only(bottom: 20), // Add some padding if needed
          child: _cancelButton(),
        ),
      ],
    );
  }

  Widget _cancelButton() {
    return SizedBox(
      width: 300, // Set a reasonable width for the button
      child: Slidable(
        key: const ValueKey(0),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          dismissible: DismissiblePane(onDismissed: _cancelSOS),
          children: [
            SlidableAction(
              onPressed: (context) => _cancelSOS(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.cancel,
              label: 'Cancel SOS',
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Slide to cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.red, // Arrow background changes to red
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

