import 'package:accessability/accessability/presentation/widgets/gpsWidgets/space_dropdown_widget.dart';
import 'package:flutter/material.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/category_item.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

class Topwidgets extends StatefulWidget {
  final Function(bool) onOverlayChange;
  final Function(String) onCategorySelected;
  final GlobalKey inboxKey;
  final GlobalKey settingsKey;
  final Function(String, String) onSpaceSelected;
  final VoidCallback onMySpaceSelected;
  final Function(String) onSpaceIdChanged;
  final VoidCallback? onTopTap;

  // NEW: accept active space id and name from parent
  final String activeSpaceId;
  final String activeSpaceName;

  const Topwidgets({
    super.key,
    required this.onOverlayChange,
    required this.onCategorySelected,
    required this.inboxKey,
    required this.settingsKey,
    required this.onSpaceSelected,
    required this.onMySpaceSelected,
    required this.onSpaceIdChanged,
    required this.activeSpaceId,
    required this.activeSpaceName,
    this.onTopTap,
  });

  @override
  TopwidgetsState createState() => TopwidgetsState();
}

class TopwidgetsState extends State<Topwidgets> {
  String _activeSpaceName = "mySpace".tr();
  String? _selectedCategory;
  String _activeSpaceId = ''; // track the ID, too

  @override
  void initState() {
    super.initState();
    // initialize from parent-provided values
    _activeSpaceId = widget.activeSpaceId;
    _activeSpaceName = (widget.activeSpaceName.isNotEmpty)
        ? widget.activeSpaceName
        : "mySpace".tr();
    debugPrint('[Topwidgets] init: id=$_activeSpaceId name=$_activeSpaceName');
  }

  @override
  void didUpdateWidget(covariant Topwidgets oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If parent changed selected space, sync internal state so UI updates immediately
    if (oldWidget.activeSpaceId != widget.activeSpaceId ||
        oldWidget.activeSpaceName != widget.activeSpaceName) {
      setState(() {
        _activeSpaceId = widget.activeSpaceId;
        _activeSpaceName = widget.activeSpaceName.isNotEmpty
            ? widget.activeSpaceName
            : "mySpace".tr();
      });
      debugPrint(
          '[Topwidgets] didUpdateWidget -> id=$_activeSpaceId name=$_activeSpaceName');
    }
  }

  void _handleCategorySelection(String cat) {
    final map = {
      'Restawran': 'Restaurant',
      'Pamimili': 'Shopping',
      'Grocery': 'Groceries',
    };
    final mapped = map[cat] ?? cat;
    setState(() {
      _selectedCategory = _selectedCategory == mapped ? null : mapped;
    });
    widget.onCategorySelected(_selectedCategory ?? '');
  }

  Future<void> _openSpaceDialog(BuildContext ctx) async {
    widget.onOverlayChange(true);

    final result = await showGeneralDialog<Map<String, String>>(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Container(color: Colors.black26),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Provider.of<ThemeProvider>(ctx, listen: false).isDarkMode
                  ? Colors.grey[800]
                  : Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: SizedBox(
                width: MediaQuery.of(ctx).size.width,
                height: MediaQuery.of(ctx).size.height * 0.6,
                child: SpaceSelectionSheet(
                  // Use the parent's active values as the initial ones
                  initialId: _activeSpaceId,
                  initialName: _activeSpaceName,
                  onPick: (id, name) {
                    Navigator.of(ctx).pop({'id': id, 'name': name});
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    widget.onOverlayChange(false);

    if (result != null) {
      setState(() {
        _activeSpaceName = result['name'] ?? "mySpace".tr();
        _activeSpaceId = result['id'] ?? '';
      });

      // notify parent (existing callbacks)
      widget.onSpaceSelected(result['id']!, result['name'] ?? '');
      widget.onSpaceIdChanged(result['id']!);
      if ((result['id'] ?? '').isEmpty) widget.onMySpaceSelected();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final purple = const Color(0xFF6750A4);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 15, 0, 0),
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row
              GestureDetector(
                behavior: HitTestBehavior
                    .translucent, // so taps on empty parts still register
                onTap: () => widget.onTopTap?.call(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Settings
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: CircleAvatar(
                        key: widget.settingsKey,
                        radius: 20,
                        backgroundColor:
                            isDark ? Colors.grey[800] : Colors.white,
                        child: IconButton(
                          icon: Icon(Icons.settings,
                              color: isDark ? Colors.white : purple),
                          onPressed: () async {
                            final result =
                                await Navigator.pushNamed(context, '/settings');

                            if (result is Map &&
                                result['spaceUpdated'] == true) {
                              final id = (result['spaceId'] ?? '') as String;
                              final name =
                                  (result['spaceName'] ?? '') as String;

                              // update Topwidgets internal UI
                              setState(() {
                                _activeSpaceId = id;
                                _activeSpaceName =
                                    name.isNotEmpty ? name : "mySpace".tr();
                              });

                              // notify the GpsScreen/parent (so LocationHandler etc. also update)
                              widget.onSpaceSelected(id, name);
                              widget.onSpaceIdChanged(id);
                              if (id.isEmpty) widget.onMySpaceSelected();
                            }
                          },
                        ),
                      ),
                    ),

                    // Fixed-width "My Space" pill (now shows parent's value)
                    GestureDetector(
                      onTap: () => _openSpaceDialog(context),
                      child: Container(
                        width: 175,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                _activeSpaceName.length > 12
                                    ? '${_activeSpaceName.substring(0, 12)}…'
                                    : _activeSpaceName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : purple,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                              color: isDark ? Colors.white : purple,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Inbox
                    Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: CircleAvatar(
                        key: widget.inboxKey,
                        radius: 20,
                        backgroundColor:
                            isDark ? Colors.grey[800] : Colors.white,
                        child: IconButton(
                          icon: Icon(Icons.chat,
                              color: isDark ? Colors.white : purple),
                          onPressed: () =>
                              Navigator.pushNamed(context, '/inbox'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Category row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // NEW: PWD category as the first option
                    CategoryItem(
                      title: 'pwd'.tr(),
                      icon: Icons.accessible,
                      onCategorySelected: _handleCategorySelection,
                      isSelected: _selectedCategory == 'PWD',
                    ),
                    CategoryItem(
                      title: 'hotel'.tr(),
                      icon: Icons.hotel,
                      onCategorySelected: _handleCategorySelection,
                      isSelected: _selectedCategory == 'Hotel',
                    ),
                    CategoryItem(
                      title: 'restaurant'.tr(),
                      icon: Icons.restaurant,
                      onCategorySelected: _handleCategorySelection,
                      isSelected: ['Restaurant', 'Restawran']
                          .contains(_selectedCategory),
                    ),
                    CategoryItem(
                      title: 'bus'.tr(),
                      icon: Icons.directions_bus,
                      onCategorySelected: _handleCategorySelection,
                      isSelected: _selectedCategory == 'Bus',
                    ),
                    CategoryItem(
                      title: 'shopping'.tr(),
                      icon: Icons.shop_2,
                      onCategorySelected: _handleCategorySelection,
                      isSelected:
                          ['Shopping', 'Pamimili'].contains(_selectedCategory),
                    ),
                    CategoryItem(
                      title: 'groceries'.tr(),
                      icon: Icons.shopping_cart,
                      onCategorySelected: _handleCategorySelection,
                      isSelected:
                          ['Groceries', 'Grocery'].contains(_selectedCategory),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
