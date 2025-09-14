// lib/presentation/widgets/simple_contact_dialog.dart
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SimpleContactDialog extends StatefulWidget {
  final List<Map<String, String>> contacts;

  const SimpleContactDialog({Key? key, required this.contacts})
      : super(key: key);

  @override
  _SimpleContactDialogState createState() => _SimpleContactDialogState();
}

class _SimpleContactDialogState extends State<SimpleContactDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<Map<String, String>> _filtered;
  String _query = '';
  int? _highlightIndex;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.contacts);
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
        _filtered = widget.contacts.where((c) {
          final name = (c['name'] ?? '').toLowerCase();
          final phone = (c['phone'] ?? '').toLowerCase();
          return name.contains(_query) || phone.contains(_query);
        }).toList();
      });
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.96,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildAvatar(String? name) {
    final initials = (name?.trim().isNotEmpty == true)
        ? name!
            .trim()
            .split(' ')
            .map((s) => s.isNotEmpty ? s[0] : '')
            .take(2)
            .join()
        : '?';

    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.03).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6750A4), Color(0xFFB388EB)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initials.toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final bg = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subText = isDarkMode ? Colors.grey[400] : Colors.grey[700];

    return Dialog(
      backgroundColor: bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560, maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header (glassy card look)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                gradient: isDarkMode
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFF6F2FF), Color(0xFFFFFFFF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'select_contact'.tr(),
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'pick_a_contact_to_add_as_emergency'.tr(),
                          style: TextStyle(fontSize: 13, color: subText),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[850] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                      ),
                    ),
                    child: IconButton(
                      tooltip: 'cancel'.tr(),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: subText),
                    ),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    const Icon(Icons.search),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'search_contacts'.tr(),
                          hintStyle: TextStyle(color: subText),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchCtrl.clear(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // List
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(18)),
                child: _filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_off,
                                size: 64,
                                color: subText,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _query.isEmpty
                                    ? 'no_contacts_found'.tr()
                                    : 'no_results'.tr(),
                                style: TextStyle(color: subText, fontSize: 15),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Material(
                        color: bg,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.grey[200]),
                          itemBuilder: (context, index) {
                            final contact = _filtered[index];
                            final name = contact['name'] ?? '';
                            final phone = contact['phone'];
                            final isHighlighted = _highlightIndex == index;

                            return GestureDetector(
                              onTapDown: (_) =>
                                  setState(() => _highlightIndex = index),
                              onTapCancel: () =>
                                  setState(() => _highlightIndex = null),
                              onTap: () async {
                                setState(() => _highlightIndex = index);
                                await Future.delayed(
                                    const Duration(milliseconds: 120));
                                Navigator.of(context).pop(contact);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14.0, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isHighlighted
                                      ? (isDarkMode
                                          ? Colors.grey[800]
                                          : Colors.grey[50])
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    _buildAvatar(name),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            phone ?? 'no_phone_number'.tr(),
                                            style: TextStyle(
                                                fontSize: 13, color: subText),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: isDarkMode
                                                ? Colors.grey[800]!
                                                : Colors.grey[200]!),
                                        color: isDarkMode
                                            ? Colors.grey[850]
                                            : Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.03),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.add, size: 16),
                                          const SizedBox(width: 8),
                                          Text(
                                            'select'.tr(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
