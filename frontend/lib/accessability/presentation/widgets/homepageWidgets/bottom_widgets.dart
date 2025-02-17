import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/accessability/firebaseServices/chat/chat_service.dart'; // Import your ChatService

class BottomWidgets extends StatefulWidget {
  final ScrollController scrollController;
  final String activeSpaceId;

  const BottomWidgets({
    Key? key,
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
  List<String> _members = []; // List of members in the space

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  // Fetch members in the active space
  Future<void> _fetchMembers() async {
    if (widget.activeSpaceId.isEmpty) return;

    final snapshot = await _firestore.collection('Spaces').doc(widget.activeSpaceId).get();
    setState(() {
      _members = List<String>.from(snapshot['members']);
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
      'Your verification code is: $verificationCode (Expires in 10 minutes)',
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
                  if (widget.activeSpaceId.isNotEmpty)
                    ElevatedButton(
                      onPressed: _addPerson,
                      child: const Text('Add Person'),
                    ),
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