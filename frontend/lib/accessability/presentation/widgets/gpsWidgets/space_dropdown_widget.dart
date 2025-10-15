import 'dart:async';
import 'package:accessability/accessability/presentation/widgets/shimmer/shimmer_space_selection.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/verification_code_widget.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

class SpaceSelectionSheet extends StatefulWidget {
  final void Function(String id, String name) onPick;
  final String initialId;
  final bool autoPickOnLoad;
  final String initialName;

  const SpaceSelectionSheet({
    super.key,
    required this.initialId,
    required this.initialName,
    required this.onPick,
    this.autoPickOnLoad = false,
  });

  @override
  _SpaceSelectionSheetState createState() => _SpaceSelectionSheetState();
}

class _SpaceSelectionSheetState extends State<SpaceSelectionSheet> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  static const Color _purple = Color(0xFF6750A4);
  static const Color _lightPurple = Color(0xFFD8CFE8);

  bool _didAutoSelect = false;
  late String _activeId;
  late String _activeName;
  List<Map<String, dynamic>> _spaces = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _spacesSub;

  @override
  void initState() {
    super.initState();
    _activeId = widget.initialId.isNotEmpty ? widget.initialId : '';
    _activeName = widget.initialId.isNotEmpty ? widget.initialName : '';
    _listenToSpaces();
  }

  @override
  void dispose() {
    _spacesSub?.cancel();
    super.dispose();
  }

  void _listenToSpaces() {
    setState(() => _isLoading = true);

    _spacesSub = _firestore
        .collection('Spaces')
        .where('members', arrayContains: _auth.currentUser?.uid)
        .snapshots()
        .listen((snap) async {
      try {
        final futures = snap.docs.map((d) async {
          final id = d.id;
          final data = d.data() as Map<String, dynamic>;
          final name = (data['name'] as String?) ?? 'Unnamed';
          final raw = data['members'];
          List<String> members = <String>[];
          if (raw is List && raw.isNotEmpty) {
            members = List<String>.from(raw);
          }

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
        built.sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String));

        if (!mounted) return;

        setState(() {
          _spaces = built;
          _isLoading = false;

          if (_spaces.isNotEmpty) {
            final hasActive = _activeId.isNotEmpty &&
                _spaces.any((s) => s['id'] == _activeId);
            if (!hasActive) {
              _activeId = _spaces[0]['id'] as String;
              _activeName = _spaces[0]['name'] as String;
            }
          } else {
            _activeId = '';
            _activeName = '';
            _didAutoSelect = false;
          }
        });

        if (_spaces.isNotEmpty && !_didAutoSelect && widget.autoPickOnLoad) {
          _didAutoSelect = true;
          final selectedId = _activeId;
          final selectedName = _activeName;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onPick(selectedId, selectedName);
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }, onError: (_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

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

  Widget _singleAvatarInner(Map<String, String> a, double size) {
    final photo = a['photo'] ?? '';
    final initial = a['initial'] ?? '?';
    if (photo.isNotEmpty && photo.startsWith('http')) {
      return Image.network(photo, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
        return _initialBox(initial, size);
      });
    }
    return _initialBox(initial, size);
  }

  Widget _initialBox(String initial, double size) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF0F6B4A),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (_activeId.isEmpty) {
                    Navigator.pushNamed(context, '/createSpace')
                        .then((success) {
                      if (success == true) _listenToSpaces();
                    });
                  } else {
                    Navigator.of(context)
                        .pop({'id': _activeId, 'name': _activeName});
                  }
                },
                child: Container(
                  width: 175,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.4)
                            : Colors.black26,
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _isLoading
                              ? 'loading'.tr()
                              : (_activeName.isNotEmpty
                                  ? (_activeName.length > 12
                                      ? '${_activeName.substring(0, 12)}…'
                                      : _activeName)
                                  : 'selectSpace'.tr()),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : _purple,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_up,
                          size: 20, color: isDark ? Colors.white : _purple),
                    ],
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_activeId.isEmpty) {
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
            child: Semantics(
                label: 'Add a person in your space',
                child:
                    Icon(Icons.person_add_outlined, color: _purple, size: 24)),
          ),
        ],
      ),
    );
  }

  Widget _buildSpaceTile(Map<String, dynamic> space) {
    final String id = space['id'] as String;
    final String name = space['name'] as String;
    final bool isSelected = id == _activeId;
    final avatars = List<Map<String, String>>.from(space['avatars'] ?? []);
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    final Color textColor = isSelected
        ? (isDark ? Colors.white : const Color(0xFF6750A4))
        : (isDark ? Colors.white70 : Colors.black87);

    final Color? bgColor = isSelected
        ? (isDark ? Colors.deepPurple.withOpacity(0.25) : Colors.grey[200])
        : null;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: isSelected
            ? const Border(left: BorderSide(width: 4, color: Color(0xFF6750A4)))
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
            color: textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check, color: Color(0xFF6750A4))
            : null,
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
              Expanded(
                child: ShimmerSpaceSelection(
                  isDark: isDark,
                  itemCount: 4,
                ),
              )
            else ...[
              if (_spaces.isEmpty) ...[
                _buildSpaceTile(
                    {'id': '', 'name': 'mySpace'.tr(), 'avatars': []}),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 4),
              ],
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _spaces.length,
                  itemBuilder: (_, idx) {
                    final s = _spaces[idx];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSpaceTile(s),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 4),
                      ],
                    );
                  },
                ),
              ),
            ],
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/createSpace')
                              .then((success) {
                        if (success == true) _listenToSpaces();
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text('createSpace'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/joinSpace')
                              .then((success) {
                        if (success == true) _listenToSpaces();
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
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
