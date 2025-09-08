// --- change_admin_status_screen.dart (replace existing class) ---
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

typedef VoidAdminToggle = Future<void> Function(
    String memberId, bool makeAdmin);

class ChangeAdminStatusScreen extends StatelessWidget {
  /// members: each item must be a Map<String, dynamic> with keys:
  /// 'id' (String), 'username' (String), 'profilePicture' (String), 'isAdmin' (bool)
  final List<Map<String, dynamic>> members;
  final String currentUserId;
  final String creatorId;
  final VoidCallback? onAddMember;
  final VoidAdminToggle? onToggleAdmin;

  const ChangeAdminStatusScreen({
    Key? key,
    this.members = const [],
    required this.currentUserId,
    required this.creatorId,
    this.onAddMember,
    this.onToggleAdmin,
  }) : super(key: key);

  bool get _isCreator => currentUserId == creatorId;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final purple = const Color(0xFF6750A4);

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
              'changeAdminStatus'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: members.isEmpty
          ? _NoMembersPlaceholder(onAddPressed: () {
              if (onAddMember != null)
                onAddMember!();
              else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('noMembersAddPlease'.tr())),
                );
              }
            })
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final m = members[index];
                final memberId = (m['id'] ?? '') as String;
                final username = (m['username'] ?? 'Unknown') as String;
                final profilePicture = (m['profilePicture'] ?? '') as String;
                final isAdmin = (m['isAdmin'] ?? false) as bool;
                final isCurrentUser = memberId == currentUserId;

                Widget trailing;
                if (isAdmin) {
                  trailing = Chip(
                    label: Text('admin'.tr()),
                    backgroundColor: purple.withOpacity(0.15),
                    labelStyle:
                        TextStyle(color: purple, fontWeight: FontWeight.w700),
                  );
                } else if (_isCreator && !isCurrentUser) {
                  // Show toggle for creator to promote -> demote
                  trailing = StatefulBuilder(builder: (ctx, setState) {
                    bool value = isAdmin;
                    return Switch.adaptive(
                      value: value,
                      onChanged: (v) async {
                        // optimistically update UI locally
                        setState(() => value = v);
                        if (onToggleAdmin != null) {
                          try {
                            await onToggleAdmin!(memberId, v);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(v
                                      ? 'adminPromoted'.tr(args: [username])
                                      : 'adminDemoted'.tr(args: [username]))),
                            );
                          } catch (e) {
                            // revert on error
                            setState(() => value = !v);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('errorUpdatingAdmin'.tr())),
                            );
                          }
                        }
                      },
                    );
                  });
                } else {
                  trailing = const SizedBox.shrink();
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: profilePicture.isNotEmpty
                        ? NetworkImage(profilePicture)
                        : null,
                    child: profilePicture.isEmpty
                        ? Text(username.isNotEmpty
                            ? username[0].toUpperCase()
                            : '?')
                        : null,
                  ),
                  title: Text(username),
                  subtitle: isCurrentUser ? Text('you'.tr()) : null,
                  trailing: trailing,
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: members.length,
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
