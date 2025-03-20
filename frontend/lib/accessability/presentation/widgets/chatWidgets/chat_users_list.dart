import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:AccessAbility/accessability/firebaseServices/auth/auth_service.dart';
import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:provider/provider.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';

class ChatUsersList extends StatelessWidget {
  ChatUsersList({super.key});
  final ChatService chatService = ChatService();
  final AuthService authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      body: _buildUserList(isDarkMode),
    );
  }

  Widget _buildUserList(bool isDarkMode) {
    return StreamBuilder(
      stream: CombineLatestStream.list([
        chatService.getUsersInSameSpaces(),
        chatService.getUsersWithAcceptedChatRequests(),
        chatService.getSpaceChatRooms(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading chats.',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<Map<String, dynamic>> usersInSameSpaces = snapshot.data![0];
        final List<Map<String, dynamic>> usersWithAcceptedRequests = snapshot.data![1];
        final List<Map<String, dynamic>> spaceChatRooms = snapshot.data![2];

        final Map<String, Map<String, dynamic>> uniqueUsers = {};

        // Add users in the same spaces (excluding space chat rooms)
        for (var user in usersInSameSpaces) {
          uniqueUsers[user['uid']] = user;
        }

        // Add users with accepted chat requests
        for (var user in usersWithAcceptedRequests) {
          uniqueUsers[user['uid']] = user;
        }

        // Add space chat rooms as a separate entity
        for (var space in spaceChatRooms) {
          uniqueUsers[space['id']] = {
            'uid': space['id'],
            'username': space['name'],
            'isSpaceChat': true,
          };
        }

        if (uniqueUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No chats available.',
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create or join a space to start chatting.',
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                ),
              ],
            ),
          );
        }

        // Separate space chat rooms from individual users
        final List<Map<String, dynamic>> spaceChats = uniqueUsers.values
            .where((user) => user['isSpaceChat'] == true)
            .toList();
        final List<Map<String, dynamic>> individualUsers = uniqueUsers.values
            .where((user) => user['isSpaceChat'] != true)
            .toList();

        // Display space chat rooms and individual users separately
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (spaceChats.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Space Chats',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.grey,
                  ),
                ),
              ),
              ...spaceChats.map((userData) {
                final String profilePicture = userData['isSpaceChat'] == true
                    ? 'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.firebasestorage.app/o/profile_pictures%2Fgroup_chat_icon.jpg?alt=media&token=7604bd51-2edf-4514-b979-e3fa84dce389'
                    : userData['profilePicture'] ?? 'https://via.placeholder.com/150';
                return _buildSpaceChatItem(userData, profilePicture, context, isDarkMode);
              }),
              const Divider(thickness: 1, height: 20),
            ],
            if (individualUsers.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'People',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.grey,
                  ),
                ),
              ),
              ...individualUsers.map((userData) {
                final String profilePicture = userData['profilePicture'] ?? 'https://via.placeholder.com/150';
                return _buildIndividualChatItem(userData, profilePicture, context, isDarkMode);
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSpaceChatItem(Map<String, dynamic> userData, String profilePicture, BuildContext context, bool isDarkMode) {
    final String spaceId = userData['uid'];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('space_chat_rooms')
          .doc(spaceId)
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              'Error loading messages',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(profilePicture),
            ),
            title: Text(
              userData['username'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              'Loading...',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
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

        userData['lastMessageTimestamp'] = lastMessageTimestamp;

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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  'Error loading sender info',
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                ),
              );
            }

            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(profilePicture),
                ),
                title: Text(
                  userData['username'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  'Loading sender info...',
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                lastMessage.isNotEmpty
                    ? '$senderUsername: $lastMessage'
                    : 'No messages yet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.grey[600]),
              ),
              trailing: Text(
                _formatTimestamp(lastMessageTimestamp),
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.grey[600], fontSize: 12),
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

  Widget _buildIndividualChatItem(Map<String, dynamic> userData, String profilePicture, BuildContext context, bool isDarkMode) {
    final String? currentUserUID = authService.getCurrentUser()?.uid;
    if (currentUserUID == null || userData['uid'] == null) {
      return ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(profilePicture),
        ),
        title: Text(
          userData['username'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Text(
          'Error: Invalid user data',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
      );
    }

    if (userData['email'] != authService.getCurrentUser()!.email) {
      final String chatRoomID = _getChatRoomID(userData['uid']);

      return FutureBuilder<bool>(
        future: chatService.hasChatRoom(currentUserUID, userData['uid']),
        builder: (context, chatRoomSnapshot) {
          if (chatRoomSnapshot.connectionState == ConnectionState.waiting) {
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(profilePicture),
              ),
              title: Text(
                userData['username'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                'Loading...',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              ),
            );
          }

          if (chatRoomSnapshot.hasError || !chatRoomSnapshot.data!) {
            // If the chat room doesn't exist, create it
            chatService.createChatRoomForMembers(currentUserUID, userData['uid'], 'Unnamed Space');
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(profilePicture),
              ),
              title: Text(
                userData['username'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                'Creating chat room...',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              ),
            );
          }

          // If the chat room exists, show the chat
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chat_rooms')
                .doc(chatRoomID)
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Error loading messages',
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(profilePicture),
                  ),
                  title: Text(
                    userData['username'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Loading...',
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  ),
                );
              }

              String lastMessage = 'No messages yet';
              String lastMessageSender = '';
              Timestamp lastMessageTimestamp = Timestamp(0, 0);

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                final messageData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                lastMessage = messageData['message'];
                lastMessageSender = messageData['senderID'];
                lastMessageTimestamp = messageData['timestamp'];
              }

              userData['lastMessageTimestamp'] = lastMessageTimestamp;

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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        'Error loading sender info',
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      ),
                    );
                  }

                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(profilePicture),
                      ),
                      title: Text(
                        userData['username'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        'Loading sender info...',
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      ),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      lastMessage.isNotEmpty
                          ? '$senderUsername: $lastMessage'
                          : 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.grey[600]),
                    ),
                    trailing: Text(
                      _formatTimestamp(lastMessageTimestamp),
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.grey[600], fontSize: 12),
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
        },
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  String _getChatRoomID(String userID) {
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
      return DateFormat('h:mm a').format(messageDate);
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(messageDate)}';
    } else if (difference.inDays <= 2) {
      return DateFormat('EEEE, h:mm a').format(messageDate);
    } else {
      return DateFormat('MMM d, h:mm a').format(messageDate);
    }
  }
}