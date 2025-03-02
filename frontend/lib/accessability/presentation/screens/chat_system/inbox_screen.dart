import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/presentation/widgets/chatWidgets/chat_users_list.dart';
import 'package:AccessAbility/accessability/presentation/widgets/chatWidgets/chat_users_tile.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: chatService.getPendingChatRequests(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Error loading chat requests');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final requests = snapshot.data!.docs;

                if (requests.isEmpty) {
                  return const Center(child: Text('No pending chat requests'));
                }

                return ListView(
                  children: requests.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final senderID = data['senderID'];
                    final message = data['message'];

                    return FutureBuilder(
                      future: FirebaseFirestore.instance
                          .collection('Users')
                          .doc(senderID)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(
                            title: Text('Loading...'),
                          );
                        }

                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>;
                        final senderEmail = userData['email'];

                        return ChatUsersTile(
                          email: senderEmail,
                          lastMessage: message,
                          lastMessageTime: 'Pending',
                          onTap: () async {
                            await chatService.acceptChatRequest(doc.id);
                            // Navigate to chat screen
                            Navigator.pushNamed(context, '/chatconvo', arguments: {
                              'receiverEmail': senderEmail,
                              'receiverID': senderID,
                            });
                          },
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: ChatUsersList(),
          ),
        ],
      ),
    );
  }
}