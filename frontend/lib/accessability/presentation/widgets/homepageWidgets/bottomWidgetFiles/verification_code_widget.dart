// verification_code_screen.dart
import 'dart:math';

import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerificationCodeScreen extends StatefulWidget {
  final String spaceId;
  final String? spaceName; // <-- new optional parameter

  const VerificationCodeScreen({
    super.key,
    required this.spaceId,
    this.spaceName,
  });

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();

  String? _verificationCode;
  bool _isLoading = false;

  // change this if you want a different validity duration
  final Duration codeValidityDuration = const Duration(hours: 48);

  @override
  void initState() {
    super.initState();
    _ensureCode();
  }

  Future<void> _ensureCode() async {
    setState(() => _isLoading = true);

    try {
      final docSnap =
          await _firestore.collection('Spaces').doc(widget.spaceId).get();
      if (!docSnap.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Space not found')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final data = docSnap.data() ?? {};
      final existing = data['verificationCode'];
      final rawTs = data['codeTimestamp'];

      DateTime? ts;
      if (rawTs is Timestamp)
        ts = rawTs.toDate();
      else if (rawTs is int)
        ts = DateTime.fromMillisecondsSinceEpoch(rawTs);
      else if (rawTs is DateTime) ts = rawTs;

      final now = DateTime.now();
      if (existing != null &&
          ts != null &&
          now.difference(ts) < codeValidityDuration) {
        _verificationCode = existing.toString();
      } else {
        _verificationCode = _generateVerificationCode();
        await _firestore.collection('Spaces').doc(widget.spaceId).update({
          'verificationCode': _verificationCode,
          'codeTimestamp': DateTime.now(),
        });
      }
    } catch (e) {
      debugPrint('Error ensuring code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _generateVerificationCode() {
    // 6-digit numeric code, displayed as AAA-BBB to match screenshot's hyphen style.
    final rand = Random();
    final code = (100000 + rand.nextInt(900000)).toString();
    return code;
  }

  String _displayFormattedCode(String? raw) {
    if (raw == null) return '— — — — — —';
    if (raw.length == 6) return '${raw.substring(0, 3)}-${raw.substring(3)}';
    return raw;
  }

  String _formatValidityText() {
    final hrs = codeValidityDuration.inHours;
    if (hrs % 24 == 0) {
      final days = hrs ~/ 24;
      return '$days ${days == 1 ? "day" : "days"}';
    } else {
      return '$hrs ${hrs == 1 ? "hour" : "hours"}';
    }
  }

  Future<String?> _showEmailInputDialog() async {
    String? email;
    await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Send Code'),
          content: TextField(
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            onChanged: (v) => email = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(email),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    return email;
  }

  Future<void> _shareCode() async {
    // This action uses the existing chat service logic you provided.
    // It asks for an email to lookup a user and sends the code via in-app chat.
    if (_verificationCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No verification code available')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in')),
      );
      return;
    }

    final email = await _showEmailInputDialog();
    if (email == null || email.trim().isEmpty) return;

    if (email.trim() == user.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot send the code to yourself')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final receiverSnapshot = await _firestore
          .collection('Users')
          .where('email', isEqualTo: email.trim())
          .get();

      if (receiverSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
        return;
      }

      final receiverId = receiverSnapshot.docs.first.id;

      final hasChatRoom = await _chatService.hasChatRoom(user.uid, receiverId);
      final codeDisplay = _displayFormattedCode(_verificationCode);
      final message =
          'Join My Space!\nVerification code: $codeDisplay\nExpires in ${_formatValidityText()}';

      if (!hasChatRoom) {
        await _chatService.sendChatRequest(receiverId, message);
      } else {
        await _chatService.sendMessage(receiverId, message);
      }

      // Make sure space doc has current code/timestamp
      await _firestore.collection('Spaces').doc(widget.spaceId).update({
        'verificationCode': _verificationCode,
        'codeTimestamp': DateTime.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code sent via chat')),
        );
      }
    } catch (e) {
      debugPrint('send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildBody() {
    // choose display name — if widget.spaceName provided use it; else fallback to generic 'Space'
    final displayName = (widget.spaceName?.trim().isNotEmpty ?? false)
        ? widget.spaceName!.trim()
        : 'Space';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // left align texts
      children: [
        const SizedBox(height: 12), // more breathing room from top
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: Text(
            'Invite members to the $displayName Space',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E1750),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(
            height: 20), // increased spacing between title & subtitle
        const Padding(
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: Text(
            'Share your code out loud or send it in a message',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 15, color: Color(0xFF7A6E9A), height: 1.4),
          ),
        ),
        const SizedBox(height: 25), // more space before the purple card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: const Color(
                0xFFF1E9FF), // subtle purple background like screenshot
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              if (_isLoading)
                const SizedBox(
                    height: 72,
                    child: Center(child: CircularProgressIndicator()))
              else ...[
                Text(
                  _displayFormattedCode(_verificationCode),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6750A4),
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'This code will be active for ${_formatValidityText()}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF2E1750),
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6750A4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _isLoading ? null : _shareCode,
                    child: const Text(
                      'Share Code',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                // "Regenerate code" removed as requested
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    void _safePop() {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    }

    return Scaffold(
      // AppBar styled to match the provided design
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF2E1750),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4),
              onPressed: _safePop,
            ),
            title: const Text(
              'Invite Code',
              style: TextStyle(
                  color: Color(0xFF2E1750), fontWeight: FontWeight.w600),
            ),
            centerTitle: false,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: _buildBody(),
        ),
      ),
    );
  }
}
