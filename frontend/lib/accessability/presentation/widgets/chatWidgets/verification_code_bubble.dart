import 'dart:async';
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class VerificationCodeBubble extends StatefulWidget {
  final String spaceId;
  final String verificationCode;
  final DateTime codeTimestamp;
  final DateTime expiresAt; // Add expiresAt parameter
  final bool isSpaceMember;

  const VerificationCodeBubble({
    super.key,
    required this.spaceId,
    required this.verificationCode,
    required this.codeTimestamp,
    required this.expiresAt, // Add this parameter
    required this.isSpaceMember,
  });

  @override
  _VerificationCodeBubbleState createState() => _VerificationCodeBubbleState();
}

class _VerificationCodeBubbleState extends State<VerificationCodeBubble> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool _isExpired = false;
  bool _isJoining = false;
  bool _hasJoined = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _checkIfUserHasJoined();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    final now = DateTime.now();

    if (now.isAfter(widget.expiresAt)) {
      setState(() {
        _isExpired = true;
      });
      return;
    }

    _remainingTime = widget.expiresAt.difference(now);

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _remainingTime = widget.expiresAt.difference(DateTime.now());
        if (_remainingTime.isNegative) {
          _isExpired = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _checkIfUserHasJoined() async {
    try {
      final spaceDoc =
          await _firestore.collection('Spaces').doc(widget.spaceId).get();
      if (spaceDoc.exists) {
        final members = List<String>.from(spaceDoc['members'] ?? []);
        final currentUserId = _auth.currentUser?.uid;

        if (currentUserId != null && members.contains(currentUserId)) {
          setState(() {
            _hasJoined = true;
          });
        }
      }
    } catch (e) {
      print('Error checking if user has joined: $e');
    }
  }

  Future<void> _joinSpace() async {
    if (_isJoining || _isExpired || _hasJoined) return;

    setState(() {
      _isJoining = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('login_required'.tr())),
        );
        return;
      }

      // Add user to space
      await _firestore.collection('Spaces').doc(widget.spaceId).update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      // Add user to space chat room
      final chatService = ChatService();
      await chatService.addMemberToSpaceChatRoom(widget.spaceId, user.uid);

      setState(() {
        _hasJoined = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('joined_space_successfully'.tr())),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_joining_space'.tr())),
      );
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isExpired = _isExpired;
    final bool canJoin = !isExpired && !_hasJoined && !widget.isSpaceMember;
    final bool showTimer = !isExpired && !_hasJoined;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired ? Colors.grey : Colors.green,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Space Invitation',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isExpired ? Colors.grey : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Verification Code: ${widget.verificationCode}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isExpired ? Colors.grey : Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          if (showTimer)
            Text(
              'Expires in: ${_formatDuration(_remainingTime)}',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (isExpired)
            Text(
              'Expired',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (_hasJoined)
            Text(
              'Already joined this space',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 12),
          if (canJoin)
            ElevatedButton(
              onPressed: _isJoining ? null : _joinSpace,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 40),
              ),
              child: _isJoining
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check, size: 18),
                        SizedBox(width: 8),
                        Text('Join Space'),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
