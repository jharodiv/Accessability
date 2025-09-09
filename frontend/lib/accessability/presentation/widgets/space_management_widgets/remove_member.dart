// lib/presentation/widgets/space_management_widgets/remove_member.dart
import 'package:accessability/accessability/presentation/widgets/space_management_widgets/remove_confirm_dialog.dart';
import 'package:accessability/accessability/presentation/widgets/space_management_widgets/shimmer_remove_members.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

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

/// Tile used in the list (avatar, bold black name, subtitle, circular check)
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
    final nameStyle = const TextStyle(
      fontWeight: FontWeight.w700,
      color: Colors.black,
      fontSize: 16,
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
              CircleAvatar(
                radius: 22,
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
              const SizedBox(width: 12),
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
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.shade300.withOpacity(0.9),
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Container(
                        decoration: const BoxDecoration(
                          color: _purple,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child:
                              Icon(Icons.check, color: Colors.white, size: 14),
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

/// RemoveMembersScreen
class RemoveMembersScreen extends StatefulWidget {
  final List<SimpleMember> members;
  final String currentUserId;
  final String creatorId;
  final List<String> adminIds;
  final bool isLoading;

  /// Optional server-side removal handler. If provided, the screen will call it and await it
  /// while showing an inline progress indicator and showing the notification here.
  final Future<void> Function(List<String> ids)? onRemove;

  const RemoveMembersScreen({
    Key? key,
    required this.members,
    required this.currentUserId,
    required this.creatorId,
    this.adminIds = const [],
    this.isLoading = false,
    this.onRemove,
  }) : super(key: key);

  @override
  _RemoveMembersScreenState createState() => _RemoveMembersScreenState();
}

class _RemoveMembersScreenState extends State<RemoveMembersScreen> {
  final Set<String> _selected = {};
  bool _processing = false;

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

    if (confirmed != true) return;

    final selectedIds = _selected.toList();

    // If there is an onRemove callback, call it and show an inline progress indicator inside this screen.
    // The screen is responsible for showing the notification (SnackBar) here.
    if (widget.onRemove != null) {
      setState(() => _processing = true);
      try {
        await widget.onRemove!(selectedIds);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                // uses translation key and replaces {count}
                'removedMembers'
                    .tr()
                    .replaceFirst('{count}', selectedIds.length.toString()),
              ),
              backgroundColor: _purple,
            ),
          );
          Navigator.of(context).pop(selectedIds);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('errorRemovingMember'.tr())),
          );
        }
      } finally {
        if (mounted) setState(() => _processing = false);
      }
    } else {
      // No server removal here — return selected ids to parent and show a small snackbar inside screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${selectedIds.length} ${'selected'.tr()}')),
        );
        Navigator.of(context).pop(selectedIds);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers =
        widget.members.where((m) => m.id != widget.creatorId).toList();

    // Prevent popping while processing
    return WillPopScope(
      onWillPop: () async => !_processing,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _purple),
            onPressed: _processing ? null : () => Navigator.of(context).pop(),
          ),
          // localized title: Remove people from Space
          title: Text(
            'removePeopleFromSpace'.tr(),
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed:
                    _hasSelection && !_processing ? _confirmAndReturn : null,
                child: Text(
                  '${'remove'.tr()}(${_selected.length})',
                  style: TextStyle(
                    color: _hasSelection ? _purple : Colors.grey,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // section header "Space Management"
            Container(
              width: double.infinity,
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'spaceManagement'.tr(),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),

            // body area:
            Expanded(
              child: Builder(builder: (context) {
                // Show the *shimmer* when either:
                // - the screen was constructed with isLoading == true (initial load)
                // - OR the remove operation is currently processing (_processing == true)
                if (widget.isLoading || _processing) {
                  return const ShimmerRemoveMembers(rows: 6);
                }

                // Empty state after owner is filtered out
                if (filteredMembers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Purple icon per request
                        Icon(Icons.group_off, size: 72, color: _purple),
                        const SizedBox(height: 12),
                        Text(
                          'noOtherMembersInSpace'.tr(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Normal list
                return ListView.separated(
                  itemCount: filteredMembers.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, i) {
                    final m = filteredMembers[i];
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
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
