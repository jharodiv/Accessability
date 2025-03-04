import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/category_item.dart';

class Topwidgets extends StatefulWidget {
  final Function(bool) onOverlayChange;
  final Function(String) onCategorySelected;
  final GlobalKey inboxKey;
  final GlobalKey settingsKey;
  final Function(String) onSpaceSelected;
  final VoidCallback onMySpaceSelected; // Add this callback

  const Topwidgets({
    super.key,
    required this.onCategorySelected,
    required this.onOverlayChange,
    required this.inboxKey,
    required this.settingsKey,
    required this.onSpaceSelected,
    required this.onMySpaceSelected, // Add this parameter
  });

  @override
  TopwidgetsState createState() => TopwidgetsState();
}

class TopwidgetsState extends State<Topwidgets> {
  bool _isDropdownOpen = false;
  List<Map<String, dynamic>> _spaces = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _activeSpaceName = 'My Space'; // Default to "My Space"

  @override
  void initState() {
    super.initState();
    _listenToSpaces();
  }

  void _listenToSpaces() {
    final user = _auth.currentUser;
    if (user == null) return;

    _firestore
        .collection('Spaces')
        .where('members', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _spaces = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'name': doc['name'],
            'creator': doc['creator'],
          };
        }).toList();
      });
    });
  }

  void _selectSpace(String spaceId, String spaceName) {
    widget.onSpaceSelected(spaceId);
    setState(() {
      _activeSpaceName = spaceName;
      _isDropdownOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.only(top: 15.0, left: 20.0, right: 20.0),
          color: Colors.transparent,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Settings button
                  GestureDetector(
                    key: widget.settingsKey,
                    onTap: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.settings, color: Color(0xFF6750A4)),
                    ),
                  ),
                  // My Space Dropdown Button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDropdownOpen = !_isDropdownOpen;
                      });
                      widget.onOverlayChange(_isDropdownOpen);
                    },
                    child: Container(
                      width: 175,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
                          Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Text(
                              _activeSpaceName.length > 8
                                  ? '${_activeSpaceName.substring(0, 8)}...'
                                  : _activeSpaceName,
                              style: const TextStyle(
                                color: Color(0xFF6750A4),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 15),
                            child: Icon(
                              _isDropdownOpen
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Inbox button
                  GestureDetector(
                    key: widget.inboxKey,
                    onTap: () {
                      Navigator.pushNamed(context, '/inbox');
                    },
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.chat, color: Color(0xFF6750A4)),
                    ),
                  ),
                ],
              ),
              // Dropdown Content
              if (_isDropdownOpen)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Default "My Space" option
                      ListTile(
                        title: const Text('My Space'),
                        onTap: () {
                          setState(() {
                            _activeSpaceName = 'My Space';
                            _isDropdownOpen = false;
                          });
                          widget.onSpaceSelected(''); // Set activeSpaceId to empty string
                          widget.onMySpaceSelected(); // Notify parent widget
                        },
                      ),
                      // Other spaces
                      ..._spaces.map((space) {
                        return ListTile(
                          title: Text(space['name']),
                          onTap: () => _selectSpace(space['id'], space['name']),
                        );
                      }),
                    ],
                  ),
                ),
              // Horizontally Scrollable List of Categories
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      CategoryItem(
                        title: 'Hotel',
                        icon: Icons.hotel,
                        onCategorySelected: widget.onCategorySelected,
                      ),
                      CategoryItem(
                        title: 'Restaurant',
                        icon: Icons.restaurant,
                        onCategorySelected: widget.onCategorySelected,
                      ),
                      CategoryItem(
                        title: 'Bus',
                        icon: Icons.directions_bus,
                        onCategorySelected: widget.onCategorySelected,
                      ),
                      CategoryItem(
                        title: 'Shopping',
                        icon: Icons.shop_2,
                        onCategorySelected: widget.onCategorySelected,
                      ),
                      CategoryItem(
                        title: 'Groceries',
                        icon: Icons.shopping_cart,
                        onCategorySelected: widget.onCategorySelected,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}