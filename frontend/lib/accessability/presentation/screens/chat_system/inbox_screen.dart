import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/presentation/widgets/chatWidgets/chat_users_list.dart';
import 'package:AccessAbility/accessability/presentation/widgets/chatWidgets/chat_users_tile.dart';
import 'package:provider/provider.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
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
            StreamBuilder<QuerySnapshot>(
              stream: chatService.getPendingChatRequests(),
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

                final requests = snapshot.data?.docs ?? [];

                if (requests.isEmpty) {
                  return const SizedBox.shrink(); // Hide if no requests
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _filterRequestsFromSpaceMembers(requests),
                  builder: (context, filteredSnapshot) {
                    if (filteredSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const SizedBox.shrink(); // Hide while loading
                    }

                    final filteredRequests = filteredSnapshot.data ?? [];

                    if (filteredRequests.isEmpty) {
                      return const SizedBox
                          .shrink(); // Hide if no filtered requests
                    }

                    return Column(
                      children: [
                        // Divider with "Message Requests" text
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Text(
                                'message_requests'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${filteredRequests.length}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        // List of filtered pending chat requests
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredRequests.length,
                          itemBuilder: (context, index) {
                            final doc = filteredRequests[index];
                            final data = doc['data'] as Map<String, dynamic>;
                            final senderID = data['senderID'];
                            final message = data['message'];

                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('Users')
                                  .doc(senderID)
                                  .get(),
                              builder: (context, userSnapshot) {
                                if (userSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return ListTile(
                                    title: Text('loading'.tr()),
                                  );
                                }

                                if (!userSnapshot.hasData ||
                                    !userSnapshot.data!.exists) {
                                  return ListTile(
                                    title: Text('unknown_user'.tr()),
                                    subtitle: Text(message ?? ''),
                                  );
                                }

                                final userData = userSnapshot.data!.data()
                                    as Map<String, dynamic>;
                                final senderUsername = userData['username'] ??
                                    userData['firstName'] ??
                                    'User';
                                final profilePicture =
                                    userData['profilePicture'] ??
                                        'https://via.placeholder.com/150';

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage:
                                        NetworkImage(profilePicture),
                                  ),
                                  title: Text(senderUsername),
                                  subtitle: Text(message ?? ''),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check,
                                            color: Colors.green),
                                        onPressed: () async {
                                          await chatService
                                              .acceptChatRequest(doc['id']);
                                          setState(
                                              () {}); // refresh after accept
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            color: Colors.red),
                                        onPressed: () async {
                                          await chatService
                                              .rejectChatRequest(doc['id']);
                                          setState(
                                              () {}); // refresh after reject
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
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

  // Filter out chat requests from users in the same space
  Future<List<Map<String, dynamic>>> _filterRequestsFromSpaceMembers(
      List<QueryDocumentSnapshot> requests) async {
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
    return requests
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final senderID = data['senderID'];
          return !spaceMemberIds.contains(senderID);
        })
        .map((doc) => {
              'id': doc.id,
              'data': doc.data(),
            })
        .toList();
  }
}
