import 'package:accessability/accessability/firebaseServices/space/space_service.dart';
import 'package:accessability/accessability/firebaseServices/space/user_service.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:accessability/accessability/presentation/widgets/shimmer/shimmer_change_admin_status.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef VoidAdminToggle = Future<void> Function(
    String memberId, bool makeAdmin);
typedef VoidTransferOwnership = Future<void> Function(String newOwnerId);

class ChangeAdminStatusScreen extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final String currentUserId;
  final String creatorId;
  final String? spaceId; // optional - allow screen to load members by space
  final bool autoLoadMembers; // set true to auto-load members from spaceId
  final VoidCallback? onAddMember;
  final VoidAdminToggle? onToggleAdmin;
  final VoidTransferOwnership? onTransferOwnership;

  const ChangeAdminStatusScreen({
    Key? key,
    this.members = const [],
    required this.currentUserId,
    required this.creatorId,
    this.spaceId,
    this.autoLoadMembers = false,
    this.onAddMember,
    this.onToggleAdmin,
    this.onTransferOwnership,
  }) : super(key: key);

  @override
  State<ChangeAdminStatusScreen> createState() =>
      _ChangeAdminStatusScreenState();
}

class _ChangeAdminStatusScreenState extends State<ChangeAdminStatusScreen> {
  static const Color purple = Color(0xFF6750A4);

  late List<Map<String, dynamic>> _membersLocal;
  final Set<String> _pendingToggleIds = {};
  final SpaceService _spaceService = SpaceService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoadingMembers = false;
  String?
      _creatorIdLocal; // resolved creator id (may be from widget or fetched)

  bool get _isCreator =>
      widget.currentUserId == (_creatorIdLocal ?? widget.creatorId);

  bool get _currentUserIsAdmin {
    final m = _findMember(widget.currentUserId);
    return (m?['isAdmin'] ?? false) as bool;
  }

  bool get _isPrivileged => _isCreator || _currentUserIsAdmin;

  @override
  void initState() {
    super.initState();
    _membersLocal = _deepCopyMembers(widget.members);
    _ensureOwnerFirst();
    _creatorIdLocal = widget.creatorId;

    // If parent asked us to auto-load members by spaceId, do it now
    if (widget.autoLoadMembers && (widget.spaceId != null)) {
      _loadMembersFromSpace(widget.spaceId!);
    }
  }

  Future<void> _loadMembersFromSpace(String spaceId) async {
    setState(() => _isLoadingMembers = true);
    try {
      final doc = await _spaceService.getSpace(spaceId);
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      final List<dynamic> memberIdsDynamic = data['members'] ?? <dynamic>[];
      final List<String> memberIds =
          memberIdsDynamic.map((e) => e.toString()).toList();
      final List<dynamic> adminsDynamic = data['admins'] ?? <dynamic>[];
      final List<String> adminIds =
          adminsDynamic.map((e) => e.toString()).toList();
      final String creatorId = (data['creator'] ?? '') as String;
      _creatorIdLocal = creatorId;

      if (memberIds.isEmpty) {
        setState(() {
          _membersLocal = [];
          _isLoadingMembers = false;
        });
        return;
      }

      // NOTE: whereIn has 10 limit in Firestore; if you're expecting >10 you should chunk.
      final q = await _firestore
          .collection('Users')
          .where('uid', whereIn: memberIds)
          .get();

      final membersData = q.docs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        final uid = (m['uid'] ?? d.id).toString();
        return <String, dynamic>{
          'id': uid,
          'uid': uid,
          'username':
              (m['username'] ?? m['displayName'] ?? 'Unknown').toString(),
          'profilePicture': (m['profilePicture'] ?? '').toString(),
          'isAdmin': adminIds.contains(uid) || (creatorId == uid),
        };
      }).toList();

