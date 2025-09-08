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
  State<VerificationRequestScreen> createState() =>
      _VerificationRequestScreenState();
}

class _VerificationRequestScreenState extends State<VerificationRequestScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  bool _isLoading = false;
  bool _isExpired = false;

  static const Color purple = Color(0xFF6750A4);

  @override
  void initState() {
    super.initState();
    _checkExpiration();
  }

  void _checkExpiration() {
    if (DateTime.now().isAfter(widget.expiresAt)) {
      setState(() => _isExpired = true);
    }
  }

  Future<void> _acceptVerification() async {
    if (_isExpired) return;
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _chatService.acceptChatRequest(widget.requestId);

      await _firestore.collection('Spaces').doc(widget.spaceId).update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      await _chatService.addMemberToSpaceChatRoom(widget.spaceId, user.uid);

      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting invitation: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectVerification() async {
    await _chatService.rejectChatRequest(widget.requestId);
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                offset: const Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: purple),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Space Invitation',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card with invitation details
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "You've been invited to join:",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.spaceName,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: purple),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.verified, color: purple, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          "Code: ${widget.verificationCode}",
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.timer, color: purple, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          "Expires: ${DateFormat('MMM d, h:mm a').format(widget.expiresAt)}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              if (_isExpired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'This invitation has expired',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ? null : () => _acceptVerification(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Join Space',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed:
                            _isLoading ? null : () => _rejectVerification(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: purple, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: purple),
                        ),
                      ),
                    ),
                  ],
                ),

              SizedBox(height: bottomSafe + 10),
            ],
          ),
        ),
      ),
    );
  }
}
