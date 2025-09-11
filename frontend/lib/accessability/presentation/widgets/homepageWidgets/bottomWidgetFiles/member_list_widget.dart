import 'package:accessability/accessability/firebaseServices/place/geocoding_service.dart'
    show OpenStreetMapGeocodingService;
import 'package:accessability/accessability/presentation/widgets/shimmer/shimmer_member_list.dart'
    show ShimmerMemberList;
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class MemberListWidget extends StatefulWidget {
  final String activeSpaceId;
  final List<Map<String, dynamic>> members;
  final String? selectedMemberId;
  final DateTime? yourLastUpdate;
  final Future<void> Function()? onShowMyInfoPressed;

  /// Your own location + label
  final LatLng? yourLocation;
  final String? yourAddressLabel;

  /// Called for both member taps and “Add a person”
  final Function(LatLng, String) onMemberPressed;
  final VoidCallback onAddPerson;

  final bool isLoading;

  const MemberListWidget({
    super.key,
    required this.activeSpaceId,
    required this.members,
    required this.onMemberPressed,
    required this.onAddPerson,
    this.selectedMemberId,
    this.yourLocation,
    this.yourAddressLabel,
    this.yourLastUpdate,
    this.isLoading = false, // default false
    this.onShowMyInfoPressed, // <-- add here
  });

  @override
  _MemberListWidgetState createState() => _MemberListWidgetState();
}

