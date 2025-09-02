import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class SpaceManagementList extends StatelessWidget {
  const SpaceManagementList({
    Key? key,
    this.onViewAdmin,
    this.onAddPeople,
    this.onLeave,
  }) : super(key: key);

  final VoidCallback? onViewAdmin;
  final VoidCallback? onAddPeople;
  final VoidCallback? onLeave;

  // Primary purple used in your app (screenshot).
  static const Color _purple = Color(0xFF6750A4);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Header uses a lighter purple like in your screenshot.
    final headerStyle = (theme.textTheme.titleMedium ??
            const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600))
        .copyWith(
      fontWeight: FontWeight.w700,
      color: _purple.withOpacity(isDark ? 0.8 : 0.45),
    );

    // Row title style should be bold purple (matches screenshot).
    final rowTitleStyle = const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 16.0,
      color: _purple,
    );

    // Divider color tuned for light/dark modes.
    final dividerColor = isDark ? Colors.grey[800] : Colors.grey[200];

    return Container(
      color: isDark ? Colors.grey[900] : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header: always "Circle Management" (ignores any space name).
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
            color: isDark ? Colors.grey[850] : Colors.grey[50],
            child: Text(
              'Circle Management'.tr(),
              style: headerStyle,
            ),
          ),

          Divider(height: 1, thickness: 1, color: dividerColor),

          // List of actionable rows. (My Role and Bubbles intentionally omitted.)
          Expanded(
            child: ListView(
              children: [
                _buildTile(
                  context,
                  title: 'View Admin Status'.tr(),
                  titleStyle: rowTitleStyle,
                  onTap: onViewAdmin,
                  showTrailingChevron: false,
                ),
                Divider(height: 1, thickness: 1, color: dividerColor),
                _buildTile(
                  context,
                  title: 'Add people to Circle'.tr(),
                  titleStyle: rowTitleStyle,
                  onTap: onAddPeople,
                  showTrailingChevron: false,
                ),
                Divider(height: 1, thickness: 1, color: dividerColor),
                _buildTile(
                  context,
                  title: 'Leave Circle'.tr(),
                  titleStyle: rowTitleStyle,
                  onTap: onLeave,
                  trailingWidget: const SizedBox.shrink(),
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
    bool showTrailingChevron = true,
    Widget? trailingWidget,
  }) {
    final effectiveTitleStyle = titleStyle ??
        const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16.0,
          color: _purple,
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: effectiveTitleStyle,
                ),
              ),
              if (trailingWidget != null) trailingWidget,
              if (trailingWidget == null && showTrailingChevron)
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
