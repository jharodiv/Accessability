import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:provider/provider.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';

class MemberListWidget extends StatefulWidget {
  final String activeSpaceId;
  final List<Map<String, dynamic>> members;
  final String? selectedMemberId;

  /// Your own location + label
  final LatLng? yourLocation;
  final String? yourAddressLabel;

  /// Called for both member taps and “Add a person”
  final Function(LatLng, String) onMemberPressed;
  final VoidCallback onAddPerson;

  const MemberListWidget({
    super.key,
    required this.activeSpaceId,
    required this.members,
    required this.onMemberPressed,
    required this.onAddPerson,
    this.selectedMemberId,
    this.yourLocation,
    this.yourAddressLabel,
  });

  @override
  _MemberListWidgetState createState() => _MemberListWidgetState();
}

class _MemberListWidgetState extends State<MemberListWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final purple = const Color(0xFF6750A4);

    final currentUser = _auth.currentUser;
    final userName = (currentUser?.displayName?.trim().isNotEmpty ?? false)
        ? currentUser!.displayName!.trim()
        : 'You';
    final avatarChar = userName[0];

    // Nothing to show?
    if (widget.activeSpaceId.isEmpty) return const SizedBox();

    // Build a single list of Widgets:
    final List<Widget> rows = [];

    if (widget.members.isEmpty) {
      if (widget.yourLocation == null || widget.yourAddressLabel == null) {
        return const SizedBox();
      }
      return Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: currentUser?.photoURL != null
                  ? NetworkImage(_auth.currentUser!.photoURL!)
                  : null,
              child: currentUser?.photoURL == null
                  ? Text(
                      avatarChar,
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            title: Text(
              _auth.currentUser?.displayName ?? 'You',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black),
            ),
            subtitle: Text(
              widget.yourAddressLabel!,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54),
            ),
            onTap: () => widget.onMemberPressed(
              widget.yourLocation!,
              _auth.currentUser!.uid,
            ),
          ),
        ],
      );
    }

    // 1) “You” at top
    if (widget.yourLocation != null && widget.yourAddressLabel != null) {
      rows.add(
        ListTile(
          leading: CircleAvatar(
            backgroundImage: currentUser?.photoURL != null
                ? NetworkImage(currentUser!.photoURL!)
                : null,
            child: currentUser?.photoURL == null
                ? Text(avatarChar, style: const TextStyle(color: Colors.white))
                : null,
          ),
          title: Text(
            userName,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black),
          ),
          subtitle: Text(
            widget.yourAddressLabel!,
            style: TextStyle(
                fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
          ),
          selected: widget.selectedMemberId == _auth.currentUser?.uid,
          onTap: () {
            setState(() => _selectedId = currentUser!.uid);
            widget.onMemberPressed(widget.yourLocation!, currentUser!.uid);
          },
        ),
      );
      rows.add(const Divider());
    }

    // 2) Other members
    for (final m
        in widget.members.where((m) => m['uid'] != _auth.currentUser?.uid)) {
      rows.add(
        GestureDetector(
          onTap: () async {
            setState(() => _selectedId = m['uid']);
            final snap = await _firestore
                .collection('UserLocations')
                .doc(m['uid'])
                .get();
            final data = snap.data();
            if (data != null) {
              final lat = data['latitude'], lng = data['longitude'];
              final addr = await _getAddressFromLatLng(LatLng(lat, lng));
              m['address'] = addr;
              m['lastUpdate'] = data['timestamp'];
              widget.onMemberPressed(LatLng(lat, lng), m['uid']);
            }
          },
          child: Container(
            color: _selectedId == m['uid']
                ? purple.withOpacity(0.2)
                : isDark
                    ? Colors.grey[900]
                    : Colors.white,
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    (m['profilePicture'] as String).startsWith('http')
                        ? NetworkImage(m['profilePicture'])
                        : const AssetImage(
                                'assets/images/others/default_profile.png')
                            as ImageProvider,
              ),
              title: Text(m['username'],
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current: ${m['address'] ?? '…'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  if (m['lastUpdate'] != null)
                    Text(
                      'Updated: ${_timeDiff((m['lastUpdate'] as Timestamp).toDate())}',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.chat, color: isDark ? Colors.white : purple),
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/chatconvo',
                  arguments: {
                    'receiverUsername': m['username'],
                    'receiverID': m['uid'],
                    'receiverProfilePicture': m['profilePicture'],
                  },
                ),
              ),
            ),
          ),
        ),
      );
      rows.add(const Divider());
    }

    // 3) “Add a person” at bottom
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

  Future<String> _getAddressFromLatLng(LatLng pos) async {
    try {
      return await OpenStreetMapGeocodingService().getAddressFromLatLng(pos);
    } catch (_) {
      return 'Unavailable';
    }
  }

  String _timeDiff(DateTime ts) {
    final d = DateTime.now().difference(ts);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