class _MemberListWidgetState extends State<MemberListWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _selectedId;

  /// Tracks currently "blinking" ids for the brief purple flash feedback.
  final Set<String> _blinkIds = {};

  @override
  void initState() {
    super.initState();
    // Initialize local selection from parent (if parent already selected someone).
    _selectedId = widget.selectedMemberId;
  }

  @override
  void didUpdateWidget(covariant MemberListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent changed selectedMemberId, sync local _selectedId so visuals match
    if (widget.selectedMemberId != oldWidget.selectedMemberId) {
      // optional: blink to indicate parent-initiated selection
      if (widget.selectedMemberId != null &&
          widget.selectedMemberId!.isNotEmpty) {
        _blink(widget.selectedMemberId!);
      }
      setState(() {
        _selectedId = widget.selectedMemberId;
      });
    }
  }

  void _blink(String id,
      {Duration duration = const Duration(milliseconds: 260)}) {
    if (id.isEmpty) return;
    setState(() {
      _blinkIds.add(id);
    });
    Future.delayed(duration, () {
      if (!mounted) return;
      setState(() {
        _blinkIds.remove(id);
      });
    });
  }

  // Helper: build full name from a member map with fallbacks
  String _fullNameFromMap(Map<String, dynamic>? m) {
    if (m == null) return 'Unknown';
    final fn = (m['firstName'] as String?)?.trim();
    final ln = (m['lastName'] as String?)?.trim();
    if ((fn?.isNotEmpty ?? false) && (ln?.isNotEmpty ?? false)) {
      return '$fn $ln';
    } else if (fn?.isNotEmpty ?? false) {
      return fn!;
    } else if (ln?.isNotEmpty ?? false) {
      return ln!;
    } else {
      final uname = (m['username'] as String?)?.trim();
      if (uname?.isNotEmpty ?? false) return uname!;
      return 'Unknown';
    }
  }

  // Helper to get first and last name strings separately (may be null/empty)
  Map<String, String?> _splitFirstLast(Map<String, dynamic>? m) {
    if (m == null) return {'firstName': null, 'lastName': null};
    final fn = (m['firstName'] as String?)?.trim();
    final ln = (m['lastName'] as String?)?.trim();
    return {'firstName': fn, 'lastName': ln};
  }

  // Helper to get a single-char avatar initial from available name sources
  String _initialFromName(
      String? name, Map<String, dynamic>? m, User? authUser) {
    if (name != null && name.trim().isNotEmpty)
      return name.trim()[0].toUpperCase();
    final fn = (m?['firstName'] as String?)?.trim();
    if (fn?.isNotEmpty ?? false) return fn![0].toUpperCase();
    final display = authUser?.displayName;
    if (display != null && display.trim().isNotEmpty)
      return display.trim()[0].toUpperCase();
    final emailPart = authUser?.email?.split('@').first;
    if (emailPart != null && emailPart.isNotEmpty)
      return emailPart[0].toUpperCase();
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final purple = const Color(0xFF6750A4);

    if (widget.isLoading) {
      return ShimmerMemberList(isDark: isDark, itemCount: 3);
    }

    final currentUser = _auth.currentUser;

    // Try to find current user's member map (if present in widget.members)
    Map<String, dynamic>? currentMemberMap;
    for (final m in widget.members) {
      try {
        if ((m['uid'] as String?) == currentUser?.uid) {
          currentMemberMap = m;
          break;
        }
      } catch (_) {
        // ignore malformed map entries
      }
    }

    // Build a display name for the current user: prefer first+last from members map,
    // then displayName, then email local-part, finally 'User'
    final userName = currentMemberMap != null
        ? _fullNameFromMap(currentMemberMap)
        : ((currentUser?.displayName?.trim().isNotEmpty ?? false)
            ? currentUser!.displayName!.trim()
            : (currentUser?.email?.split('@').first ?? 'User'));

    final avatarChar =
        _initialFromName(userName, currentMemberMap, currentUser);

    // Nothing to show?
    if (widget.activeSpaceId.isEmpty) return const SizedBox();

    // Build rows
    final List<Widget> rows = [];

    // If there are no other members, but we have a user location, show only the current user
    if (widget.members.isEmpty) {
      if (widget.yourLocation == null || widget.yourAddressLabel == null) {
        return const SizedBox();
      }
      return Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: currentUser?.photoURL != null
                  ? NetworkImage(currentUser!.photoURL!)
                  : null,
              child: currentUser?.photoURL == null
                  ? Text(avatarChar,
                      style: const TextStyle(color: Colors.white))
                  : null,
            ),
            title: Text(
              userName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.yourAddressLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (widget.yourLastUpdate != null)
                  Text(
                    'Updated: ${_timeDiff(widget.yourLastUpdate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
              ],
            ),
            onTap: () async {
              if (widget.onShowMyInfoPressed != null) {
                try {
                  await widget.onShowMyInfoPressed!();
                } catch (e, st) {
                  debugPrint('onShowMyInfoPressed threw: $e\n$st');
                  // fallback
                  widget.onMemberPressed(
                      widget.yourLocation!, _auth.currentUser!.uid);
                }
                return;
              }
              widget.onMemberPressed(
                  widget.yourLocation!, _auth.currentUser!.uid);
            },
          ),
          // Add-person CTA still useful even if no members
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: InkWell(
              onTap: widget.onAddPerson,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: purple.withOpacity(0.2),
                    child: Icon(Icons.person_add, size: 28, color: purple),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add a person',
                    style: TextStyle(
                        color: purple,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 1) Current user row (if we have location/address)
    if (widget.yourLocation != null && widget.yourAddressLabel != null) {
      final currentId = _auth.currentUser?.uid ?? '';
      // Current user row (replace your existing block)
      rows.add(
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          color: _blinkIds.contains(currentId)
              ? purple.withOpacity(0.28)
              : (widget.selectedMemberId == currentId ||
                      _selectedId == currentId
                  ? purple.withOpacity(0.12)
                  : (isDark ? Colors.grey[900] : Colors.white)),
          child: Material(
            color: Colors
                .transparent, // keep AnimatedContainer visual, but give Ink something to draw on
            child: InkWell(
              // visible ripple + pressed highlight
              splashColor: purple.withOpacity(0.28),
              highlightColor: purple.withOpacity(0.12),
              onTap: () async {
                if (currentId.isNotEmpty) _blink(currentId);
                setState(() => _selectedId = currentId);

                if (widget.onShowMyInfoPressed != null) {
                  try {
                    await widget.onShowMyInfoPressed!();
                  } catch (e, st) {
                    debugPrint('onShowMyInfoPressed threw: $e\n$st');
                    // fallback to older behavior
                    widget.onMemberPressed(widget.yourLocation!, currentId);
                  }
                  return;
                }

                widget.onMemberPressed(widget.yourLocation!, currentId);
              },

              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: currentUser?.photoURL != null
                      ? NetworkImage(currentUser!.photoURL!)
                      : null,
                  child: currentUser?.photoURL == null
                      ? Text(avatarChar,
                          style: const TextStyle(color: Colors.white))
                      : null,
                ),
                title: Text(
                  userName,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.yourAddressLabel!,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54)),
                    if (widget.yourLastUpdate != null)
                      Text('Updated: ${_timeDiff(widget.yourLastUpdate!)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54)),
                  ],
                ),
                selected: widget.selectedMemberId == _auth.currentUser?.uid ||
                    _selectedId == currentUser?.uid,
              ),
            ),
          ),
        ),
      );
      rows.add(const Divider());
    }

    // 2) Other members
    for (final m
        in widget.members.where((m) => m['uid'] != _auth.currentUser?.uid)) {
      final memberId = (m['uid'] as String?) ?? '';
      rows.add(
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          color: _blinkIds.contains(memberId)
              ? purple.withOpacity(0.28)
              : (widget.selectedMemberId == memberId || _selectedId == memberId
                  ? purple.withOpacity(0.12)
                  : (isDark ? Colors.grey[900] : Colors.white)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: purple.withOpacity(0.28),
              highlightColor: purple.withOpacity(0.12),
              onTap: () async {
                if (memberId.isNotEmpty) _blink(memberId);
                // locally mark selected for immediate visual feedback
                setState(() => _selectedId = memberId);

                final snap = await _firestore
                    .collection('UserLocations')
                    .doc(memberId)
                    .get();
                final data = snap.data();
                if (data != null) {
                  final lat = data['latitude'], lng = data['longitude'];
                  final addr = await _getAddressFromLatLng(LatLng(lat, lng));
                  setState(() {
                    m['address'] = addr;
                    m['lastUpdate'] = data['timestamp'];
                  });
                  widget.onMemberPressed(LatLng(lat, lng), memberId);
                }
              },
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      (m['profilePicture'] as String).startsWith('http')
                          ? NetworkImage(m['profilePicture'])
                          : const AssetImage(
                                  'assets/images/others/default_profile.png')
                              as ImageProvider,
                ),
                title: Text(
                  _fullNameFromMap(m),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current: ${m['address'] ?? '…'}',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54)),
                    if (m['lastUpdate'] != null)
                      Text('Updated: ${_formatLastUpdate(m['lastUpdate'])}',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54)),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.chat, color: isDark ? Colors.white : purple),
                  onPressed: () {
                    final fullName = _fullNameFromMap(m);
                    final names = _splitFirstLast(m);
                    Navigator.pushNamed(context, '/chatconvo', arguments: {
                      'receiverUsername': fullName,
                      'receiverFirstName': names['firstName'] ?? '',
                      'receiverLastName': names['lastName'] ?? '',
                      'receiverID': m['uid'],
                      'receiverProfilePicture': m['profilePicture'],
                    });
                  },
                ),
                selected: widget.selectedMemberId == memberId ||
                    _selectedId == memberId,
                selectedTileColor: purple.withOpacity(0.12),
              ),
            ),
          ),
        ),
      );
      rows.add(const Divider());
    }

    // 3) Add a person CTA
    rows.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: InkWell(
          onTap: widget.onAddPerson,
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: purple.withOpacity(0.2),
                child: Icon(Icons.person_add, size: 28, color: purple),
              ),
              const SizedBox(width: 12),
              Text(
                'Add a person',
                style: TextStyle(
                    color: purple, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(children: rows);
  }

  /// Convert different timestamp types to a human friendly "x ago" string.
  String _formatLastUpdate(dynamic ts) {
    DateTime? dt;
    if (ts == null) return 'Unknown';
    if (ts is Timestamp)
      dt = ts.toDate();
    else if (ts is DateTime)
      dt = ts;
    else if (ts is int)
      dt = DateTime.fromMillisecondsSinceEpoch(ts);
    else
      return 'Unknown';
    return _timeDiff(dt);
  }

  String _timeDiff(DateTime ts) {
    final d = DateTime.now().difference(ts);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Future<String> _getAddressFromLatLng(LatLng pos) async {
    try {
      return await OpenStreetMapGeocodingService().getAddressFromLatLng(pos);
    } catch (_) {
      return 'Unavailable';
    }
  }
}