      setState(() {
        _membersLocal = membersData;
        _ensureOwnerFirst();
        _isLoadingMembers = false;
      });
    } catch (e, st) {
      debugPrint('[_loadMembersFromSpace] ERROR: $e\n$st');
      if (mounted) {
        setState(() => _isLoadingMembers = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('errorLoadingMembers'.tr())));
      }
    }
  }

  @override
  void didUpdateWidget(covariant ChangeAdminStatusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.members != widget.members) {
      _membersLocal = _deepCopyMembers(widget.members);
      _ensureOwnerFirst();
      final ids = _membersLocal.map((m) => m['id'] as String).toSet();
      _pendingToggleIds.removeWhere((id) => !ids.contains(id));
      setState(() {});
    }
  }

  void _ensureOwnerFirst() {
    final ownerIndex = _membersLocal.indexWhere(
        (m) => m['id'] == (widget.creatorId ?? _creatorIdLocal ?? ''));
    if (ownerIndex > 0) {
      final owner = _membersLocal.removeAt(ownerIndex);
      _membersLocal.insert(0, owner);
    }
  }

  List<Map<String, dynamic>> _deepCopyMembers(List<Map<String, dynamic>> src) {
    return src
        .map((m) => {
              'id': (m['id'] ?? '') as String,
              'uid': (m['uid'] ?? m['id'] ?? '') as String,
              'username': (m['username'] ?? 'Unknown') as String,
              'profilePicture': (m['profilePicture'] ?? '') as String,
              'isAdmin': (m['isAdmin'] ?? false) as bool,
            })
        .toList();
  }

  Map<String, dynamic>? _findMember(String id) {
    for (final m in _membersLocal) {
      if ((m['id'] ?? '') == id) return m;
    }
    return null;
  }

  Future<void> _toggleAdmin(String memberId, bool makeAdmin, int index) async {
    final member = _membersLocal[index];
    debugPrint(
        '[_toggleAdmin] start: memberId=$memberId, index=$index, member=$member');

    // guard: don't touch the creator row
    final creatorId = (_creatorIdLocal ?? widget.creatorId) ?? '';
    if ((member['id'] ?? '') == creatorId) {
      debugPrint('[_toggleAdmin] abort: member is creator');
      return;
    }

    // avoid duplicate operations
    if (_pendingToggleIds.contains(memberId)) {
      debugPrint('[_toggleAdmin] abort: already pending');
      return;
    }

    // optimistic UI update
    setState(() {
      _membersLocal[index]['isAdmin'] = makeAdmin;
      _pendingToggleIds.add(memberId);
    });

    try {
      if (widget.onToggleAdmin != null) {
        debugPrint('[_toggleAdmin] calling parent onToggleAdmin for $memberId');
        await widget.onToggleAdmin!(memberId, makeAdmin);
      } else {
        // fallback: revert and show message
        setState(() {
          _membersLocal[index]['isAdmin'] = !makeAdmin;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('implementToggleAdminCallback'.tr())),
        );
        return;
      }

      final userService = UserService();
      final fullName = await userService.getFullName(memberId);

      final displayName = (fullName.isNotEmpty)
          ? fullName
          : ((member['username'] as String?)?.trim().isNotEmpty == true
              ? (member['username'] as String)
              : ((member['uid'] as String?)?.trim().isNotEmpty == true
                  ? (member['uid'] as String)
                  : memberId));

      final msg = makeAdmin
          ? 'adminPromoted'.tr(namedArgs: {'name': displayName})
          : 'adminDemoted'.tr(namedArgs: {'name': displayName});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg,
              style: TextStyle(
                  color: makeAdmin ? Colors.white : null,
                  fontWeight: FontWeight.w600)),
          backgroundColor: makeAdmin ? purple : null,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e, st) {
      debugPrint('[_toggleAdmin] ERROR: $e\n$st');
      // rollback UI on error
      setState(() {
        _membersLocal[index]['isAdmin'] = !makeAdmin;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('errorUpdatingAdmin'.tr())));
    } finally {
      setState(() {
        _pendingToggleIds.remove(memberId);
      });
      debugPrint('[_toggleAdmin] finished for $memberId');
    }
  }

  // reuse your existing _promptTransferOwnershipIfCreatorLeaves (copy/paste from your earlier file)
  // ----------------------------------------------------------------
  Future<void> _promptTransferOwnershipIfCreatorLeaves() async {
    if (!_isCreator) return;

    final candidates = _membersLocal
        .where((m) => m['id'] != (widget.creatorId ?? _creatorIdLocal))
        .toList();

    if (candidates.isEmpty) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('noOtherMembers'.tr()),
          content: Text('cannotLeaveNoOtherMembers'.tr()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: Text('ok'.tr()))
          ],
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('selectNewOwner'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const Divider(height: 1),
                ...candidates.map((c) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          (c['profilePicture'] as String).isNotEmpty
                              ? NetworkImage(c['profilePicture'] as String)
                              : null,
                      child: (c['profilePicture'] as String).isEmpty
                          ? Text(
                              (c['username'] as String).isNotEmpty
                                  ? (c['username'] as String)[0].toUpperCase()
                                  : '?',
                            )
                          : null,
                    ),
                    title: Text(c['username'] as String),
                    onTap: () => Navigator.pop(ctx, c['id'] as String),
                  );
                }).toList(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      if (widget.onTransferOwnership != null) {
        try {
          await widget.onTransferOwnership!(selected);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ownershipTransferred'.tr())));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('errorTransferringOwnership'.tr())));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('implementTransferOwnershipCallback'.tr())));
      }
    }
  }
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final dividerColor = isDarkMode ? Colors.grey[700] : Colors.grey[200];

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
              color: purple,
            ),
            title: Text(
              (_isPrivileged)
                  ? 'changeAdminStatus'.tr()
                  : 'viewAdminStatus'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            centerTitle: false,
            backgroundColor: Colors.transparent,
            actions: [
              if (_isCreator)
                TextButton(
                  onPressed: () async {
                    await _promptTransferOwnershipIfCreatorLeaves();
                  },
                  child: Text('Transfer'.tr(),
                      style: const TextStyle(color: purple)),
                ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Text(
              'Admin status'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
              ),
              textAlign: TextAlign.left,
            ),
          ),
          Expanded(
            child: _buildBody(dividerColor!),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Color dividerColor) {
    // show shimmer while loading members
    if (_isLoadingMembers) {
      // use your existing shimmer component pieces (ShimmerMemberRow) so we don't nest scaffolds
      return ListView.separated(
        padding: EdgeInsets.zero,
        itemBuilder: (c, i) {
          if (i == 0) {
            // owner-like row placeholder
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: ShimmerBlock(height: 14, radius: 6)),
                  const SizedBox(width: 12),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      child: const ShimmerBlock(
                          height: 14, width: 48, radius: 12)),
                ],
              ),
            );
          }
          return const ShimmerMemberRow();
        },
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.transparent),
        itemCount: 6,
      );
    }

    // If not loading and no members: show placeholder
    if (_membersLocal.isEmpty) {
      return _NoMembersPlaceholder(onAddPressed: () {
        if (widget.onAddMember != null) widget.onAddMember!();
      });
    }

    // normal members list
    return ListView.separated(
      itemCount: _membersLocal.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, thickness: 1.2, color: dividerColor),
      itemBuilder: (context, index) {
        final m = _membersLocal[index];
        final memberId = m['id'] as String;
        final username = m['username'] as String;
        final profilePicture = m['profilePicture'] as String;
        final isAdmin = (m['isAdmin'] ?? false) as bool;
        final isCreatorRow = memberId == (widget.creatorId ?? _creatorIdLocal);
        final isCurrentUser = memberId == widget.currentUserId;
        final isPending = _pendingToggleIds.contains(memberId);

        Widget trailing;

        if (isCreatorRow) {
          // Owner chip (always shown and should be first row due to sorting)
          trailing = Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            decoration: const BoxDecoration(
              color: purple,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Text('Owner'.tr(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          );
        } else if (_isPrivileged) {
          // show toggle (or loading spinner) for privileged users
          trailing = isPending
              ? SizedBox(
                  width: 46,
                  height: 26,
                  child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(purple),
                        )),
                  ),
                )
              : _AestheticToggle(
                  value: isAdmin,
                  onChanged: (v) {
                    _toggleAdmin(memberId, v, index);
                  },
                  activeColor: purple,
                );
        } else {
          // non-privileged members see an admin chip or nothing
          if (isAdmin) {
            trailing = Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: purple.withOpacity(0.12),
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
              child: Text('admin'.tr(),
                  style: TextStyle(color: purple, fontWeight: FontWeight.w700)),
            );
          } else {
            trailing = const SizedBox.shrink();
          }
        }

        return ListTile(
          key: ValueKey(memberId),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            radius: 22,
            backgroundImage:
                profilePicture.isNotEmpty ? NetworkImage(profilePicture) : null,
            child: profilePicture.isEmpty
                ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?')
                : null,
          ),
          title: Text(
            username,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: purple, fontSize: 14),
          ),
          subtitle: isCurrentUser
              ? Text('you'.tr(), style: TextStyle(fontSize: 12))
              : null,
          trailing: trailing,
          onTap: () {},
        );
      },
    );
  }
}

