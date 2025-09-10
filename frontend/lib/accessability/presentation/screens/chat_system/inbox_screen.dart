import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:accessability/accessability/presentation/widgets/chatWidgets/chat_users_list.dart';
import 'package:provider/provider.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  _InboxScreenState createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final ChatService chatService = ChatService();
  final DraggableScrollableController _draggableController =
      DraggableScrollableController();
  final double _initialChildSize = 0.25;
  final double _minChildSize = 0.25; // bottom limit = initial placement
  final double _maxChildSize = 0.8;

  @override
  void initState() {
    super.initState();

    // Listen for new messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      setState(() {}); // refresh UI
    });
  }

  @override
  void dispose() {
    _draggableController.dispose();
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
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: AppBar(
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4),
            ),
            title: Text(
              'inbox'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: Container(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        child: Stack(
          children: [
            /// Chat Users List takes the background
            ChatUsersList(),

            /// Chat Requests as draggable sheet
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: chatService.getVerificationCodeChatRequests(),
              builder: (context, snapshot) {
                if (snapshot.hasError || !snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final requests = snapshot.data ?? [];
                // remove expired ones immediately so UI never shows them
                final activeRequests = _removeExpiredRequests(requests);

                if (activeRequests.isEmpty) {
                  return const SizedBox.shrink();
                }
                if (requests.isEmpty) {
                  return const SizedBox.shrink();
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _filterRequestsFromSpaceMembers(requests),
                  builder: (context, filteredSnapshot) {
                    if (filteredSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }

                    final filteredRequests = filteredSnapshot.data ?? [];

                    if (filteredRequests.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    /// Draggable sheet for requests
                    return DraggableScrollableSheet(
                      controller: _draggableController,
                      initialChildSize: _initialChildSize,
                      minChildSize: _minChildSize,
                      maxChildSize: _maxChildSize,
                      builder: (context, scrollController) {
                        // Make the entire sheet respond to vertical drags,
                        // but only when the inner ListView is at its top (so scrolling still works).
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (DragUpdateDetails details) {
                            // if inner list is scrolled (not at top), don't drag the sheet
                            if (scrollController.hasClients &&
                                scrollController.position.pixels > 0) return;

                            final screenHeight =
                                MediaQuery.of(context).size.height;
                            final delta = -details.delta.dy /
                                screenHeight; // up -> positive
                            final newSize = (_draggableController.size + delta)
                                .clamp(_minChildSize, _maxChildSize);
                            _draggableController.jumpTo(newSize);
                          },
                          onVerticalDragEnd: (DragEndDetails details) {
                            // if inner list is scrolled (not at top), do nothing
                            if (scrollController.hasClients &&
                                scrollController.position.pixels > 0) return;

                            final velocity = details.primaryVelocity ?? 0.0;
                            double target;
                            if (velocity < -200) {
                              // fast swipe up
                              target = _maxChildSize;
                            } else if (velocity > 200) {
                              // fast swipe down
                              target = _minChildSize;
                            } else {
                              final mid = (_minChildSize + _maxChildSize) / 2;
                              target = (_draggableController.size >= mid)
                                  ? _maxChildSize
                                  : _minChildSize;
                            }
                            _draggableController.animateTo(target,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  isDarkMode ? Colors.grey[850] : Colors.white,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // simple handle (no separate gestures — whole sheet handles it now)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    margin: const EdgeInsets.only(
                                        top: 8, bottom: 8),
                                    height: 5,
                                    width: 50,
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.white24
                                          : Colors.grey[400],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),

                                // Header
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Chat Requests',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.grey[700],
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${filteredRequests.length}',
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white60
                                              : Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // List
                                Expanded(
                                  child: ListView.builder(
                                    controller: scrollController,
                                    itemCount: filteredRequests.length,
                                    itemBuilder: (context, index) {
                                      final request = filteredRequests[index];
                                      final metadata = request['metadata']
                                          as Map<String, dynamic>?;

                                      // safe-check the metadata['type'] value and only treat it as verification when it's exactly 'verification_code'
                                      final isVerificationRequest =
                                          metadata != null &&
                                              metadata['type']?.toString() ==
                                                  'verification_code';

                                      if (isVerificationRequest) {
                                        return _buildVerificationRequestItem(
                                            request, isDarkMode);
                                      } else {
                                        return _buildRegularRequestItem(
                                            request, isDarkMode);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build Verification Request
  Widget _buildVerificationRequestItem(
      Map<String, dynamic> request, bool isDarkMode) {
    final metadata = request['metadata'] as Map<String, dynamic>;
    final spaceName = metadata['spaceName'] as String? ?? 'Space';
    final verificationCode = metadata['verificationCode'] as String? ?? '';
    final expiresAt = DateTime.parse(metadata['expiresAt'] as String? ??
        DateTime.now().add(const Duration(minutes: 10)).toIso8601String());

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple,
          child: const Icon(Icons.vpn_key, color: Colors.white),
        ),
        title: Text(
          'Space Invitation: $spaceName',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Code: $verificationCode',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            Text(
              'Expires: ${DateFormat('MMM d, h:mm a').format(expiresAt)}',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.deepPurple,
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/verificationRequest',
            arguments: {
              'requestId': request['id'],
              'spaceId': metadata['spaceId'],
              'spaceName': spaceName,
              'verificationCode': verificationCode,
              'expiresAt': expiresAt,
              'senderID': request['senderID'],
            },
          );
        },
      ),
    );
  }

  /// Build Regular Request
  Widget _buildRegularRequestItem(
      Map<String, dynamic> request, bool isDarkMode) {
    final senderID = request['senderID'];
    final message = request['message'];

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('Users').doc(senderID).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            title: Text('Loading...',
                style:
                    TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
          );
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return ListTile(
            title: Text('Unknown user',
                style:
                    TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            subtitle: Text(message ?? '',
                style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54)),
          );
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final senderUsername =
            userData['username'] ?? userData['firstName'] ?? 'User';
        final profilePicture = userData['profilePicture'] ??
            'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.firebasestorage.app/o/profile_pictures%2Fdefault_profile.png?alt=media&token=bc7a75a7-a78e-4460-b816-026a8fc341ba';

        return ListTile(
          leading: CircleAvatar(backgroundImage: NetworkImage(profilePicture)),
          title: Text(senderUsername,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black,
              )),
          subtitle: Text(message ?? '',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              )),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () => chatService.acceptChatRequest(request['id']),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => chatService.rejectChatRequest(request['id']),
              ),
            ],
          ),
        );
      },
    );
  }

  // call this to filter out expired requests and auto-reject them
  List<Map<String, dynamic>> _removeExpiredRequests(
      List<Map<String, dynamic>> requests) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> valid = [];

    for (final req in requests) {
      try {
        final metadata = req['metadata'] as Map<String, dynamic>?;
        final expiresAtStr = metadata?['expiresAt'] as String?;
        if (expiresAtStr == null) {
          // no expiry info -> keep
          valid.add(req);
          continue;
        }

        final expiresAt = DateTime.parse(expiresAtStr);
        if (expiresAt.isAfter(now)) {
          // still valid
          valid.add(req);
        } else {
          // expired -> request removal (do it after frame to avoid setState during build)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              chatService.rejectChatRequest(req['id']);
            } catch (_) {}
          });
        }
      } catch (e) {
        // parsing error or unexpected shape -> keep (safer)
        valid.add(req);
      }
    }

    return valid;
  }

  /// Filter out requests from users in the same space
  Future<List<Map<String, dynamic>>> _filterRequestsFromSpaceMembers(
      List<Map<String, dynamic>> requests) async {
    final currentUserID = FirebaseAuth.instance.currentUser!.uid;

    final spacesSnapshot = await FirebaseFirestore.instance
        .collection('space_chat_rooms')
        .where('members', arrayContains: currentUserID)
        .get();

    final Set<String> allMembersInUserSpaces = {};

    for (final spaceDoc in spacesSnapshot.docs) {
      final members = List<String>.from(spaceDoc['members'] ?? []);
      allMembersInUserSpaces.addAll(members);
    }

    return requests.where((request) {
      final senderID = request['senderID'];
      final isPending = request['status'] == 'pending';
      final senderAlreadyMember = allMembersInUserSpaces.contains(senderID);

      return isPending && !senderAlreadyMember;
    }).toList();
  }
}
