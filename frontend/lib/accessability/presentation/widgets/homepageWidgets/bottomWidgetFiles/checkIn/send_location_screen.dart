// Replace the previous SendLocationScreen with this file contents.

import 'package:accessability/accessability/firebaseServices/auth/auth_service.dart';
import 'package:accessability/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:accessability/accessability/presentation/widgets/shimmer/shimmer_chat_list.dart';
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

class _SendLocationScreenState extends State<SendLocationScreen>
    with SingleTickerProviderStateMixin {
  static const Color _purple = Color(0xFF6750A4);

  late final AnimationController _sendAnimController;

  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OpenStreetMapGeocodingService _geocodingService =
      OpenStreetMapGeocodingService();
  final LocationHandler _locationHandler = LocationHandler(
    onMarkersUpdated: (markers) {},
  );

  Set<String> _selectedChats = {}; // Stores selected chat room IDs
  bool _isSending = false;

  String? _currentUserPhotoUrl; // cached profile picture of the current user

  @override
  void initState() {
    super.initState();
    _sendAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Load current user's photo once and cache it
    _loadCurrentUserPhoto();
  }

  Future<void> _loadCurrentUserPhoto() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        debugPrint('[SendLocation] no current user (not signed in)');
        return;
      }
      debugPrint('[SendLocation] current uid: ${user.uid}');
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        debugPrint('[SendLocation] user doc does not exist for ${user.uid}');
        return;
      }

      final data = doc.data();
      debugPrint('[SendLocation] user doc data: $data');

      if (data == null) return;

      final candidate = (data['profilePicture'] ??
          data['profilepicture'] ?? // being extra-safe with key spelling
          data['photoUrl'] ??
          data['avatar'] ??
          data['profilePictureUrl']) as String?;

      if (candidate != null && candidate.trim().isNotEmpty) {
        setState(() {
          _currentUserPhotoUrl = candidate.trim();
        });
        debugPrint('[SendLocation] loaded profile picture url');
      } else {
        debugPrint('[SendLocation] profile picture field empty or missing');
      }
    } catch (e, st) {
      debugPrint('[SendLocation] failed loading profile picture: $e\n$st');
    }
  }

  @override
  void dispose() {
    _sendAnimController.dispose();
    super.dispose();
  }

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
                color: Colors.black.withOpacity(0.06),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: AppBar(
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              color: _purple,
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
                icon: _isSending
                    ? SizedBox(
                        width: 28,
                        height: 28,
                        child: AnimatedBuilder(
                          animation: _sendAnimController,
                          builder: (context, child) {
                            final double anim = _sendAnimController.value;

                            // Smooth pulsing purple animation
                            return Transform.scale(
                              scale: 1 + (anim * 0.2), // gentle pulse
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF7C4DFF), // deep purple
                                      const Color(0xFFD1C4E9), // soft lavender
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    transform: GradientRotation(anim * 6.28),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C4DFF)
                                          .withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : const Icon(Icons.send, color: Color(0xFF7C4DFF)),
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Chat Rooms or Spaces',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                if (_selectedChats.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: _purple),
                        const SizedBox(width: 6),
                        Text('${_selectedChats.length} selected',
                            style: TextStyle(color: _purple)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildChatList()),
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
            icon: Icons.group_off,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 0),
            child: SizedBox(
              height: 72.0 * 6,
              child: ChatListShimmer(
                itemCount: 3,
              ),
            ),
          );
        }

        final List<Map<String, dynamic>> usersInSameSpaces =
            List<Map<String, dynamic>>.from(snapshot.data![0]);
        final List<Map<String, dynamic>> usersWithAcceptedRequests =
            List<Map<String, dynamic>>.from(snapshot.data![1]);
        final List<Map<String, dynamic>> spaceChatRooms =
            List<Map<String, dynamic>>.from(snapshot.data![2]);

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
            'isSpaceChat': true,
          };
        }

        if (uniqueUsers.isEmpty) {
          final String message = widget.isSpaceChat
              ? 'There are no members in your space yet.'
              : 'There are no space chats yet, or there are no members in your space yet.';
          return _buildEmptyState(
            message,
            icon: Icons.people_outline,
          );
        }

        final List<Map<String, dynamic>> spaceChats =
            uniqueUsers.values.where((u) => u['isSpaceChat'] == true).toList();
        final List<Map<String, dynamic>> individualUsers =
            uniqueUsers.values.where((u) => u['isSpaceChat'] != true).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
          itemCount: (spaceChats.isNotEmpty ? spaceChats.length + 1 : 0) +
              (individualUsers.isNotEmpty ? individualUsers.length + 1 : 0),
          itemBuilder: (context, index) {
            // We're building a combined list: section header(s) + items
            int cursor = 0;
            if (spaceChats.isNotEmpty) {
              // space header
              if (index == cursor) return _sectionHeader('Space Chats');
              cursor += 1;
              final int endSpaceIndex = cursor + spaceChats.length - 1;
              if (index >= cursor && index <= endSpaceIndex) {
                final item = spaceChats[index - cursor];
                return _buildChatListRow(item, isSpace: true);
              }
              cursor += spaceChats.length;
            }
            if (individualUsers.isNotEmpty) {
              if (index == cursor) return _sectionHeader('People');
              cursor += 1;
              final int endPeopleIndex = cursor + individualUsers.length - 1;
              if (index >= cursor && index <= endPeopleIndex) {
                final item = individualUsers[index - cursor];
                return _buildChatListRow(item, isSpace: false);
              }
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildChatListRow(Map<String, dynamic> userData,
      {required bool isSpace}) {
    final String chatId = userData['uid'];
    final String username = userData['username'] ?? 'Unknown';

    return InkWell(
      onTap: () {
        setState(() {
          if (_selectedChats.contains(chatId)) {
            _selectedChats.remove(chatId);
          } else {
            _selectedChats.add(chatId);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        color: Colors.transparent, // keep flat look
        child: Row(
          children: [
            // Avatar area
            if (isSpace)
              // show group icon instead of image for GC
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(
                  'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.firebasestorage.app/o/profile_pictures%2Fgroup_chat_icon.jpg?alt=media&token=7604bd51-2edf-4514-b979-e3fa84dce389',
                ),
                backgroundColor: Colors.transparent,
              )
            else
              // show current user's profile picture for People (fallback to person icon)
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade200,
                foregroundImage: (userData['profilePicture'] != null &&
                        (userData['profilePicture'] as String).isNotEmpty)
                    ? NetworkImage(userData['profilePicture'])
                    : null,
                child: (userData['profilePicture'] == null ||
                        (userData['profilePicture'] as String).isEmpty)
                    ? const Icon(Icons.person, color: Colors.black54)
                    : null,
              ),

            const SizedBox(width: 12),
            // name & subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSpace)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _purple.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Space',
                            style: TextStyle(fontSize: 12, color: _purple),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSpace
                        ? 'Group chat — tap to select'
                        : 'Tap to select person',
                    style: TextStyle(
                      fontSize: 13,
                      color: Provider.of<ThemeProvider>(context).isDarkMode
                          ? Colors.white70
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            // Purple checkbox (flat style)
            Checkbox(
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
              activeColor: _purple,
              checkColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 24,
            decoration: BoxDecoration(
              color: _purple,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
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
            if (assetPath != null) ...[
              Image.asset(
                assetPath,
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                ),
                padding: icon == Icons.group_off
                    ? const EdgeInsets.fromLTRB(8, 4, 8, 8)
                    : const EdgeInsets.all(8),
                child: Icon(
                  icon ?? Icons.chat_bubble_outline,
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

  Future<void> _sendLocation() async {
    if (_selectedChats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one chat.')),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _sendAnimController.repeat();
    });

    try {
      final String currentUserID = _auth.currentUser!.uid;
      final String currentUserEmail = _auth.currentUser!.email!;
      final Timestamp timestamp = Timestamp.now();

      final String address =
          await _geocodingService.getAddressFromLatLng(widget.currentLocation);

      final String locationMessage = '📍 My current location: $address\n'
          'https://www.google.com/maps?q=${widget.currentLocation.latitude},${widget.currentLocation.longitude}';

      for (final chatId in _selectedChats) {
        final spaceChatDoc =
            await _firestore.collection('space_chat_rooms').doc(chatId).get();
        final isSpaceChat = spaceChatDoc.exists;
        await _chatService.sendMessage(
          chatId,
          locationMessage,
          isSpaceChat: isSpaceChat,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Location sent successfully!',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green, // ✅ green background
          behavior: SnackBarBehavior.floating, // optional for a modern look
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send location: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _sendAnimController.stop();
        });
      } else {
        _sendAnimController.stop();
      }
    }
  }
}