/// Fixed _AestheticToggle widget — thumb no longer appears "cut".
/// Replace your existing _AestheticToggle and _AestheticToggleState with this code.
class _AestheticToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const _AestheticToggle({
    Key? key,
    required this.value,
    required this.onChanged,
    this.activeColor = const Color(0xFF6750A4),
  }) : super(key: key);

  @override
  State<_AestheticToggle> createState() => _AestheticToggleState();
}

class _AestheticToggleState extends State<_AestheticToggle>
    with SingleTickerProviderStateMixin {
  late bool _value;
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    if (_value) _anim.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _AestheticToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
      if (_value)
        _anim.forward();
      else
        _anim.reverse();
    }
  }

  void _handleTap() {
    final newVal = !_value;
    if (newVal)
      _anim.forward();
    else
      _anim.reverse();

    setState(() => _value = newVal);
    widget.onChanged(newVal);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: adjusted thumb/track/padding so the white thumb + shadow has breathing room
    final trackWidth = 46.0;
    final trackHeight = 26.0;
    final thumbSize = 18.0; // slightly smaller to avoid clipping of shadow
    final horizontalPadding = 4.0;
    final verticalPadding = 4.0;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = _anim.value;
          final active = widget.activeColor;
          final inactive = Colors.grey.shade300;
          final trackColor = Color.lerp(inactive, active.withOpacity(0.92), t)!;

          // compute thumb left position (0..1) then map to pixels
          final maxThumbLeft = trackWidth - thumbSize - (horizontalPadding * 2);
          final thumbLeft = (maxThumbLeft) * t;

          return Container(
            width: trackWidth,
            height: trackHeight,
            padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding, vertical: verticalPadding),
            // no clip — give thumb + shadow room inside the container
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(trackHeight / 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04 * t),
                  blurRadius: 4 * t,
                  offset: Offset(0, 1 * t),
                )
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none, // ensure thumb/shadow aren't clipped
              children: [
                Positioned(
                  left: thumbLeft,
                  top: (trackHeight - verticalPadding * 2 - thumbSize) / 2,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NoMembersPlaceholder extends StatelessWidget {
  final VoidCallback onAddPressed;
  const _NoMembersPlaceholder({Key? key, required this.onAddPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final purple = const Color(0xFF6750A4);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.notifications, size: 30, color: purple),
              const SizedBox(width: 12),
              Icon(Icons.person, size: 30, color: purple),
              const SizedBox(width: 12),
              Icon(Icons.directions_car, size: 30, color: purple),
            ]),
            const SizedBox(height: 18),
            Text('yourCircleNeedsMembers'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('circleNeedsMembersDesc'.tr(),
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onAddPressed,
                style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40))),
                child: Text('addANewMember'.tr(),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
