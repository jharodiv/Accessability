import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/firebaseServices/auth/auth_service.dart';
import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:AccessAbility/accessability/presentation/widgets/chatWidgets/chat_users_tile.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

class ChatUsersList extends StatelessWidget {
  ChatUsersList({super.key});
  final ChatService chatService = ChatService();
  final AuthService authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildUserList(),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder(
      stream: CombineLatestStream.list([
        chatService.getUsersInSameSpaces(),
        chatService.getUsersWithAcceptedChatRequests(),
        chatService.getSpaceChatRooms(),
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
            'isSpaceChat': true,
          };
        }

        if (uniqueUsers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No chats available.'),
                SizedBox(height: 16),
                Text('Create or join a space to start chatting.'),
              ],
            ),
          );
        }

        // Separate space chats and individual users
        final List<Map<String, dynamic>> spaceChats = uniqueUsers.values
            .where((user) => user['isSpaceChat'] == true)
            .toList();
        final List<Map<String, dynamic>> individualUsers = uniqueUsers.values
            .where((user) => user['isSpaceChat'] != true)
            .toList();

        // Sort space chats by last message timestamp
        spaceChats.sort((a, b) {
          final aTimestamp = a['lastMessageTimestamp'] ?? Timestamp(0, 0);
          final bTimestamp = b['lastMessageTimestamp'] ?? Timestamp(0, 0);
          return bTimestamp.compareTo(aTimestamp);
        });

        // Sort individual users by last message timestamp
        individualUsers.sort((a, b) {
          final aTimestamp = a['lastMessageTimestamp'] ?? Timestamp(0, 0);
          final bTimestamp = b['lastMessageTimestamp'] ?? Timestamp(0, 0);
          return bTimestamp.compareTo(aTimestamp);
        });

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
              ...spaceChats.map((userData) => _buildUserListItem(userData, context)),
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
              ...individualUsers.map((userData) => _buildUserListItem(userData, context)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> userData, BuildContext context) {
    final bool isSpaceChat = userData['isSpaceChat'] == true;
    final String profilePicture = isSpaceChat
        ? 'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.firebasestorage.app/o/profile_pictures%2Fgroup_chat_icon.jpg?alt=media&token=7604bd51-2edf-4514-b979-e3fa84dce389'
        : userData['profilePicture'] ?? 'https://via.placeholder.com/150';

    if (isSpaceChat) {
      return _buildSpaceChatItem(userData, profilePicture, context);
    } else {
      return _buildIndividualChatItem(userData, profilePicture, context);
    }
  }

  Widget _buildSpaceChatItem(Map<String, dynamic> userData, String profilePicture, BuildContext context) {
    final String spaceId = userData['uid'];

    // Debug log to check the spaceId
    print('Space ID: $spaceId');

    // Validate spaceId
    if (spaceId.isEmpty) {
      return ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(profilePicture),
        ),
        title: Text(
          userData['username'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Invalid space chat room'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('space_chat_rooms')
          .doc(spaceId) // Use validated spaceId
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(profilePicture),
            ),
            title: Text(
              userData['username'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Error loading messages'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(profilePicture),
            ),
            title: Text(
              userData['username'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Loading...'),
          );
        }

        String lastMessage = '';
        String lastMessageSender = '';
        Timestamp lastMessageTimestamp = Timestamp(0, 0);

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final messageData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          lastMessage = messageData['message'];
          lastMessageSender = messageData['senderID'];
          lastMessageTimestamp = messageData['timestamp'];
        }

        // Debug log to check the lastMessageSender
        print('Last Message Sender: $lastMessageSender');

        // Validate lastMessageSender
        if (lastMessageSender.isEmpty) {
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(profilePicture),
            ),
            title: Text(
              userData['username'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              lastMessage.isNotEmpty
                  ? 'Unknown: $lastMessage'
                  : 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('Users')
              .doc(lastMessageSender)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.hasError) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(profilePicture),
                ),
                title: Text(
                  userData['username'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Error loading sender info'),
              );
            }

            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(profilePicture),
                ),
                title: Text(
                  userData['username'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Loading sender info...'),
              );
            }

            String senderUsername = 'Unknown';

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final user = userSnapshot.data!.data() as Map<String, dynamic>;
              senderUsername = user['username'] ?? 'Unknown';
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(profilePicture),
              ),
              title: Text(
                userData['username'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                lastMessage.isNotEmpty
                    ? '$senderUsername: $lastMessage'
                    : 'No messages yet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: Text(
                _formatTimestamp(lastMessageTimestamp),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/chatconvo',
                  arguments: {
                    'receiverUsername': userData['username'],
                    'receiverID': userData['uid'],
                    'isSpaceChat': true,
                    'receiverProfilePicture': profilePicture,
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildIndividualChatItem(Map<String, dynamic> userData, String profilePicture, BuildContext context) {
    if (userData['email'] != authService.getCurrentUser()!.email) {
      final String chatRoomID = _getChatRoomID(userData['uid']);

      // Debug log to check the chatRoomID
      print('Chat Room ID: $chatRoomID');

      // Validate chatRoomID
      if (chatRoomID.isEmpty) {
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(profilePicture),
          ),
          title: Text(
            userData['username'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Invalid chat room'),
        );
      }

      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(chatRoomID) // Use validated chatRoomID
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(profilePicture),
              ),
              title: Text(
                userData['username'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Error loading messages'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(profilePicture),
              ),
              title: Text(
                userData['username'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Loading...'),
            );
          }

          String lastMessage = '';
          String lastMessageSender = '';
          Timestamp lastMessageTimestamp = Timestamp(0, 0);

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final messageData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
            lastMessage = messageData['message'];
            lastMessageSender = messageData['senderID'];
            lastMessageTimestamp = messageData['timestamp'];
          }

          // Debug log to check the lastMessageSender
          print('Last Message Sender: $lastMessageSender');

          // Validate lastMessageSender
          if (lastMessageSender.isEmpty) {
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(profilePicture),
              ),
              title: Text(
                userData['username'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                lastMessage.isNotEmpty
                    ? 'Unknown: $lastMessage'
                    : 'No messages yet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('Users')
                .doc(lastMessageSender)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.hasError) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(profilePicture),
                  ),
                  title: Text(
                    userData['username'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Error loading sender info'),
                );
              }

              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(profilePicture),
                  ),
                  title: Text(
                    userData['username'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Loading sender info...'),
                );
              }

              String senderUsername = 'Unknown';

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final user = userSnapshot.data!.data() as Map<String, dynamic>;
                senderUsername = user['username'] ?? 'Unknown';
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(profilePicture),
                ),
                title: Text(
                  userData['username'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  lastMessage.isNotEmpty
                      ? '$senderUsername: $lastMessage'
                      : 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: Text(
                  _formatTimestamp(lastMessageTimestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                onTap: () {
                  Navigator.pushNamed(context, '/chatconvo', arguments: {
                    'receiverUsername': userData['username'],
                    'receiverID': userData['uid'],
                    'receiverProfilePicture': profilePicture,
                  });
                },
              );
            },
          );
        },
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  String _getChatRoomID(String userID) {
    // Ensure userID is not empty
    if (userID.isEmpty) {
      print('Error: userID is empty');
      return '';
    }

    List<String> ids = [authService.getCurrentUser()!.uid, userID];
    ids.sort();
    return ids.join('_');
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime now = DateTime.now();
    final DateTime messageDate = timestamp.toDate();
    final Duration difference = now.difference(messageDate);

    if (difference.inDays == 0) {
      // Today
      return DateFormat('h:mm a').format(messageDate);
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday, ${DateFormat('h:mm a').format(messageDate)}';
    } else if (difference.inDays <= 2) {
      // Within 2 days
      return DateFormat('EEEE, h:mm a').format(messageDate);
    } else {
      // More than 3 days
      return DateFormat('MMM d, h:mm a').format(messageDate);
    }
  }
}