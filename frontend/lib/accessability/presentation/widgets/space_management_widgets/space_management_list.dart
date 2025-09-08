import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/verification_code_widget.dart';
import 'package:accessability/accessability/presentation/widgets/space_management_widgets/change_admin_status.dart';
import 'package:accessability/accessability/presentation/widgets/space_management_widgets/edit_space_name_screen.dart';
import 'package:accessability/accessability/presentation/widgets/space_management_widgets/leave_space_dialog.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

class SpaceManagementList extends StatelessWidget {
  const SpaceManagementList({
    Key? key,
    this.spaceId,
    this.spaceName,
    this.onViewAdmin,
    this.onAddPeople,
    this.onLeave,
    this.lastUpdatedSpaceId,
    this.onEditName,
  }) : super(key: key);

  final String? spaceId;
  final String? spaceName;
  final String? lastUpdatedSpaceId;

  final VoidCallback? onViewAdmin;
  final VoidCallback? onAddPeople;
  final VoidCallback? onLeave;
  final void Function(String newName)? onEditName;

  static const Color _purple = Color(0xFF6750A4);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    final headerStyle = (theme.textTheme.titleMedium ??
            const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600))
        .copyWith(
      fontWeight: FontWeight.w700,
      color: _purple.withOpacity(isDark ? 0.8 : 0.45),
    );

    final sectionHeaderStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.grey[500],
    );

    final rowTitleStyle = const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 16.0,
      color: _purple,
    );

    final rowValueStyle = TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 14.0,
      color: Colors.grey[600],
    );

    final dividerColor = isDark ? Colors.grey[800] : Colors.grey[200];

    return Container(
      // light-mode: soft gray like the screenshot; dark-mode keeps scaffold bg
      color: isDark ? theme.scaffoldBackgroundColor : Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top info card (icon group + space name + description)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 18.0),
                child: Row(
                  children: [
                    // icon cluster (stacked avatars)
                    SizedBox(
                      width: 64,
                      height: 48,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 28,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.yellow[700],
                              child: Icon(Icons.person,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.pink[300],
                              child: Icon(Icons.person,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: _purple,
                            child: Icon(Icons.person,
                                size: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 14),
                    // Title + description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spaceName?.isNotEmpty == true
                                ? spaceName!
                                : 'Space management'.tr(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              // highlight in purple if this space was just updated
                              color: (spaceId != null &&
                                      spaceId == lastUpdatedSpaceId)
                                  ? _purple
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Changes you make here apply only to the current selected Space.'
                                .tr(),
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Section header: Space details
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Space details'.tr(), style: sectionHeaderStyle),
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),

          // List area
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Edit Space Name (in details section) — white tile with chevron
                _buildTile(
                  context,
                  title: 'Edit Space Name'.tr(),
                  titleStyle: rowTitleStyle,
                  onTap: () async {
                    final result = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) =>
                            EditSpaceNameScreen(initialName: spaceName ?? ''),
                      ),
                    );

                    if (result != null && result.trim().isNotEmpty) {
                      // notify parent callback
                      if (onEditName != null) onEditName!(result.trim());
                    }
                  },
                ),
                Divider(height: 1, thickness: 1, color: dividerColor),

                // Section header: Space Management
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child:
                      Text('Space Management'.tr(), style: sectionHeaderStyle),
                ),
                Divider(height: 1, thickness: 1, color: dividerColor),

                // My Role (set to Admin)
                _buildTile(
                  context,
                  title: 'My Role'.tr(),
                  titleStyle: rowTitleStyle,
                  trailingWidget: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text('Admin', style: rowValueStyle),
                  ),
                ),
                Divider(height: 1, thickness: 1, color: dividerColor),

                // Change Admin Status
                _buildTile(
                  context,
                  title: 'Change Admin Status'.tr(),
                  titleStyle: rowTitleStyle,
                  onTap: () {
                    if (onViewAdmin != null) {
                      onViewAdmin!();
                    } else {
                      // fallback behaviour (optional):
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select a space'.tr())),
                      );
                    }
                  },
                ),
                Divider(height: 1, thickness: 1, color: dividerColor),

                // Add people to Space
                _buildTile(
                  context,
                  title: 'Add people to Space'.tr(),
                  titleStyle: rowTitleStyle,
                  onTap: () {
                    if (onAddPeople != null) {
                      onAddPeople!();
                      return;
                    }
                    final sid = (spaceId ?? '').trim();
                    if (sid.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No space selected'.tr())),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VerificationCodeScreen(
                            spaceId: sid, spaceName: spaceName),
                      ),
                    );
                  },
                ),
                Divider(height: 1, thickness: 1, color: dividerColor),

                // Leave Space
                _buildTile(
                  context,
                  title: 'Leave Space'.tr(),
                  titleStyle: rowTitleStyle,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => LeaveSpaceDialogWidget(
                        onConfirm: () {
                          if (onLeave != null) {
                            onLeave!(); // trigger parent callback
                          }
                        },
                      ),
                    );
                  },
                ),

                Divider(height: 1, thickness: 1, color: dividerColor),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required String title,
    VoidCallback? onTap,
    TextStyle? titleStyle,
    double verticalPadding = 18.0,
    Widget? trailingWidget,
  }) {
    final effectiveTitleStyle = titleStyle ??
        const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 16.0, color: _purple);

    // White tile background to match screenshot
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: Colors.white,
          padding:
              EdgeInsets.symmetric(horizontal: 16.0, vertical: verticalPadding),
          child: Row(
            children: [
              Expanded(child: Text(title, style: effectiveTitleStyle)),
              if (trailingWidget != null) trailingWidget,
              if (trailingWidget == null && onTap != null)
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
