import 'package:accessability/accessability/firebaseServices/auth/auth_service.dart';
import 'package:accessability/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:accessability/accessability/firebaseServices/place/geocoding_service.dart';
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
  // Purple used for the send icon and loading indicator
  static const Color _purple = Color(0xFF6750A4);

  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OpenStreetMapGeocodingService _geocodingService =
      OpenStreetMapGeocodingService();
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
              color: const Color(0xFF6750A4),
            ),
            title: Text(
              'sendLocation'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                onPressed: _isSending ? null : _sendLocation,
                // Disable button when sending
                icon: _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          // Use purple loading color
                          valueColor: AlwaysStoppedAnimation<Color>(_purple),
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.send, color: _purple),
              ),
            ],
          ),
        ),
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
          final String message = widget.isSpaceChat
              ? 'noMembersInSpace'.tr()
              : 'noSpaceChatsOrMembers'.tr();
          return _buildEmptyState(
            message,
            icon: Icons.group_off, // a more fitting icon for error/no members
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<Map<String, dynamic>> usersInSameSpaces = snapshot.data![0];
        final List<Map<String, dynamic>> usersWithAcceptedRequests =
            snapshot.data![1];
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
          final String message = widget.isSpaceChat
              ? 'There are no members in your space yet.'
              : 'There are no space chats yet, or there are no members in your space yet.';
          return _buildEmptyState(
            message,
            icon: Icons.people_outline,
            // Or use an image: assetPath: 'assets/images/no_chats.png',
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
              ...individualUsers
                  .map((userData) => _buildChatListItem(userData)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String message, {IconData? icon, String? assetPath}) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white70 : Colors.black54;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // show an asset image if provided, otherwise show an icon
            if (assetPath != null) ...[
              // If using an asset, make sure to add it to pubspec.yaml
              Image.asset(
                assetPath,
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Special-case Icons.group_off: keep icon at 48 but reduce top padding
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                ),
                // If the icon is group_off, reduce the top padding to remove the visual gap
                padding: icon == Icons.group_off
                    ? const EdgeInsets.fromLTRB(8, 4, 8, 8)
                    : const EdgeInsets.all(8),
                child: Icon(
                  icon ?? Icons.chat_bubble_outline,
                  // Keep the group_off icon at 48 as you requested; others stay slightly smaller
                  size: icon == Icons.group_off ? 48 : 40,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
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
      final String address =
          await _geocodingService.getAddressFromLatLng(widget.currentLocation);

      // Create a message with the location and address
      final String locationMessage = '📍 My current location: $address\n'
          'https://www.google.com/maps?q=${widget.currentLocation.latitude},${widget.currentLocation.longitude}';

      // Send the location to each selected chat
      for (final chatId in _selectedChats) {
        // Check if the chatId exists in the space_chat_rooms collection
        final spaceChatDoc =
            await _firestore.collection('space_chat_rooms').doc(chatId).get();
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
