import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/accessability/firebaseServices/chat/chat_service.dart'; // Import your ChatService

class BottomWidgets extends StatefulWidget {
  final ScrollController scrollController;
  final String activeSpaceId;
  final Key? key;

  const BottomWidgets({
    this.key,
    required this.scrollController,
    required this.activeSpaceId,
  }) : super(key: key);

  @override
  _BottomWidgetsState createState() => _BottomWidgetsState();
}

class _BottomWidgetsState extends State<BottomWidgets> {
  int _activeIndex = 0; // 0: People, 1: Buildings, 2: Map
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService(); // Initialize ChatService
  List<Map<String, dynamic>> _members = []; // List of members in the space
  String? _creatorId; // ID of the space creator

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  @override
  void didUpdateWidget(BottomWidgets oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeSpaceId != oldWidget.activeSpaceId) {
      _fetchMembers(); // Fetch members for the new space
    }
  }

  // Fetch members in the active space
  Future<void> _fetchMembers() async {
    if (widget.activeSpaceId.isEmpty) return;

    final snapshot =
        await _firestore.collection('Spaces').doc(widget.activeSpaceId).get();
    final members = List<String>.from(snapshot['members']);
    final creatorId = snapshot['creator'];

    final usersSnapshot = await _firestore
        .collection('Users')
        .where('uid', whereIn: members)
        .get();

    setState(() {
      _members = usersSnapshot.docs.map((doc) {
        return {
          'uid': doc['uid'],
          'username': doc['username'],
        };
      }).toList();
      _creatorId = creatorId;
    });
  }

  // Add a person to the space
  Future<void> _addPerson() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final email = await _showAddPersonDialog();
    if (email == null || email.isEmpty) return;

    // Fetch the receiver's user ID from Firestore
    final receiverSnapshot = await _firestore
        .collection('Users')
        .where('email', isEqualTo: email)
        .get();

    if (receiverSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
      return;
    }

    final receiverID = receiverSnapshot.docs.first.id;

    // Generate a random verification code
    final verificationCode = _generateVerificationCode();

    // Send the verification code via chat
    await _chatService.sendMessage(
      receiverID,
      'Join My Space! \n Your verification code is: $verificationCode (Expires in 10 minutes)',
    );

    // Update the space with the verification code
    await _firestore.collection('Spaces').doc(widget.activeSpaceId).update({
      'verificationCode': verificationCode,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification code sent via chat')),
    );
  }

  // Generate a random 6-digit verification code
  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Show a dialog to add a person
  Future<String?> _showAddPersonDialog() async {
    String? email;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Person'),
          content: TextField(
            decoration: const InputDecoration(labelText: 'Email'),
            onChanged: (value) => email = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    return email;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.8,
      builder: (BuildContext context, ScrollController scrollController) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildServiceButton(Icons.check_circle, 'Check-in'),
                _buildServiceButton(Icons.warning, 'SOS'),
                _buildServiceButton(Icons.accessibility, 'PWD'),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
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
                        Container(
                          width: 100, // Adjust width as needed
                          height: 2, // Thin line
                          color: Colors.grey.shade700, // Dark grey color
                          margin: const EdgeInsets.only(
                              bottom: 8), // Space below the line
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: 50, // Adjust height
                          decoration: BoxDecoration(
                            color:
                                Colors.grey.shade200, // Light gray background
                            borderRadius:
                                BorderRadius.circular(25), // Rounded edges
                          ),
                          child: const Row(
                            children: [
                              // Placeholder text
                              Expanded(
                                child: Text(
                                  "Text to Speech, Speech to Text",
                                  style: TextStyle(
                                    color: Color(0xFF6750A4), // Updated color
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              // Microphone icon
                              Icon(
                                Icons.mic, // Microphone icon
                                color: Color(0xFF6750A4), // Updated color
                              ),
                            ],
                          ),
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
                        if (_creatorId ==
                            _auth.currentUser?.uid) // Only show if creator
                          ElevatedButton(
                            onPressed: _addPerson,
                            child: const Text('Add Person'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServiceButton(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        // You can add functionality here later if needed
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          children: [
            Icon(
              icon,
              color: const Color(0xFF6750A4),
              size: 18, // Reduced icon size
            ),
            const SizedBox(width: 5), // Space between icon and text
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6750A4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
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
          children: _members
              .where((member) =>
                  member['uid'] !=
                  _auth.currentUser?.uid) // Exclude current user
              .map((member) => ListTile(
                    title: Text(member['username']),
                    trailing: IconButton(
                      icon: const Icon(Icons.chat),
                      onPressed: () {
                        // Navigate to chat with the member
                        Navigator.pushNamed(
                          context,
                          '/chatconvo',
                          arguments: {
                            'receiverEmail': member['username'],
                            'receiverID': member['uid'],
                          },
                        );
                      },
                    ),
                  ))
              .toList(),
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
