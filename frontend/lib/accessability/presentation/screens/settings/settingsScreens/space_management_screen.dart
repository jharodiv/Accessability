import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:provider/provider.dart';

class SpaceManagementScreen extends StatefulWidget {
  const SpaceManagementScreen({super.key});

  @override
  _SpaceManagementScreenState createState() => _SpaceManagementScreenState();
}

class _SpaceManagementScreenState extends State<SpaceManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, bool> _expandedSpaces = {};
  final Set<String> _deletingSpaces = {};

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
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4),
            ),
            title: Text(
              'spaceManagement'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: Container(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('Spaces')
              .where('members', arrayContains: _auth.currentUser?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('errorLoadingSpaces'.tr()));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text('noSpacesFound'.tr()));
            }

            final spaces = snapshot.data!.docs;

            return ListView.builder(
              itemCount: spaces.length,
              itemBuilder: (context, index) {
                final space = spaces[index];
                final spaceId = space.id;
                final spaceData = space.data() as Map<String, dynamic>;
                final spaceName = spaceData['name'] ?? 'Unnamed Space';
                final creatorId = spaceData['creator'] ?? '';
                final isCreator = creatorId == _auth.currentUser?.uid;

                return _buildSpaceTile(
                  spaceId,
                  spaceName,
                  isCreator,
                  spaceData['members'] ?? [],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSpaceTile(String spaceId, String spaceName, bool isCreator,
      List<dynamic> memberIds) {
    final bool isExpanded = _expandedSpaces[spaceId] ?? false;
    final isDeleting = _deletingSpaces.contains(spaceId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        key: Key(spaceId),
        initiallyExpanded: false,
        trailing: isDeleting
            ? const CircularProgressIndicator()
            : isCreator
                ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _showDeleteSpaceDialog(spaceId, spaceName),
                  )
                : IconButton(
                    icon: const Icon(Icons.exit_to_app, color: Colors.orange),
                    onPressed: () => _showLeaveSpaceDialog(spaceId, spaceName),
                  ),
        title: Text(
          spaceName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDeleting ? Colors.grey : null,
          ),
        ),
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('Users')
                .where('uid', whereIn: memberIds)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                );
              }

              if (!snapshot.hasData) {
                return const SizedBox();
              }

              final members = snapshot.data!.docs;

              return Column(
                children: members.map((memberDoc) {
                  final memberData = memberDoc.data() as Map<String, dynamic>;
                  final memberId = memberDoc.id;
                  final username = memberData['username'] ?? 'Unknown';
                  final profilePicture = memberData['profilePicture'] ?? '';
                  final isCurrentUser = memberId == _auth.currentUser?.uid;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: profilePicture.isNotEmpty
                          ? NetworkImage(profilePicture)
                          : const AssetImage(
                                  'assets/images/others/default_profile.png')
                              as ImageProvider,
                    ),
                    title: Text(username),
                    subtitle: isCurrentUser ? Text('you'.tr()) : null,
                    trailing: isCreator && !isCurrentUser
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red),
                            onPressed: () => _showRemoveMemberDialog(
                                spaceId, spaceName, memberId, username),
                          )
                        : null,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberDialog(
      String spaceId, String spaceName, String memberId, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('removeMember'.tr()),
        content: Text(
          'removeMemberConfirm'
              .tr()
              .replaceFirst('{username}', username)
              .replaceFirst('{spaceName}', spaceName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              _removeMemberFromSpace(spaceId, memberId, spaceName, username);
              Navigator.pop(context);
            },
            child:
                Text('remove'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteSpaceDialog(String spaceId, String spaceName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('deleteSpace'.tr()),
        content: Text(
          'deleteSpaceConfirm'.tr().replaceFirst('{spaceName}', spaceName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              _deleteSpace(spaceId, spaceName);
              Navigator.pop(context);
            },
            child:
                Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLeaveSpaceDialog(String spaceId, String spaceName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('leaveSpace'.tr()),
        content: Text(
          'leaveSpaceConfirm'.tr().replaceFirst('{spaceName}', spaceName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              _leaveSpace(spaceId, spaceName);
              Navigator.pop(context);
            },
            child: Text('leave'.tr(),
                style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMemberFromSpace(String spaceId, String memberId,
      String spaceName, String username) async {
    try {
      final currentUser = _auth.currentUser;
      final currentUsername = await _getUsername(currentUser!.uid);

      // Remove from Spaces collection
      await _firestore.collection('Spaces').doc(spaceId).update({
        'members': FieldValue.arrayRemove([memberId])
      });

      // Remove from space_chat_rooms collection using ChatService
      final chatService = ChatService();
      await chatService.removeMemberFromSpaceChatRoom(spaceId, memberId);

      // Send notification to space chat
      await chatService.notifyMemberRemoved(spaceId, username, currentUsername);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('memberRemoved'.tr())),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('errorRemovingMember'.tr())),
      );
    }
  }

  Future<void> _deleteSpace(String spaceId, String spaceName) async {
    try {
      final currentUser = _auth.currentUser;
      final currentUsername = await _getUsername(currentUser!.uid);

      // First cleanup related data
      await _cleanupSpaceData(spaceId);

      // Send notification before deletion
      final chatService = ChatService();
      await chatService.notifySpaceDeleted(spaceId, spaceName);

      // Then delete the space document
      await _firestore.collection('Spaces').doc(spaceId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('spaceDeleted'.tr())),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('errorDeletingSpace'.tr())),
      );
      print("Error deleting space: $e");
    }
  }

  Future<void> _leaveSpace(String spaceId, String spaceName) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final currentUsername = await _getUsername(currentUserId);

      // Remove from Spaces collection
      await _firestore.collection('Spaces').doc(spaceId).update({
        'members': FieldValue.arrayRemove([currentUserId])
      });

      // Remove from space_chat_rooms collection using ChatService
      final chatService = ChatService();
      await chatService.removeMemberFromSpaceChatRoom(spaceId, currentUserId);

      // Send notification to space chat
      await chatService.notifyMemberLeft(spaceId, currentUsername);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('spaceLeft'.tr())),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('errorLeavingSpace'.tr())),
      );
    }
  }

  Future<String> _getUsername(String userId) async {
    try {
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      return userDoc['username'] ?? 'Unknown User';
    } catch (e) {
      return 'Unknown User';
    }
  }

  Future<void> _cleanupSpaceData(String spaceId) async {
    try {
      print("Starting cleanup for space: $spaceId");

      // 1. Delete space chats and messages
      await _cleanupSpaceChats(spaceId);

      // 2. Delete space locations
      await _cleanupSpaceLocations(spaceId);

      // 3. Delete space invitations
      await _cleanupSpaceInvitations(spaceId);

      // 4. Delete any other space-related data
      await _cleanupOtherSpaceData(spaceId);

      print("Cleanup completed for space: $spaceId");
    } catch (e) {
      print("Error cleaning up space data: $e");
      // Don't throw here - we want to continue with space deletion even if cleanup fails
    }
  }

  Future<void> _cleanupSpaceChats(String spaceId) async {
    try {
      // Delete chat conversations in this space
      final chatQuery = await _firestore
          .collection('Chats')
          .where('spaceId', isEqualTo: spaceId)
          .get();

      final batch = _firestore.batch();
      for (final chat in chatQuery.docs) {
        // Also delete all messages in this chat
        final messagesQuery = await _firestore
            .collection('Chats')
            .doc(chat.id)
            .collection('messages')
            .get();

        for (final message in messagesQuery.docs) {
          batch.delete(message.reference);
        }

        batch.delete(chat.reference);
      }

      await batch.commit();
      print("Deleted ${chatQuery.docs.length} chats for space $spaceId");
    } catch (e) {
      print("Error cleaning up space chats: $e");
    }
  }

  Future<void> _cleanupSpaceLocations(String spaceId) async {
    try {
      // Delete space-specific location data
      final locationQuery = await _firestore
          .collection('SpaceLocations')
          .where('spaceId', isEqualTo: spaceId)
          .get();

      final batch = _firestore.batch();
      for (final location in locationQuery.docs) {
        batch.delete(location.reference);
      }

      await batch.commit();
      print(
          "Deleted ${locationQuery.docs.length} locations for space $spaceId");
    } catch (e) {
      print("Error cleaning up space locations: $e");
    }
  }

  Future<void> _cleanupSpaceInvitations(String spaceId) async {
    try {
      // Delete any pending invitations for this space
      final invitationQuery = await _firestore
          .collection('SpaceInvitations')
          .where('spaceId', isEqualTo: spaceId)
          .get();

      final batch = _firestore.batch();
      for (final invitation in invitationQuery.docs) {
        batch.delete(invitation.reference);
      }

      await batch.commit();
      print(
          "Deleted ${invitationQuery.docs.length} invitations for space $spaceId");
    } catch (e) {
      print("Error cleaning up space invitations: $e");
    }
  }

  Future<void> _cleanupOtherSpaceData(String spaceId) async {
    try {
      // Add any other space-related collections you might have
      // For example: SpaceSettings, SpacePermissions, etc.

      final otherCollections = ['SpaceSettings', 'SpacePermissions'];

      for (final collection in otherCollections) {
        try {
          final query = await _firestore
              .collection(collection)
              .where('spaceId', isEqualTo: spaceId)
              .get();

          final batch = _firestore.batch();
          for (final doc in query.docs) {
            batch.delete(doc.reference);
          }

          if (query.docs.isNotEmpty) {
            await batch.commit();
            print(
                "Deleted ${query.docs.length} documents from $collection for space $spaceId");
          }
        } catch (e) {
          print("Error cleaning up $collection: $e");
          // Continue with other collections
        }
      }
    } catch (e) {
      print("Error in general cleanup: $e");
    }
  }
}
