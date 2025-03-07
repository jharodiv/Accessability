import 'package:AccessAbility/accessability/firebaseServices/auth/auth_service.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

class SendLocationScreen extends StatefulWidget {
  final LatLng currentLocation;
  final bool isSpaceChat;

  const SendLocationScreen({
    super.key,
    required this.currentLocation,
    required this.isSpaceChat,
  });

  @override
  _SendLocationScreenState createState() => _SendLocationScreenState();
}

class _SendLocationScreenState extends State<SendLocationScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeocodingService _geocodingService = GeocodingService();
  final LocationHandler _locationHandler = LocationHandler(
    onMarkersUpdated: (markers) {
      // Handle marker updates if needed
    },
  );

  Set<String> _selectedChats = {}; // Stores selected chat room IDs
  bool _isSending = false; // Track whether the send operation is in progress

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Location'),
        actions: [
          IconButton(
            onPressed: _isSending ? null : _sendLocation, // Disable button when sending
            icon: _isSending
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.currentLocation,
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('current_location'),
                  position: widget.currentLocation,
                  infoWindow: const InfoWindow(title: 'Your Location'),
                ),
              },
              onMapCreated: (controller) {
                _locationHandler.setMapStyle(controller, isDarkMode);
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Select Chat Rooms or Spaces',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          Expanded(
            child: _buildChatList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return StreamBuilder(
      stream: CombineLatestStream.list([
        _chatService.getUsersInSameSpaces(),
        _chatService.getUsersWithAcceptedChatRequests(),
        _chatService.getSpaceChatRooms(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading chats.'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<Map<String, dynamic>> usersInSameSpaces = snapshot.data![0];
        final List<Map<String, dynamic>> usersWithAcceptedRequests = snapshot.data![1];
        final List<Map<String, dynamic>> spaceChatRooms = snapshot.data![2];

        // Combine the lists and remove duplicates
        final Map<String, Map<String, dynamic>> uniqueUsers = {};

        for (var user in usersInSameSpaces) {
          uniqueUsers[user['uid']] = user;
        }

        for (var user in usersWithAcceptedRequests) {
          uniqueUsers[user['uid']] = user;
        }

        for (var space in spaceChatRooms) {
          uniqueUsers[space['id']] = {
            'uid': space['id'],
            'username': space['name'],
            'isSpaceChat': true, // Mark space chats explicitly
          };
        }

        if (uniqueUsers.isEmpty) {
          return const Center(
            child: Text('No chats available.'),
          );
        }

        // Separate space chats and individual users
        final List<Map<String, dynamic>> spaceChats = uniqueUsers.values
            .where((user) => user['isSpaceChat'] == true)
            .toList();
        final List<Map<String, dynamic>> individualUsers = uniqueUsers.values
            .where((user) => user['isSpaceChat'] != true)
            .toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (spaceChats.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Space Chats',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              ...spaceChats.map((userData) => _buildChatListItem(userData)),
              const Divider(thickness: 1, height: 20),
            ],
            if (individualUsers.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'People',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              ...individualUsers.map((userData) => _buildChatListItem(userData)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildChatListItem(Map<String, dynamic> userData) {
    final bool isSpaceChat = userData['isSpaceChat'] == true;
    final String chatId = userData['uid'];
    final String username = userData['username'];

    return CheckboxListTile(
      title: Text(username),
      value: _selectedChats.contains(chatId),
      onChanged: (value) {
        setState(() {
          if (value == true) {
            _selectedChats.add(chatId);
          } else {
            _selectedChats.remove(chatId);
          }
        });
      },
    );
  }

  Future<void> _sendLocation() async {
    if (_selectedChats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one chat.')),
      );
      return;
    }

    setState(() {
      _isSending = true; // Start loading animation
    });

    try {
      final String currentUserID = _auth.currentUser!.uid;
      final String currentUserEmail = _auth.currentUser!.email!;
      final Timestamp timestamp = Timestamp.now();

      // Fetch the address using GeocodingService
      final String address = await _geocodingService.getAddressFromLatLng(widget.currentLocation);

      // Create a message with the location and address
      final String locationMessage =
          '📍 My current location: $address\n'
          'https://www.google.com/maps?q=${widget.currentLocation.latitude},${widget.currentLocation.longitude}';

      // Send the location to each selected chat
      for (final chatId in _selectedChats) {
        // Check if the chatId exists in the space_chat_rooms collection
        final spaceChatDoc = await _firestore.collection('space_chat_rooms').doc(chatId).get();
        final isSpaceChat = spaceChatDoc.exists;

        await _chatService.sendMessage(
          chatId,
          locationMessage,
          isSpaceChat: isSpaceChat, // Pass the correct isSpaceChat value
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location sent successfully!')),
      );

      Navigator.pop(context); // Close the screen after sending
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send location: $e')),
      );
    } finally {
      setState(() {
        _isSending = false; // Stop loading animation
      });
    }
  }
}