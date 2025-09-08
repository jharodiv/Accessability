// lib/presentation/screens/space_management_screen.dart
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/verification_code_widget.dart';
import 'package:accessability/accessability/presentation/widgets/space_management_widgets/change_admin_status.dart';
import 'package:accessability/accessability/presentation/widgets/space_management_widgets/space_management_list.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accessability/accessability/firebaseServices/space/space_service.dart';
import 'package:accessability/accessability/firebaseServices/space/space_service.dart';

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
  final SpaceService _spaceService = SpaceService();
  String? _lastUpdatedSpaceId;

  static const String _kSavedActiveSpaceKey = 'saved_active_space_id';

  String? _selectedSpaceId;
  String? _selectedSpaceName;
  String? _currentUserRole;

  /// Ensures we only auto-select a default from the snapshot once per screen lifecycle.
  bool _didInitializeFromSnapshot = false;

  @override
  void initState() {
    super.initState();
    _restoreSavedActiveSpace();
  }

  void _computeAndSetRoleFromDoc(DocumentSnapshot doc) {
    try {
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      final creator = (data['creator'] ?? '') as String;
      final admins = List<String>.from(data['admins'] ?? <String>[]);
      final currentUserId = _auth.currentUser?.uid ?? '';

      String role;
      if (currentUserId.isNotEmpty && creator == currentUserId) {
        role = 'owner';
      } else if (currentUserId.isNotEmpty && admins.contains(currentUserId)) {
        role = 'admin';
      } else {
        role = 'member';
      }

      if (mounted) {
        setState(() => _currentUserRole = role);
      }
    } catch (e) {
      if (mounted) setState(() => _currentUserRole = null);
    }
  }

  Future<void> _leaveSpace(String spaceId, String spaceName) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Fetch latest space doc to inspect creator, members, admins
      final snap = await _firestore.collection('Spaces').doc(spaceId).get();
      if (!snap.exists) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('spaceNotFound'.tr())));
        return;
      }

      final data = snap.data() as Map<String, dynamic>;
      final creator = (data['creator'] ?? '') as String;
      final members = List<String>.from(data['members'] ?? <String>[]);
      final admins = List<String>.from(data['admins'] ?? <String>[]);

      // CASE: current user is the creator/owner
      if (creator == currentUserId) {
        // if creator is the only member -> allow leave
        if (members.length <= 1) {
          // Proceed with leaving (no transfer needed)
        } else {
          // There are other members: require either another admin exists OR transfer ownership
          final otherAdmins = admins.where((a) => a != creator).toList();

          if (otherAdmins.isNotEmpty) {
            // There is at least one other admin -> allow leave without transfer
            // (optional: you might want to auto-promote someone as new creator, but per your rule it's not required)
          } else {
            // No other admins and other members exist -> must transfer ownership first
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('cannotLeaveAsOwner'.tr()),
                content: Text('pleaseTransferOwnershipBeforeLeaving'.tr()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('cancel'.tr()),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Open transfer flow so owner can pick new owner/admin
                      _openChangeAdminStatusForTransfer(spaceId);
                    },
                    child: Text('Transfer'.tr()),
                  ),
                ],
              ),
            );
            return; // stop here until transfer happens
          }
        }
      }

      // At this point: either user is not creator OR allowed to leave (creator + allowed condition)
      // Remove user from members
      await _firestore.collection('Spaces').doc(spaceId).update({
        'members': FieldValue.arrayRemove([currentUserId])
      });

      // Also remove from space chat room collection via ChatService
      final chatService = ChatService();
      await chatService.removeMemberFromSpaceChatRoom(spaceId, currentUserId);

      // Notify space chat that member left (best-effort)
      final currentUsername = await _getUsername(currentUserId);
      await chatService.notifyMemberLeft(spaceId, currentUsername);

      // If left space was the selected one, clear saved active selection
      if (_selectedSpaceId == spaceId) {
        await _clearSavedActiveSpace();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('spaceLeft'.tr())),
      );
    } catch (e) {
      debugPrint('Error leaving space: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('errorLeavingSpace'.tr())));
    }
  }

  void _openChangeAdminStatusForTransfer(String spaceId) async {
    try {
      // fetch up-to-date space doc
      final doc = await _spaceService.getSpace(spaceId);
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      final List<dynamic> memberIdsDynamic = data['members'] ?? <dynamic>[];
      final List<String> memberIds =
          memberIdsDynamic.map((e) => e.toString()).toList();
      final List<dynamic> adminsDynamic = data['admins'] ?? <dynamic>[];
      final List<String> adminIds =
          adminsDynamic.map((e) => e.toString()).toList();
      final String creatorId = (data['creator'] ?? '') as String;

      if (memberIds.isEmpty) return;

      final usersQuery = await _firestore
          .collection('Users')
          .where('uid', whereIn: memberIds)
          .get();
      final membersData = usersQuery.docs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        final uid = (m['uid'] ?? d.id).toString();
        return <String, dynamic>{
          'id': uid,
          'username':
              (m['username'] ?? m['displayName'] ?? 'Unknown').toString(),
          'profilePicture': (m['profilePicture'] ?? '').toString(),
          'isAdmin': adminIds.contains(uid) || (creatorId == uid),
        };
      }).toList();

      // open screen with onTransferOwnership bound to the new transfer method
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChangeAdminStatusScreen(
          members: membersData,
          currentUserId: _auth.currentUser!.uid,
          creatorId: creatorId,
          onTransferOwnership: (newOwnerId) async {
            final performedBy = _auth.currentUser!.uid;
            await _spaceService.transferOwnership(
              spaceId: spaceId,
              newOwnerId: newOwnerId,
              performedBy: performedBy,
            );
            // optional: after transfer you might automatically call leave again or notify user
          },
        ),
      ));
    } catch (e) {
      debugPrint('Error opening transfer owner flow: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('errorLoadingMembers'.tr())));
    }
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
              // compute role from the fetched doc
              _computeAndSetRoleFromDoc(doc);
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

      // compute current user's role for this space (best-effort)
      try {
        final doc = await _firestore.collection('Spaces').doc(id).get();
        if (doc.exists) _computeAndSetRoleFromDoc(doc);
      } catch (e) {
        // ignore role compute error (non-fatal)
        debugPrint('Error computing role after saveActiveSpace: $e');
      }
    } catch (e) {
      debugPrint('save active space error: $e');
    }
  }

  void _showFullWidthSnack(String message,
      {Color background = const Color(0xFF6750A4)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.fixed,
        duration: const Duration(seconds: 3),
      ),
    );
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
          _currentUserRole = null; // clear role when no space selected
          // allow snapshot initialization again
          _didInitializeFromSnapshot = false;
        });
      }
    } catch (e) {
      debugPrint('clear saved active space error: $e');
    }
  }

  Future<void> _renameSpace(String spaceId, String newName) async {
    if (spaceId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('noSpaceSelected'.tr())),
        );
      }
      return;
    }

    try {
      await _spaceService.renameSpace(spaceId, newName);

      // If this was the active space update the saved name + UI title
      if (_selectedSpaceId == spaceId) {
        await _saveActiveSpace(spaceId, newName);
      }

      // Highlight the just-updated space name
      if (mounted) {
        setState(() {
          _lastUpdatedSpaceId = spaceId;
        });
        // clear highlight after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _lastUpdatedSpaceId = null;
            });
          }
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Space name updated'.tr(),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF6750A4),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
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
              onPressed: () {
                Navigator.of(context).pop({
                  'spaceUpdated': true,
                  'spaceId': _selectedSpaceId,
                  'spaceName': _selectedSpaceName,
                });
              },
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
              final bool isDarkMode =
                  Provider.of<ThemeProvider>(context).isDarkMode;

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // bigger icon
                    Icon(
                      Icons.meeting_room_outlined,
                      size: 96, // <- bigger
                      color:
                          isDarkMode ? Colors.white70 : const Color(0xFF6750A4),
                    ),

                    const SizedBox(height: 16),

                    // title (localized)
                    Text(
                      'noSpaceSelected'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // subtitle (localized)
                    Text(
                      'goBackHomeSelectSpace'.tr(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
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
              lastUpdatedSpaceId: _lastUpdatedSpaceId, // <-- pass it here
              currentUserRole: _currentUserRole, // <-- pass role here

              onEditName: (newName) async {
                if (_selectedSpaceId != null) {
                  await _renameSpace(_selectedSpaceId!, newName);
                } else {
                  // maybe prompt user to pick a space first
                }
              },
              onViewAdmin: () async {
                if (_selectedSpaceId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select a space'.tr())),
                  );
                  return;
                }

                // show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  // fetch space doc to read members/admins/creator
                  final doc = await _spaceService.getSpace(_selectedSpaceId!);
                  final data = (doc.data() as Map<String, dynamic>?) ?? {};
                  final List<dynamic> memberIdsDynamic =
                      data['members'] ?? <dynamic>[];
                  final List<String> memberIds =
                      memberIdsDynamic.map((e) => e.toString()).toList();
                  final List<dynamic> adminsDynamic =
                      data['admins'] ?? <dynamic>[];
                  final List<String> adminIds =
                      adminsDynamic.map((e) => e.toString()).toList();
                  final String creatorId = (data['creator'] ?? '') as String;

                  // If no members (shouldn't happen since current user is a member) show placeholder screen:
                  if (memberIds.isEmpty) {
                    Navigator.of(context).pop(); // remove loader
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChangeAdminStatusScreen(
                        members: const [],
                        currentUserId: _auth.currentUser!.uid,
                        creatorId: creatorId,
                        onAddMember: () {
                          // reuse existing add flow
                          if (_selectedSpaceId != null) {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => VerificationCodeScreen(
                                  spaceId: _selectedSpaceId!,
                                  spaceName: _selectedSpaceName),
                            ));
                          }
                        },
                      ),
                    ));
                    return;
                  }

                  // fetch users data for the memberIds (batch query whereIn; keep chunking if >10 in production)
                  final usersQuery = await _firestore
                      .collection('Users')
                      .where('uid', whereIn: memberIds)
                      .get();
                  final membersData = usersQuery.docs.map((d) {
                    final m = d.data() as Map<String, dynamic>;
                    final uid = (m['uid'] ?? d.id).toString();
                    return <String, dynamic>{
                      'id': uid,
                      'username':
                          (m['username'] ?? m['displayName'] ?? 'Unknown')
                              .toString(),
                      'profilePicture': (m['profilePicture'] ?? '').toString(),
                      'isAdmin': adminIds.contains(uid) || (creatorId == uid),
                    };
                  }).toList();

                  Navigator.of(context).pop(); // remove loader
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChangeAdminStatusScreen(
                      members: membersData,
                      currentUserId: _auth.currentUser!.uid,
                      creatorId: creatorId,
                      onAddMember: () {
                        // reuse existing add flow
                        if (_selectedSpaceId != null) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => VerificationCodeScreen(
                                spaceId: _selectedSpaceId!,
                                spaceName: _selectedSpaceName),
                          ));
                        }
                      },
                      onToggleAdmin: (memberId, makeAdmin) async {
                        try {
                          final performedBy = _auth.currentUser!.uid;
                          if (makeAdmin) {
                            await _spaceService.promoteToAdmin(
                                spaceId: _selectedSpaceId!,
                                userId: memberId,
                                performedBy: performedBy);
                          } else {
                            await _spaceService.demoteAdmin(
                                spaceId: _selectedSpaceId!,
                                userId: memberId,
                                performedBy: performedBy);
                          }

                          // update UI & notify user
                          _showFullWidthSnack(makeAdmin
                              ? 'adminPromotedTo'.tr(args: [memberId])
                              : 'adminDemotedFrom'.tr(args: [memberId]));
                        } catch (e) {
                          debugPrint('Error toggling admin: $e');
                          rethrow;
                        }
                      },
                    ),
                  ));
                } catch (e) {
                  Navigator.of(context).pop(); // remove loader
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('errorLoadingMembers'.tr())));
                }
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
                // read theme locally here
                final bool isDarkMode =
                    Provider.of<ThemeProvider>(context).isDarkMode;

                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.meeting_room,
                        size: 64,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'noSpaceSelected'.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
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
