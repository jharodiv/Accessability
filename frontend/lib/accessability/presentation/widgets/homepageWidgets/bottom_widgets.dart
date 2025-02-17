import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BottomWidgets extends StatefulWidget {
  final ScrollController scrollController;

  const BottomWidgets({Key? key, required this.scrollController}) : super(key: key);

  @override
  _BottomWidgetsState createState() => _BottomWidgetsState();
}

class _BottomWidgetsState extends State<BottomWidgets> {
  int _activeIndex = 0; // 0: People, 1: Buildings, 2: Map
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _members = []; // List of members in the space

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  // Fetch members in the current space
  Future<void> _fetchMembers() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore.collection('Spaces').where('members', arrayContains: user.uid).get();
    if (snapshot.docs.isNotEmpty) {
      final spaceId = snapshot.docs.first.id;
      final spaceSnapshot = await _firestore.collection('Spaces').doc(spaceId).get();
      setState(() {
        _members = List<String>.from(spaceSnapshot['members']);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.1,
      minChildSize: 0.1,
      maxChildSize: 0.8,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Search Location",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                    ),
                    onChanged: (value) {
                      // Handle search logic here
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildButton(Icons.people, 0),
                      _buildButton(Icons.business, 1),
                      _buildButton(Icons.map, 2),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildContent(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButton(IconData icon, int index) {
    bool isActive = _activeIndex == index;
    return SizedBox(
      width: 100,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _activeIndex = index;
          });
        },
        child: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFF6750A4),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? const Color(0xFF6750A4) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_activeIndex) {
      case 0:
        return Column(
          children: _members.map((member) => ListTile(
            title: Text(member),
          )).toList(),
        );
      case 1:
        return const Text("Buildings Content");
      case 2:
        return const Text("Map Content");
      default:
        return const SizedBox.shrink();
    }
  }
}