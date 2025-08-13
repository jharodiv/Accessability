// lib/presentation/widgets/homepageWidgets/space_selection_sheet.dart

import 'dart:async';

import 'package:AccessAbility/accessability/presentation/widgets/shimmer/shimmer_space_selection.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/verification_code_widget.dart'; // <-- added
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

/// SpaceSelectionSheet
/// - Shows list of "Spaces" the current user is a member of
/// - Displays a compact stacked avatar cluster as the leading widget
/// - Shows a shimmer placeholder while loading
class SpaceSelectionSheet extends StatefulWidget {
  final void Function(String id, String name) onPick;
  final String initialId;
  final String initialName;
  const SpaceSelectionSheet({
    super.key,
    required this.initialId,
    required this.initialName,
    required this.onPick,
  });

  @override
  _SpaceSelectionSheetState createState() => _SpaceSelectionSheetState();
}

class _SpaceSelectionSheetState extends State<SpaceSelectionSheet> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  static const Color _purple = Color(0xFF6750A4);

  late String _activeId;
  late String _activeName;

  /// Each space: { id, name, members: List<String>, avatars: List<Map<String,String>> }
  List<Map<String, dynamic>> _spaces = [];

  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _spacesSub;

  @override
  void initState() {
    super.initState();
    _activeId = widget.initialId;
    _activeName = widget.initialName;
    _listenToSpaces();
  }

  @override
  void dispose() {
    _spacesSub?.cancel();
    super.dispose();
  }

  void _listenToSpaces() {
    // show shimmer while we subscribe / fetch
    setState(() => _isLoading = true);

    _spacesSub = _firestore
        .collection('Spaces')
        .where('members', arrayContains: _auth.currentUser?.uid)
        .snapshots()
        .listen((snap) async {
      try {
        // For each space doc we will fetch a small set of user profiles (avatars)
        final futures = snap.docs.map((d) async {
          final id = d.id;
          final data = d.data() as Map<String, dynamic>;
          final name = (data['name'] as String?) ?? 'Unnamed';
          final raw = data['members'];
          List<String> members = <String>[];
          if (raw is List && raw.isNotEmpty) {
            members = List<String>.from(raw);
          }

          // Limit how many member profiles to fetch at once (whereIn supports up to 10)
          final limited = members.take(8).toList();

          List<Map<String, String>> avatars = [];
          if (limited.isNotEmpty) {
            try {
              final usersSnap = await _firestore
                  .collection('Users')
                  .where('uid', whereIn: limited)
                  .get();

              avatars = usersSnap.docs.map((u) {
                final udata = u.data();
                final photo = (udata['profilePicture'] ?? '') as String;
                final username = (udata['username'] ?? '') as String;
                final initial =
                    username.isNotEmpty ? username[0].toUpperCase() : '?';
                return {'photo': photo, 'initial': initial};
              }).toList();
            } catch (_) {
              // fallback to initials only
              avatars =
                  limited.map((m) => {'photo': '', 'initial': '?'}).toList();
            }
          }

          return {
            'id': id,
            'name': name,
            'members': members,
            'avatars': avatars,
          };
        }).toList();

        final built = await Future.wait(futures);
        // sort by name to keep order stable (optional)
        built.sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String));

        if (mounted) {
          setState(() {
            _spaces = built;
            _isLoading = false;
          });
        }
      } catch (e) {
        // if something fails, stop loading but keep UI stable
        if (mounted) setState(() => _isLoading = false);
      }
    }, onError: (_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  /// Avatar cluster: up to 3 avatars shown overlapping (horizontal),
  /// with a +N badge if more.
  Widget _avatarStack(List<Map<String, String>> avatars, double size) {
    final total = avatars.length;
    final display = avatars.take(3).toList();
    final overlap = size * 0.45;
    final width = size + (display.length - 1) * (size - overlap) + 8;

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < display.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipOval(child: _singleAvatarInner(display[i], size)),
              ),
            ),
          if (total > display.length)
            Positioned(
              left: display.length * (size - overlap),
              child: Container(
                width: size * 0.78,
                height: size * 0.78,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(size * 0.39),
                  border: Border.all(color: Colors.grey.shade200, width: 1.6),
                ),
                child: Center(
                  child: Text(
                    '+${total - display.length}',
                    style: TextStyle(
                      fontSize: size * 0.32,
                      fontWeight: FontWeight.w600,
                      color: _purple,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Returns an Image widget or a colored initial box sized to [size].
  Widget _singleAvatarInner(Map<String, String> a, double size) {
    final photo = a['photo'] ?? '';
    final initial = a['initial'] ?? '?';
    if (photo.isNotEmpty && photo.startsWith('http')) {
      return Image.network(photo, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
        // fallback to initials if image fails
        return _initialBox(initial, size);
      });
    }
    return _initialBox(initial, size);
  }

  Widget _initialBox(String initial, double size) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF0F6B4A), // adjust to your brand if needed
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.44,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final pill = GestureDetector(
      onTap: () => widget.onPick(_activeId, _activeName),
      child: Container(
        width: 175,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 4, offset: Offset(1, 1))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _activeName.length > 12
                    ? '${_activeName.substring(0, 12)}…'
                    : _activeName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : _purple),
              ),
            ),
            Icon(Icons.keyboard_arrow_down,
                size: 20, color: isDark ? Colors.white : _purple),
          ],
        ),
      ),
    );

    // Modified addBtn: open VerificationCodeScreen for the currently selected space.
    final addBtn = GestureDetector(
      onTap: () {
        if (_activeId.isEmpty) {
          // no space selected — fallback to create flow
          Navigator.pushNamed(context, '/createSpace').then((success) {
            if (success == true) _listenToSpaces();
          });
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerificationCodeScreen(
              spaceId: _activeId,
              spaceName: _activeName,
            ),
          ),
        );
      },
      child: Icon(Icons.person_add_outlined, color: _purple, size: 24),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(children: [Expanded(child: Center(child: pill)), addBtn]),
    );
  }

  Widget _buildSpaceTile(Map<String, dynamic> space) {
    final String id = space['id'] as String;
    final String name = space['name'] as String;
    final bool isSelected = id == _activeId;
    final avatars = List<Map<String, String>>.from(space['avatars'] ?? []);

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.grey[200] : null,
        border: isSelected
            ? const Border(left: BorderSide(width: 4, color: _purple))
            : null,
      ),
      child: ListTile(
        minVerticalPadding: 0,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        leading: _avatarStack(avatars, 44),
        title: Text(
          name,
          style: TextStyle(
            color: isSelected ? _purple : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: isSelected ? Icon(Icons.check, color: _purple) : null,
        onTap: () {
          setState(() {
            _activeId = id;
            _activeName = name;
          });
          Navigator.of(context).pop({'id': id, 'name': name});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // restrict max height so sheet stays “short”
    final maxHeight = MediaQuery.of(context).size.height * 0.6;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            _buildHeader(),
            if (_isLoading)
              // show shimmer while loading
              Expanded(
                child: ShimmerSpaceSelection(
                  isDark: isDark,
                  itemCount: 4,
                  // optional: pass how many avatars each shimmer tile should show
                  // avatarCounts: [3, 1, 2, 4],
                ),
              )
            else ...[
              if (_spaces.isEmpty) ...[
                // show placeholder "My Space" if none
                _buildSpaceTile(
                    {'id': '', 'name': 'mySpace'.tr(), 'avatars': []}),
                if (_activeId.isNotEmpty)
                  const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 4),
              ],
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _spaces.length,
                  separatorBuilder: (context, idx) {
                    final nextId =
                        _spaces.length > idx + 1 ? _spaces[idx + 1]['id']! : '';
                    final isNextSelected = nextId == _activeId;
                    return Column(
                      children: [
                        if (!isNextSelected)
                          const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 4),
                      ],
                    );
                  },
                  itemBuilder: (_, idx) {
                    final s = _spaces[idx];
                    return _buildSpaceTile(s);
                  },
                ),
              ),
            ],
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 8),
            // Update the buttons in the build method:
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/createSpace')
                              .then((success) {
                        if (success == true) {
                          // Refresh spaces if creation was successful
                          _listenToSpaces();
                        }
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text('createSpace'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/joinSpace')
                              .then((success) {
                        if (success == true) {
                          // Refresh spaces if join was successful
                          _listenToSpaces();
                        }
                      }),
                      child: Text('joinSpace'.tr()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
