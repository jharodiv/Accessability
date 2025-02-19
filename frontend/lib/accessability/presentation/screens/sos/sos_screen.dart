import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class SOSScreen extends StatefulWidget {
  @override
  _SOSScreenState createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  int _countdown = 10;
  bool _isActivated = false;
  bool _isCounting = false;
  bool _isHolding = false;
  Timer? _timer;

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

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
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
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SOS',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: AnimatedContainer(
        duration: Duration(milliseconds: 500),
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
            SizedBox(height: 50),
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
                  duration: Duration(milliseconds: 300),
                  width: _isHolding ? 180 : 0,
                  height: _isHolding ? 180 : 0,
                  decoration: BoxDecoration(
                    color: Color(0xFF6750A4).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                InkWell(
                  onTap: _startCountdown,
                  borderRadius: BorderRadius.circular(80),
                  splashColor: Color(0xFF6750A4),
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
          const Text('Your SOS will be sent to 1 person',
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
            'After 10 seconds, your SOS and location will be sent to your Space and emergency contact',
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
                          style: TextStyle(fontSize: 40, color: Colors.white),
                        )
                      : Icon(
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
          padding: const EdgeInsets.only(top: 50), // Add padding at the top
          child: const Text(
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Text(
            'After 10 seconds, your SOS and location will be sent to your Space and emergency contact',
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
                const Text(
                  'SOS Activated!',
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
                const SizedBox(height: 10),
                const CircleAvatar(
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
    return Container(
      width: 300, // Set a reasonable width for the button
      child: Slidable(
        key: const ValueKey(0),
        endActionPane: ActionPane(
          motion: DrawerMotion(),
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
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Slide to cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.red, // Arrow background changes to red
                  shape: BoxShape.circle,
                ),
                child: Center(
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
