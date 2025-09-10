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
  final DateTime expiresAt;
  final bool isSpaceMember;

  // optional inputs
  final bool? isPending; // if caller already computed pending state
  final String? requestId; // optional chat_requests doc id

  const VerificationCodeBubble({
    super.key,
    required this.spaceId,
    required this.verificationCode,
    required this.codeTimestamp,
    required this.expiresAt,
    required this.isSpaceMember,
    this.isPending,
    this.requestId,
  });

  @override
  _VerificationCodeBubbleState createState() => _VerificationCodeBubbleState();
}

class _VerificationCodeBubbleState extends State<VerificationCodeBubble> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();

  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool _isExpired = false;
  bool _isJoining = false;
  bool _hasJoined = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _requestSubscription;
  String? _requestStatus; // "pending"/"accepted"/"rejected" or null

  @override
  void initState() {
    super.initState();
    _startTimer();
    _checkIfUserHasJoined();

    // initialize _requestStatus from passed isPending (fallback)
    if (widget.isPending != null) {
      _requestStatus = widget.isPending! ? 'pending' : null;
    }

    // if requestId provided, subscribe to its live updates (overrides isPending)
    _subscribeToRequestDocIfNeeded();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _requestSubscription?.cancel();
    super.dispose();
  }

  void _startTimer() {
    final now = DateTime.now();
    if (now.isAfter(widget.expiresAt)) {
      setState(() {
        _isExpired = true;
        _remainingTime = Duration.zero;
      });
      return;
    }

    _remainingTime = widget.expiresAt.difference(now);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final diff = widget.expiresAt.difference(DateTime.now());
      if (diff.isNegative) {
        setState(() {
          _isExpired = true;
          _remainingTime = Duration.zero;
        });
        timer.cancel();
      } else {
        if (mounted) {
          setState(() {
            _remainingTime = diff;
          });
        }
      }
    });
  }

  Future<void> _checkIfUserHasJoined() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final joined = await ChatService()
          .isUserSpaceMember(widget.spaceId, currentUser.uid);
      if (!mounted) return;
      setState(() {
        _hasJoined = joined;
      });
      debugPrint(
          'Verification bubble: user joined? $_hasJoined (space ${widget.spaceId})');
    } catch (e) {
      debugPrint('Error checking if user has joined via service: $e');
    }
  }

  void _subscribeToRequestDocIfNeeded() {
    final rid = widget.requestId;
    if (rid == null || rid.isEmpty) return;

    final docRef = _firestore.collection('chat_requests').doc(rid);

    _requestSubscription = docRef.snapshots().listen(
        (DocumentSnapshot<Map<String, dynamic>> snap) {
      if (!mounted) return;

      if (!snap.exists) {
        setState(() => _requestStatus = null);
        return;
      }

      final data = snap.data() ?? <String, dynamic>{};
      final status = (data['status'] as String?)?.toLowerCase();
      setState(() {
        _requestStatus = status;
      });

      if (status == 'accepted') {
        setState(() {
          _hasJoined = true;
        });
      }
    }, onError: (e) {
      debugPrint('Error listening to request doc: $e');
    });
  }

  Future<void> _handleJoinPressed() async {
    if (_isJoining || _isExpired || _hasJoined || widget.isSpaceMember) return;

    // If a request doc exists and its status is not pending, don't join
    if (widget.requestId != null &&
        widget.requestId!.isNotEmpty &&
        _requestStatus != null &&
        _requestStatus != 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This invitation is no longer pending.')),
      );
      return;
    }

    setState(() => _isJoining = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('login_required'.tr())),
        );
        return;
      }

      if (widget.requestId != null && widget.requestId!.isNotEmpty) {
        // accept through chat_requests doc so backend creates chat room and marks request accepted
        await _chatService.acceptChatRequest(widget.requestId!);
      } else {
        // fallback: directly add to Spaces (no chat_request document)
        await _firestore.collection('Spaces').doc(widget.spaceId).update({
          'members': FieldValue.arrayUnion([user.uid]),
        });
      }

      // ensure space chat room membership and related setup
      await _chatService.addMemberToSpaceChatRoom(widget.spaceId, user.uid);

      if (!mounted) return;
      setState(() {
        _hasJoined = true;
        _requestStatus = 'accepted';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('joined_space_successfully'.tr())),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_joining_space'.tr())),
        );
      }
      debugPrint('Error joining space: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false);
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
    final bool isMember = widget.isSpaceMember || _hasJoined;
    final bool requestExists =
        widget.requestId != null && widget.requestId!.isNotEmpty;

    // if request exists, treat pending only when _requestStatus == 'pending'
    // otherwise fallback to widget.isPending (if provided) or assume pending
    final bool requestPending = requestExists
        ? (_requestStatus == 'pending')
        : (widget.isPending ?? true);

    final bool canJoin =
        !isExpired && !isMember && (!requestExists || requestPending);
    final bool showTimer = !isExpired && !isMember;

    // status string
    String statusText;
    if (isExpired) {
      statusText = 'Expired';
    } else if (isMember) {
      statusText = 'Already joined this space';
    } else if (requestExists && _requestStatus != null) {
      if (_requestStatus == 'pending')
        statusText = 'Invitation pending';
      else if (_requestStatus == 'accepted')
        statusText = 'Invitation accepted';
      else if (_requestStatus == 'rejected')
        statusText = 'Invitation declined';
      else
        statusText = 'Invitation: ${_requestStatus}';
    } else {
      // no request doc; rely on passed isPending or assume pending
      statusText = (widget.isPending == false)
          ? 'No active invitation'
          : 'Invitation pending';
    }

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
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'DBG: requestId=${widget.requestId ?? 'null'} status=${_requestStatus ?? (widget.isPending == true ? 'pending(fallback)' : 'null')} '
              'isSpaceMember=${widget.isSpaceMember} hasJoined=${_hasJoined} expires=${widget.expiresAt.toIso8601String()}',
              style: const TextStyle(fontSize: 10),
            ),
          ),
          const Text(
            'Space Invitation',
            style: TextStyle(
              fontWeight: FontWeight.bold,
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
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (isExpired)
            const Text(
              'Expired',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (isMember)
            const Text(
              'Already joined this space',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (!isMember && !isExpired)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                statusText,
                style: TextStyle(
                  color: (_requestStatus == 'rejected')
                      ? Colors.red
                      : (_requestStatus == 'accepted' || isMember)
                          ? Colors.green
                          : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (canJoin)
            ElevatedButton(
              onPressed: _isJoining ? null : _handleJoinPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
              ),
              child: _isJoining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
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
