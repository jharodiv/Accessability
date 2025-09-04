import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:accessability/accessability/presentation/widgets/chatWidgets/chat_users_list.dart';
import 'package:accessability/accessability/presentation/widgets/chatWidgets/chat_users_tile.dart';
import 'package:provider/provider.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:easy_localization/easy_localization.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  _InboxScreenState createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final ChatService chatService = ChatService();

  @override
  void initState() {
    super.initState();

    // Listen for new messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Refresh the chat list or show a notification
      setState(() {});
    });
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
              onPressed: () {
                Navigator.of(context).pop();
              },
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
        child: Column(
          children: [
            // Chat Users List (Moved to the top)
            Expanded(
              child: ChatUsersList(),
            ),

            // Chat Requests Section (Only shown if there are requests)
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: chatService.getVerificationCodeChatRequests(),
              builder: (context, snapshot) {
                // If there was an error loading requests, show the "no messages" asset
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 24.0, horizontal: 16.0),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 220,
                          child: Image.asset(
                            'assets/images/others/nomessage.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your Inbox is Empty',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink(); // Hide while loading
                }

                final requests = snapshot.data ?? [];

                if (requests.isEmpty) {
                  return const SizedBox.shrink(); // Hide if no requests
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

                    return Column(
                      children: [
                        // Chat Requests Header (matching other sections)
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
                        // List of chat requests
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredRequests.length,
                          itemBuilder: (context, index) {
                            final request = filteredRequests[index];
                            final metadata =
                                request['metadata'] as Map<String, dynamic>?;
                            final isVerificationRequest = metadata != null &&
                                metadata['type'] == 'verification_code';

                            // Check if request is expired
                            final expiresAtString =
                                metadata?['expiresAt'] as String?;
                            final isExpired = expiresAtString != null &&
                                DateTime.now()
                                    .isAfter(DateTime.parse(expiresAtString));

                            // Auto-decline expired requests
                            if (isExpired) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                chatService.rejectChatRequest(request['id']);
                              });
                              return const SizedBox.shrink();
                            }

                            if (isVerificationRequest) {
                              return _buildVerificationRequestItem(
                                  request, isDarkMode);
                            } else {
                              return _buildRegularRequestItem(
                                  request, isDarkMode);
                            }
                          },
                        ),
                      ],
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

  Widget _buildVerificationRequestItem(
      Map<String, dynamic> request, bool isDarkMode) {
    final metadata = request['metadata'] as Map<String, dynamic>;
    final spaceName = metadata['spaceName'] as String? ?? 'Space';
    final verificationCode = metadata['verificationCode'] as String? ?? '';
    final expiresAt = DateTime.parse(metadata['expiresAt'] as String? ??
        DateTime.now().add(Duration(minutes: 10)).toIso8601String());

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue,
        child: Icon(Icons.vpn_key, color: Colors.white),
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
      trailing: Icon(Icons.arrow_forward_ios,
          size: 16, color: isDarkMode ? Colors.white70 : Colors.grey[600]),
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
    );
  }

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
                icon: Icon(Icons.check, color: Colors.green),
                onPressed: () => chatService.acceptChatRequest(request['id']),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.red),
                onPressed: () => chatService.rejectChatRequest(request['id']),
              ),
            ],
          ),
        );
      },
    );
  }

  // Filter out chat requests from users in the same space
  Future<List<Map<String, dynamic>>> _filterRequestsFromSpaceMembers(
      List<Map<String, dynamic>> requests) async {
    final currentUserID = FirebaseAuth.instance.currentUser!.uid;

    // Fetch all spaces the current user is in
    final spacesSnapshot = await FirebaseFirestore.instance
        .collection('space_chat_rooms')
        .where('members', arrayContains: currentUserID)
        .get();

    final Set<String> spaceMemberIds = {};

    // Collect all member IDs from the spaces
    for (final spaceDoc in spacesSnapshot.docs) {
      final members = List<String>.from(spaceDoc['members'] ?? []);
      spaceMemberIds.addAll(members);
    }

    // Filter out requests from users in the same space
    return requests.where((request) {
      final senderID = request['senderID'];
      return !spaceMemberIds.contains(senderID);
    }).toList();
  }
}
