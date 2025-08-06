// lib/presentation/widgets/homepageWidgets/space_selection_sheet.dart

import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

class SpaceSelectionSheet extends StatefulWidget {
  final void Function(String id, String name) onPick;
  const SpaceSelectionSheet({required this.onPick});

  @override
  _SpaceSelectionSheetState createState() => _SpaceSelectionSheetState();
}

class _SpaceSelectionSheetState extends State<SpaceSelectionSheet> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  static const Color _purple = Color(0xFF6750A4);

  List<Map<String, String>> _spaces = [];
  String _activeId = '';
  String _activeName = 'mySpace'.tr();

  @override
  void initState() {
    super.initState();
    _firestore
        .collection('Spaces')
        .where('members', arrayContains: _auth.currentUser?.uid)
        .snapshots()
        .listen((snap) {
      setState(() {
        _spaces = snap.docs
            .map((d) => {'id': d.id, 'name': d['name'] as String})
            .toList();
      });
    });
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
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
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
                  color: isDark ? Colors.white : _purple,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: isDark ? Colors.white : _purple,
            ),
          ],
        ),
      ),
    );

    // Now just an Icon, no container
    final addPeopleBtn = GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/createSpace'),
      child: Icon(Icons.person_add_outlined, color: _purple, size: 24),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Center(child: pill)),
          addPeopleBtn,
        ],
      ),
    );
  }

  Widget _buildSpaceTile(String id, String name) {
    final isSelected = id == _activeId;
    return Container(
      color: isSelected ? _purple.withOpacity(0.15) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade300,
          child: Text(name[0].toUpperCase()),
        ),
        title: Text(
          name,
          style: TextStyle(
            color: isSelected ? _purple : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : null,
          ),
        ),
        trailing: isSelected ? Icon(Icons.check, color: _purple) : null,
        onTap: () {
          setState(() {
            _activeId = id;
            _activeName = name;
          });
          widget.onPick(id, name);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          _buildHeader(),
          const Divider(height: 1),
          _buildSpaceTile('', 'mySpace'.tr()),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: _spaces.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, idx) {
                final s = _spaces[idx];
                return _buildSpaceTile(s['id']!, s['name']!);
              },
            ),
          ),
          const Divider(height: 1),

          // Bottom buttons: purple background, vertical padding = 10
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.onPick('', 'createSpace'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'createSpace'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.onPick('', 'joinSpace'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'joinSpace'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
