import 'package:accessability/accessability/data/model/emergency_contact.dart';
import 'package:accessability/accessability/presentation/widgets/reusableWidgets/delete_confirmation_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class EmergencyContactsList extends StatelessWidget {
  final List<EmergencyContact> contacts;
  final bool isDarkMode;
  final String uid;
  final VoidCallback onAddPressed;
  final void Function(String? number) onCallPressed;
  final void Function(EmergencyContact contact) onMessagePressed;
  final void Function(String? contactId) onDeletePressed;

  const EmergencyContactsList({
    Key? key,
    required this.contacts,
    required this.isDarkMode,
    required this.uid,
    required this.onAddPressed,
    required this.onCallPressed,
    required this.onMessagePressed,
    required this.onDeletePressed,
  }) : super(key: key);

  String _relationOf(EmergencyContact c) {
    final r = (c.relationship ?? '').toString().trim();
    return r;
  }

  String _phoneOf(EmergencyContact c) {
    final p = (c.phone ?? '').toString().trim();
    return p;
  }

  Widget _sheetAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    Color? background,
    Color? iconColor,
  }) {
    final bg =
        background ?? (isDark ? Colors.white10 : const Color(0xFFF3F5FF));
    final ic = iconColor ?? (isDark ? Colors.white : const Color(0xFF5A2B9B));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: ic, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF33303A),
            ),
          )
        ],
      ),
    );
  }

  void _showDetailsSheet(
    BuildContext context,
    EmergencyContact contact,
    String phone,
    bool isDark,
    void Function(String? number) onCallPressed,
    void Function(EmergencyContact contact) onMessagePressed,
    void Function(String? contactId) onDeletePressed,
  ) {
    const Color purple = Color(0xFF6750A4);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // header: avatar + name + relationship pill + close
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isDark
                          ? const Color(0xFF5E2FB7)
                          : const Color(0xFFF0E8FF),
                      child: Text(
                        contact.name.isNotEmpty
                            ? contact.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFF5A2B9B),
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (contact.relationship.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white10
                                      : const Color(0xFFF3E8FF),
                                  borderRadius: BorderRadius.circular(999)),
                              child: Text(contact.relationship,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF5A2B9B))),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close,
                          color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Optional compact info hint (if you want something above actions)
                // Removed explicit phone & location lines per request:
                // the Location action will show full location when tapped.
                // The Call action will use the `phone` value.

                // actions row — Call, Message, Location, Delete (all same style)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Call
                    _sheetAction(
                      icon: Icons.call,
                      label: 'Call',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (phone.isNotEmpty) {
                          onCallPressed(phone);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('no_number_available'.tr())),
                          );
                        }
                      },
                    ),

                    // Message
                    _sheetAction(
                      icon: Icons.message,
                      label: 'Message',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        onMessagePressed(contact);
                      },
                    ),

                    // Location (same style) - close sheet then show full-location dialog
                    _sheetAction(
                      icon: Icons.location_on,
                      label: 'Location',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (contact.location.trim().isNotEmpty) {
                          showDialog(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              title: Text('location'.tr()),
                              content: Text(contact.location),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dctx).pop(),
                                  child: Text('close'.tr()),
                                )
                              ],
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('no_location_available'.tr())),
                          );
                        }
                      },
                    ),

                    // Delete
                    _sheetAction(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      isDark: isDark,
                      background: Colors.redAccent.withOpacity(0.9),
                      iconColor: Colors.white,
                      onTap: () async {
                        Navigator.pop(
                            ctx); // close the sheet first (keeps previous behavior)

// show the styled confirmation dialog
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dctx) => DeleteConfirmationDialogWidget(
                            contactName: contact.name,
                            onConfirm: () {
                              // Optional: perform the delete action here, but better to let caller handle it.
                              // You may leave this empty and use the returned 'confirmed' boolean
                              // to run the deletion in the calling scope.
                            },
                          ),
                        );

// If the dialog returned true, call your deletion callback:
                        if (confirmed == true) {
                          onDeletePressed(contact.id);
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode;

    if (contacts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 18.0),
        child: Column(
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF8F4FF),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 6),
                    )
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.person_off_outlined,
                  size: 54,
                  color: isDark ? Colors.white70 : const Color(0xFF6B3FC5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'no_emergency_contacts_yet'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    }

    return Column(
      children: contacts.map((contact) {
        final relation = _relationOf(contact);
        final phone = _phoneOf(contact);

        return Column(
          children: [
            InkWell(
              onTap: () => _showDetailsSheet(context, contact, phone, isDark,
                  onCallPressed, onMessagePressed, onDeletePressed),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10.0, horizontal: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // avatar
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: isDark
                            ? const Color(0xFF6633CC)
                            : const Color(0xFFEFE7FF),
                        child: Text(
                            contact.name.isNotEmpty
                                ? contact.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF5A2B9B),
                                fontWeight: FontWeight.w700)),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // text block: name row (name + relation at right), then phone row below
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // top row: name (left) and relationship (right)
                          Row(
                            children: [
                              // name (takes available space)
                              Expanded(
                                child: Text(contact.name,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),

                              // relationship pill (if present) — appears to the right of the name
                              if (relation.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white10
                                          : const Color(0xFFF3E8FF),
                                      borderRadius: BorderRadius.circular(999)),
                                  child: Text(relation,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xFF5A2B9B))),
                                ),
                              ],
                            ],
                          ),

                          // phone row (small) below name
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.phone,
                                  size: 13,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      phone.isNotEmpty
                                          ? phone
                                          : 'no_number_available'.tr(),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.black87),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // compact three-dot button — vertically centered
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color:
                              isDark ? Colors.white12 : const Color(0xFFF0F3FF),
                          borderRadius: BorderRadius.circular(8)),
                      child: Center(
                        child: InkWell(
                          onTap: () => _showDetailsSheet(
                              context,
                              contact,
                              phone,
                              isDark,
                              onCallPressed,
                              onMessagePressed,
                              onDeletePressed),
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Icon(Icons.more_horiz),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // inset divider
            Padding(
              padding: const EdgeInsets.only(left: 62, right: 6),
              child: Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? Colors.white10 : Colors.grey[200]),
            ),
          ],
        );
      }).toList(),
    );
  }
}
