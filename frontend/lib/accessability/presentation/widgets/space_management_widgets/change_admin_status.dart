// change_admin_status_screen.dart
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

typedef VoidAdminToggle = Future<void> Function(
    String memberId, bool makeAdmin);
typedef VoidTransferOwnership = Future<void> Function(String newOwnerId);

class ChangeAdminStatusScreen extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final String currentUserId;
  final String creatorId;
  final VoidCallback? onAddMember;
  final VoidAdminToggle? onToggleAdmin;
  final VoidTransferOwnership? onTransferOwnership;

  const ChangeAdminStatusScreen({
    Key? key,
    this.members = const [],
    required this.currentUserId,
    required this.creatorId,
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

  bool get _isCreator => widget.currentUserId == widget.creatorId;

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
    // Find the creator row and move it to the front if present.
    final ownerIndex =
        _membersLocal.indexWhere((m) => m['id'] == widget.creatorId);
    if (ownerIndex > 0) {
      final owner = _membersLocal.removeAt(ownerIndex);
      _membersLocal.insert(0, owner);
    }
  }

  List<Map<String, dynamic>> _deepCopyMembers(List<Map<String, dynamic>> src) {
    return src
        .map((m) => {
              'id': (m['id'] ?? '') as String,
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
    if ((member['id'] ?? '') == widget.creatorId) return;
    if (_pendingToggleIds.contains(memberId)) return;

    setState(() {
      _membersLocal[index]['isAdmin'] = makeAdmin;
      _pendingToggleIds.add(memberId);
    });

    if (widget.onToggleAdmin != null) {
      try {
        await widget.onToggleAdmin!(memberId, makeAdmin);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(makeAdmin
              ? 'adminPromoted'.tr(args: [member['username']])
              : 'adminDemoted'.tr(args: [member['username']])),
        ));
      } catch (e) {
        setState(() {
          _membersLocal[index]['isAdmin'] = !makeAdmin;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('errorUpdatingAdmin'.tr())));
      } finally {
        setState(() {
          _pendingToggleIds.remove(memberId);
        });
      }
    } else {
      setState(() {
        _membersLocal[index]['isAdmin'] = !makeAdmin;
        _pendingToggleIds.remove(memberId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('implementToggleAdminCallback'.tr())),
      );
    }
  }

  Future<void> _promptTransferOwnershipIfCreatorLeaves() async {
    if (!_isCreator) return;

    final candidates =
        _membersLocal.where((m) => m['id'] != widget.creatorId).toList();

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
            child: _membersLocal.isEmpty
                ? _NoMembersPlaceholder(onAddPressed: () {
                    if (widget.onAddMember != null) widget.onAddMember!();
                  })
                : ListView.separated(
                    itemCount: _membersLocal.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, thickness: 1.2, color: dividerColor),
                    itemBuilder: (context, index) {
                      final m = _membersLocal[index];
                      final memberId = m['id'] as String;
                      final username = m['username'] as String;
                      final profilePicture = m['profilePicture'] as String;
                      final isAdmin = (m['isAdmin'] ?? false) as bool;
                      final isCreatorRow = memberId == widget.creatorId;
                      final isCurrentUser = memberId == widget.currentUserId;
                      final isPending = _pendingToggleIds.contains(memberId);

                      Widget trailing;

                      if (isCreatorRow) {
                        // Owner chip (always shown and should be first row due to sorting)
                        trailing = Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 14),
                          decoration: const BoxDecoration(
                            color: purple,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Text('Owner'.tr(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
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
                                        valueColor:
                                            AlwaysStoppedAnimation(purple),
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
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: purple.withOpacity(0.12),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(16)),
                            ),
                            child: Text('admin'.tr(),
                                style: TextStyle(
                                    color: purple,
                                    fontWeight: FontWeight.w700)),
                          );
                        } else {
                          trailing = const SizedBox.shrink();
                        }
                      }

                      return ListTile(
                        key: ValueKey(memberId),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundImage: profilePicture.isNotEmpty
                              ? NetworkImage(profilePicture)
                              : null,
                          child: profilePicture.isEmpty
                              ? Text(username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : '?')
                              : null,
                        ),
                        title: Text(
                          username,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: purple,
                              fontSize: 14),
                        ),
                        subtitle: isCurrentUser
                            ? Text('you'.tr(), style: TextStyle(fontSize: 12))
                            : null,
                        trailing: trailing,
                        onTap: () {},
                      );
                    },
                  ),
          ),
        ],
      ),
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
