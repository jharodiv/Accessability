import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:intl/intl.dart';

class VerificationRequestScreen extends StatefulWidget {
  final String requestId;
  final String spaceId;
  final String spaceName;
  final String verificationCode;
  final DateTime expiresAt;
  final String senderID;

  const VerificationRequestScreen({
    super.key,
    required this.requestId,
    required this.spaceId,
    required this.spaceName,
    required this.verificationCode,
    required this.expiresAt,
    required this.senderID,
  });

  @override
  _VerificationRequestScreenState createState() =>
      _VerificationRequestScreenState();
}

class _VerificationRequestScreenState extends State<VerificationRequestScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  bool _isLoading = false;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _checkExpiration();
  }

  void _checkExpiration() {
    if (DateTime.now().isAfter(widget.expiresAt)) {
      setState(() {
        _isExpired = true;
      });
    }
  }

  Future<void> _acceptVerification() async {
    if (_isExpired) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('Accepting verification request: ${widget.requestId}'); // Debug
      print('Space ID: ${widget.spaceId}'); // Debug
      print('User ID: ${user.uid}'); // Debug

      // Accept the chat request (this will create the chat room)
      await _chatService.acceptChatRequest(widget.requestId);

      // Add user to space
      await _firestore.collection('Spaces').doc(widget.spaceId).update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      // Add user to space chat room
      await _chatService.addMemberToSpaceChatRoom(widget.spaceId, user.uid);

      Navigator.of(context).pop(true);
    } catch (e) {
      print('Error details: $e'); // More detailed error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting invitation: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _rejectVerification() async {
    await _chatService.rejectChatRequest(widget.requestId);
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Space Invitation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve been invited to join:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              widget.spaceName,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Verification code: ${widget.verificationCode}'),
            SizedBox(height: 8),
            Text(
                'Expires: ${DateFormat('MMM d, h:mm a').format(widget.expiresAt)}'),
            SizedBox(height: 24),
            if (_isExpired)
              Text(
                'This invitation has expired',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _acceptVerification,
                      child: _isLoading
                          ? CircularProgressIndicator()
                          : Text('Join Space'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _rejectVerification,
                      child: Text('Decline'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
