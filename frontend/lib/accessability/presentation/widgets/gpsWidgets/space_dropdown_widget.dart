// lib/presentation/widgets/homepageWidgets/space_selection_sheet.dart

import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

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

  List<Map<String, String>> _spaces = [];

  @override
  void initState() {
    super.initState();
    _activeId = widget.initialId;
    _activeName = widget.initialName;

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

    final addBtn = GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/createSpace'),
      child: Icon(Icons.person_add_outlined, color: _purple, size: 24),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(children: [Expanded(child: Center(child: pill)), addBtn]),
    );
  }

  Widget _buildSpaceTile(String id, String name) {
    final isSelected = id == _activeId;
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.grey[200] : null,
        border: isSelected
            ? const Border(left: BorderSide(width: 4, color: _purple))
            : null,
      ),
      child: ListTile(
        // <— ADD THIS LINE
        minVerticalPadding: 0,

        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade300,
          child: Text(name[0].toUpperCase()),
        ),
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

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            // header
            _buildHeader(),
            // no top divider

            // "My Space" if none
            if (_spaces.isEmpty) ...[
              _buildSpaceTile('', 'mySpace'.tr()),
              if (_activeId.isNotEmpty)
                const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 4),
            ],

            // space list
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _spaces.length,
                separatorBuilder: (context, idx) {
                  // look ahead to the next space
                  final nextId = _spaces[idx + 1]['id']!;
                  final isNextSelected = nextId == _activeId;
                  return Column(
                    children: [
                      if (!isNextSelected)
                        const Divider(height: 1, thickness: 0.5),
                      // still keep your 4px gap
                      const SizedBox(height: 4),
                    ],
                  );
                },
                itemBuilder: (_, idx) {
                  final s = _spaces[idx];
                  return _buildSpaceTile(s['id']!, s['name']!);
                },
              ),
            ),

            // divider above buttons
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 8),

            // Create / Join buttons (smaller)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.onPick('', 'createSpace'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text('createSpace'.tr(),
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.onPick('', 'joinSpace'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text('joinSpace'.tr(),
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),

            // extra padding below buttons
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
