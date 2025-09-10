import 'dart:async';
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

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

  /// Helper for a slightly friendlier description below the chip.
  @override
  Widget build(BuildContext context) {
    final bool isMember = widget.isSpaceMember || _hasJoined;
    final bool requestExists =
        widget.requestId != null && widget.requestId!.isNotEmpty;

    // Request status from live subscription (may be null until loaded)
    final String? rawReqStatus = _requestStatus?.toLowerCase();
    final bool reqStatusKnown = rawReqStatus != null;

    final bool isPending = requestExists
        ? (!reqStatusKnown ? true : rawReqStatus == 'pending')
        : (widget.isPending == true);
    final bool isAccepted = requestExists && rawReqStatus == 'accepted';
    final bool isRejected = requestExists && rawReqStatus == 'rejected';

    // determine expired (timer-driven)
    final bool isExpired = _isExpired;

    // STATUS TEXT & chip-data logic
    String statusText;
    IconData statusIcon = Icons.hourglass_top;
    Color statusColor = Colors.amber.shade700;

    // Priority logic:
    // 1) If user is already member -> green "Already joined this space"
    // 2) Else if expired -> red "Invitation expired"
    // 3) Else evaluate request doc status (accepted/pending/rejected) or fallback
    if (isMember) {
      statusText = 'Already joined this space';
      statusIcon = Icons.check_circle;
      statusColor = Colors.green.shade600;
    } else if (isExpired) {
      statusText = 'Invitation expired';
      statusIcon = Icons.error_outline;
      statusColor = Colors.red.shade600;
    } else {
      // not member and not expired -> show request status
      if (requestExists) {
        if (isAccepted) {
          statusText = 'Invitation accepted';
          statusIcon = Icons.check_circle;
          statusColor = Colors.green.shade600;
        } else if (isRejected) {
          statusText = 'Invitation declined';
          statusIcon = Icons.cancel;
          statusColor = Colors.red.shade600;
        } else {
          statusText = 'Invitation pending';
          statusIcon = Icons.hourglass_top;
          statusColor = Colors.amber.shade700;
        }
      } else {
        // no request doc -> fallback to passed flag or treat as pending
        if (widget.isPending == true) {
          statusText = 'Invitation pending';
          statusIcon = Icons.hourglass_top;
          statusColor = Colors.amber.shade700;
        } else {
          statusText = 'Invitation pending';
          statusIcon = Icons.hourglass_top;
          statusColor = Colors.amber.shade700;
        }
      }
    }

    // Button visibility:
    // Only allow Join when:
    // - NOT expired
    // - NOT a member
    // - request is pending (or no request doc)
    final bool canJoin =
        !isExpired && !isMember && (!requestExists || isPending);
    final bool showTimer = !isExpired && !isMember;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Material(
            color: Colors.white, // white background as requested
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            shadowColor: Colors.black.withOpacity(0.08),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18.0, vertical: 18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F1FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.vpn_key,
                                color: Color(0xFF6750A4), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Space Invitation',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E1750),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Verification code to join the space',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Expires / Expired row (above the status chip)
                      Row(
                        children: [
                          if (showTimer) ...[
                            const Icon(Icons.timer,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              'Expires in: ${_formatDuration(_remainingTime)}',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                          if (isExpired && !isMember) ...[
                            const Icon(Icons.error_outline,
                                size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('Expired',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600)),
                          ],
                          const Spacer(),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Status chip ABOVE the code pill (centered)
                      Center(
                        child: Chip(
                          avatar:
                              Icon(statusIcon, size: 18, color: Colors.white),
                          label: Text(statusText,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          backgroundColor: statusColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // big code pill
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Text(
                            widget.verificationCode.length == 6
                                ? '${widget.verificationCode.substring(0, 3)}-${widget.verificationCode.substring(3)}'
                                : widget.verificationCode,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6750A4),
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // description under divider
                      Text(
                        _composeStatusDescription(
                          statusText,
                          isMember: isMember,
                          isExpired: isExpired,
                          isAccepted: isAccepted,
                          isRejected: isRejected,
                        ),
                        style: TextStyle(
                          color: isRejected
                              ? Colors.red.shade600
                              : (isAccepted || isMember
                                  ? Colors.green.shade700
                                  : Colors.grey.shade800),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // CTA
                      if (canJoin)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isJoining ? null : _handleJoinPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6750A4),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                            child: _isJoining
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Join Space',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              isMember
                                  ? 'You are a member'
                                  : (isExpired
                                      ? 'Invitation expired'
                                      : 'Not available'),
                              style: TextStyle(
                                  fontSize: 14,
                                  color: isExpired
                                      ? Colors.red.shade600
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // top-right copy icon only when NOT expired
                if (!isExpired)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      icon: Icon(Icons.copy, color: Colors.grey.shade600),
                      tooltip: 'Copy code',
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.verificationCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied')));
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// helper already referenced above
String _composeStatusDescription(
  String base, {
  required bool isMember,
  required bool isExpired,
  required bool isAccepted,
  required bool isRejected,
}) {
  if (isAccepted || isMember) return 'You are already a member of this space.';
  if (isRejected) return 'This invitation was declined.';
  if (isExpired)
    return 'This invitation has expired and can no longer be used.';
  return 'This invitation is pending — tap Join Space to accept it.';
}
