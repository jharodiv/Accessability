// lib/presentation/screens/space_management_screen.dart
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:accessability/accessability/presentation/widgets/space_management_widgets/space_management_list.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String _kSavedActiveSpaceKey = 'saved_active_space_id';

  String? _selectedSpaceId;
  String? _selectedSpaceName;

  /// Ensures we only auto-select a default from the snapshot once per screen lifecycle.
  bool _didInitializeFromSnapshot = false;

  @override
  void initState() {
    super.initState();
    _restoreSavedActiveSpace();
  }

  // Restore saved active space id & try to get its name (best-effort).
  Future<void> _restoreSavedActiveSpace() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_kSavedActiveSpaceKey);
      if (id != null && id.isNotEmpty) {
        // try to fetch the doc to read its name
        try {
          final doc = await _firestore.collection('Spaces').doc(id).get();
          if (doc.exists) {
            final name = (doc.data() as Map<String, dynamic>)['name'] ?? '';
            if (mounted) {
              setState(() {
                _selectedSpaceId = id;
                _selectedSpaceName = name.toString();
              });
            }
            return;
          } else {
            // saved id no longer valid -> remove
            await prefs.remove(_kSavedActiveSpaceKey);
          }
        } catch (e) {
          // Firestore error: still keep the id so we can try to match it against stream later
          if (mounted) {
            setState(() {
              _selectedSpaceId = id;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('restore saved space error: $e');
    }
  }

  // Persist active space selection and update local state
  Future<void> _saveActiveSpace(String id, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSavedActiveSpaceKey, id);
      if (mounted) {
        setState(() {
          _selectedSpaceId = id;
          _selectedSpaceName = name;
        });
      }
    } catch (e) {
      debugPrint('save active space error: $e');
    }
  }

  // Clear saved active space (used when a selected space is deleted/left)
  Future<void> _clearSavedActiveSpace() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSavedActiveSpaceKey);
      if (mounted) {
        setState(() {
          _selectedSpaceId = null;
          _selectedSpaceName = null;
          // allow snapshot initialization again
          _didInitializeFromSnapshot = false;
        });
      }
    } catch (e) {
      debugPrint('clear saved active space error: $e');
    }
  }

  Future<void> _renameSpace(String? spaceId, String newName) async {
    if (spaceId == null || spaceId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('noSpaceSelected'.tr())),
        );
      }
      return;
    }

    try {
      // update firestore
      await _firestore.collection('Spaces').doc(spaceId).update({
        'name': newName,
        'updatedAt': FieldValue.serverTimestamp(), // optional
      });

      // update saved active space name + local state (also persists to prefs)
      await _saveActiveSpace(spaceId, newName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('spaceNameUpdated'.tr())), // add key to translations
        );
      }
    } catch (e) {
      debugPrint('Error renaming space: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('errorUpdatingSpaceName'.tr())),
        );
      }
    }
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
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4),
            ),
            title: Text(
              _selectedSpaceName?.isNotEmpty == true
                  ? _selectedSpaceName!
                  : 'spaceManagement'.tr(),
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
            // Loading & error handling
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

            // One-time initialization from snapshot:
            // If we don't yet have a selected space id, pick saved or default to the first.
            if (!_didInitializeFromSnapshot) {
              _didInitializeFromSnapshot = true;

              // If we already had a saved id (from prefs) but no name, try to find name in snapshot
              if (_selectedSpaceId != null && _selectedSpaceId!.isNotEmpty) {
                final found = spaces.firstWhere(
                  (d) => d.id == _selectedSpaceId,
                  orElse: () => throw Exception(),
                );
              }

              // Safer loop-based approach to find saved id or default:
              String? foundId;
              String? foundName;
              for (final d in spaces) {
                if (_selectedSpaceId != null &&
                    _selectedSpaceId!.isNotEmpty &&
                    d.id == _selectedSpaceId) {
                  foundId = d.id;
                  foundName = ((d.data() as Map<String, dynamic>)['name'] ?? '')
                      .toString();
                  break;
                }
              }

              if (foundId != null) {
                // We found the saved id inside the snapshot -> ensure name is set
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _selectedSpaceId = foundId;
                      _selectedSpaceName = foundName ?? _selectedSpaceName;
                    });
                  }
                });
              } else {
                // No saved id in the snapshot - choose the first available space as default
                final first = spaces.first;
                final defaultId = first.id;
                final defaultName =
                    ((first.data() as Map<String, dynamic>)['name'] ?? '')
                        .toString();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Persist and update UI after build finishes
                  _saveActiveSpace(defaultId, defaultName);
                });
              }
            }

            return SpaceManagementList(
              spaceId: _selectedSpaceId,
              spaceName: _selectedSpaceName,
              onViewAdmin: () {
                if (_selectedSpaceId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select a space'.tr())),
                  );
                  return;
                }
                // Your existing view-admin flow (or a dialog) using _selectedSpaceId.
                // _showAdminStatusForSelectedSpace();
              },
              onAddPeople: () {
                if (_selectedSpaceId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select a space'.tr())),
                  );
                  return;
                }
                // Open invite flow using _selectedSpaceId
              },
              onLeave: () {
                if (_selectedSpaceId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select a space'.tr())),
                  );
                  return;
                }
                _showLeaveSpaceDialog(
                    _selectedSpaceId!, _selectedSpaceName ?? '');
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
          // small header row: show active chip or "Set as active" button
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: [
                Expanded(child: SizedBox()), // push control to the right
                if (_selectedSpaceId == spaceId)
                  Chip(
                    label: Text('Active',
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: const Color(0xFF6750A4),
                  )
                else
                  TextButton(
                    onPressed: () => _saveActiveSpace(spaceId, spaceName),
                    child: Text('setAsActive'.tr(),
                        style: const TextStyle(color: Color(0xFF6750A4))),
                  ),
              ],
            ),
          ),

          // Members list (streaming user docs)
          StreamBuilder<QuerySnapshot>(
            stream: memberIds.isNotEmpty
                ? _firestore
                    .collection('Users')
                    .where('uid', whereIn: memberIds)
                    .snapshots()
                : const Stream.empty(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                    trailing: (isCreator && !isCurrentUser)
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
      // show spinner for this space
      setState(() {
        _deletingSpaces.add(spaceId);
      });

      final currentUser = _auth.currentUser;
      final currentUsername = await _getUsername(currentUser!.uid);

      // First cleanup related data
      await _cleanupSpaceData(spaceId);

      // Send notification before deletion
      final chatService = ChatService();
      await chatService.notifySpaceDeleted(spaceId, spaceName);

      // Then delete the space document
      await _firestore.collection('Spaces').doc(spaceId).delete();

      // If deleted space was the selected one, clear saved active selection
      if (_selectedSpaceId == spaceId) {
        await _clearSavedActiveSpace();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('spaceDeleted'.tr())),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('errorDeletingSpace'.tr())),
      );
      print("Error deleting space: $e");
    } finally {
      setState(() {
        _deletingSpaces.remove(spaceId);
      });
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

      // If left space was the selected one, clear saved active selection
      if (_selectedSpaceId == spaceId) {
        await _clearSavedActiveSpace();
      }

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
