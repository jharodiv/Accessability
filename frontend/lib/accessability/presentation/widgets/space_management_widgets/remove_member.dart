import 'package:accessability/accessability/presentation/widgets/space_management_widgets/remove_confirm_dialog.dart';
import 'package:flutter/material.dart';

const Color _purple = Color(0xFF6750A4);

/// Simple model for member list
class SimpleMember {
  final String id;
  final String username;
  final String profilePicture;
  final String? subtitle;
  final bool isAdmin;
  SimpleMember({
    required this.id,
    required this.username,
    this.profilePicture = '',
    this.subtitle,
    this.isAdmin = false,
  });
}

/// Tile used in the list (avatar, bold purple name, subtitle, circular check)
class RemoveMemberListTile extends StatelessWidget {
  final SimpleMember member;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  const RemoveMemberListTile({
    Key? key,
    required this.member,
    required this.selected,
    this.disabled = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // NAME: now black and smaller
    final nameStyle = const TextStyle(
      fontWeight: FontWeight.w700,
      color: Colors.black, // changed from purple to black
      fontSize: 16, // reduced from 18
    );

    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: Colors.grey[600],
    );

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              // slightly smaller avatar
              CircleAvatar(
                radius: 22, // was 26
                backgroundImage: (member.profilePicture.isNotEmpty)
                    ? NetworkImage(member.profilePicture)
                    : null,
                backgroundColor:
                    member.profilePicture.isEmpty ? Colors.grey[300] : null,
                child: member.profilePicture.isEmpty
                    ? Text(
                        member.username.isNotEmpty
                            ? member.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      )
                    : null,
              ),

              const SizedBox(width: 12), // slightly reduced spacing

              // Title & subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.username, style: nameStyle),
                    if (member.subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(member.subtitle!, style: subtitleStyle),
                    ],
                  ],
                ),
              ),

              // smaller circular check indicator (right)
              Container(
                width: 28, // was 40
                height: 28, // was 40
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.shade300.withOpacity(0.9),
                    width: 1.5, // thinner border
                  ),
                ),
                child: selected
                    ? Container(
                        // fully filled smaller purple circle
                        decoration: const BoxDecoration(
                          color: _purple,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.check,
                              color: Colors.white, size: 14), // smaller icon
                        ),
                      )
                    : (disabled
                        ? Icon(Icons.remove_circle_outline,
                            color: Colors.grey.shade300, size: 18)
                        : const SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen that lists members with multi-select and returns selected ids on confirm.
///
/// Notes:
/// - The owner is excluded from the list entirely (owner cannot be removed).
/// - The current user is excluded from selecting themself (can't remove themself here).
/// - If the current user is the owner, they can select admins (owner may remove admins).
class RemoveMembersScreen extends StatefulWidget {
  final List<SimpleMember> members;
  final String currentUserId;
  final String creatorId;
  final List<String> adminIds;

  const RemoveMembersScreen({
    Key? key,
    required this.members,
    required this.currentUserId,
    required this.creatorId,
    this.adminIds = const [],
  }) : super(key: key);

  @override
  _RemoveMembersScreenState createState() => _RemoveMembersScreenState();
}

class _RemoveMembersScreenState extends State<RemoveMembersScreen> {
  final Set<String> _selected = {};

  bool get _hasSelection => _selected.isNotEmpty;

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id))
        _selected.remove(id);
      else
        _selected.add(id);
    });
  }

  Future<void> _confirmAndReturn() async {
    if (_selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RemoveConfirmDialogWidget(count: _selected.length),
    );

    if (confirmed == true) {
      Navigator.of(context).pop(_selected.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter out the owner/creator from the displayed list (owner is not included in remove)
    final filteredMembers =
        widget.members.where((m) => m.id != widget.creatorId).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false, // left-align title
        titleSpacing: 0, // align title near leading icon like screenshot
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _purple),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Remove people from Circle',
          // smaller and black as requested
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        actions: [
          // "Remove(n)" small (~13px) and purple when enabled
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _hasSelection ? _confirmAndReturn : null,
              child: Text(
                'Remove(${_selected.length})',
                style: TextStyle(
                  color: _hasSelection ? _purple : Colors.grey,
                  fontWeight: FontWeight.w700,
                  fontSize: 13, // made smaller per request
                ),
              ),
            ),
          ),
        ],
      ),

      // body: small section header then the list (matches provided image)
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // section header "Circle Management"
          Container(
            width: double.infinity,
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Circle Management',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),

          // list
          Expanded(
            child: ListView.separated(
              itemCount: filteredMembers.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (context, i) {
                final m = filteredMembers[i];

                // disabled if it's the current user (can't remove themself).
                // Owner already filtered out above.
                final disabled = (m.id == widget.currentUserId);

                return RemoveMemberListTile(
                  member: m,
                  disabled: disabled,
                  selected: _selected.contains(m.id),
                  onTap: () {
                    if (!disabled) _toggle(m.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
