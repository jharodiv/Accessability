import 'package:accessability/accessability/data/model/emergency_contact.dart';
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
    // try these names in order until we find a non-empty string
    return _stringProp(c, ['relationship', 'relation', 'arrival']);
  }

  String _phoneOf(EmergencyContact c) {
    return _stringProp(c, ['phone', 'number', 'update', 'tel']);
  }

  // NEW: compact, muted action button used in the bottom sheet
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

  // put these inside EmergencyContactsList

  String _stringProp(dynamic obj, List<String> props) {
    for (final p in props) {
      try {
        final dyn = obj as dynamic;
        final val = dyn?.$;
        {
          '';
        }
        ; // placeholder to keep analyzer quiet
      } catch (_) {}
    }
    // above hack isn't needed at runtime; below we do actual tries:
    for (final p in props) {
      try {
        final dyn = obj as dynamic;
        final v = (() {
          switch (p) {
            case 'relationship':
              return dyn.relationship;
            case 'relation':
              return dyn.relation;
            case 'arrival':
              return dyn.arrival;
            case 'phone':
              return dyn.phone;
            case 'number':
              return dyn.number;
            case 'update':
              return dyn.update;
            case 'tel':
              return dyn.tel;
            default:
              return null;
          }
        })();
        if (v != null) {
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
      } catch (_) {
        // ignore and try next
      }
    }
    return '';
  }

  // Reworked bottom sheet: compact, muted, no overflow
  void _showActionsSheet(BuildContext context, EmergencyContact contact,
      String phone, bool isDark) {
    final mq = MediaQuery.of(context);
    // cap height so it never overflows
    final sheetHeight = (mq.size.height * 0.28).clamp(140.0, 260.0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: sheetHeight,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // small handle
                  Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  // header row
                  Row(
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
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF5A2B9B),
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(contact.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87)),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(phone,
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                      fontSize: 13)),
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
                  const SizedBox(height: 14),

                  // actions — responsive: use Row with evenly spaced actions; wrap on small widths
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // use Wrap so actions never overflow horizontally
                        return Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 18,
                            runSpacing: 12,
                            children: [
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
                                        SnackBar(
                                            content: Text(
                                                'no_number_available'.tr())));
                                  }
                                },
                              ),
                              _sheetAction(
                                icon: Icons.message,
                                label: 'Message',
                                isDark: isDark,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onMessagePressed(contact);
                                },
                              ),
                              _sheetAction(
                                icon: Icons.delete_outline,
                                label: 'Delete',
                                isDark: isDark,
                                background: Colors.redAccent.withOpacity(0.9),
                                iconColor: Colors.white,
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dctx) => AlertDialog(
                                      title: Text('confirm_delete'.tr()),
                                      content: Text('confirm_delete_contact'
                                          .tr(args: [contact.name])),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dctx, false),
                                            child: Text('cancel'.tr())),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.redAccent),
                                          onPressed: () =>
                                              Navigator.pop(dctx, true),
                                          child: Text('delete'.tr()),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    onDeletePressed(contact.id);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
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
      // ultra compact empty state with single Add button inline to the right
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Spacer(),
            TextButton.icon(
              onPressed: onAddPressed,
              icon: Icon(Icons.person_add,
                  color: isDark
                      ? const Color(0xFFBDA6FF)
                      : const Color(0xFF7C5BE6)),
              label: Text('add'.tr(),
                  style: TextStyle(
                      color: isDark
                          ? const Color(0xFFBDA6FF)
                          : const Color(0xFF7C5BE6),
                      fontWeight: FontWeight.w800)),
            ),
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
              onTap: () {},
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

                    // text block (collapses if no location/arrival)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // name + relation (small)
                          Row(
                            children: [
                              Expanded(
                                child: Text(contact.name,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
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
                                )
                              ],
                            ],
                          ),

                          // only show location/arrival when present (no empty gap)
                          if (contact.location != null &&
                              contact.location
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    size: 12,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[700]),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(contact.location,
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[700],
                                          fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ],

                          if (contact.arrival != null &&
                              contact.arrival.toString().trim().isNotEmpty &&
                              (relation.isEmpty ||
                                  contact.arrival != relation)) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 12,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[700]),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(contact.arrival,
                                        style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[700],
                                            fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ],

                          // phone row always shown
                          const SizedBox(height: 6),
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

                    // compact three-dot button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            _showActionsSheet(context, contact, phone, isDark),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFF0F3FF),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.more_horiz),
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
