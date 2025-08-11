import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';

class JoinSpaceScreen extends StatefulWidget {
  const JoinSpaceScreen({super.key});

  @override
  _JoinSpacePageState createState() => _JoinSpacePageState();
}

class _JoinSpacePageState extends State<JoinSpaceScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _joinSpace() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final verificationCode = _controllers.map((c) => c.text).join();
    if (verificationCode.length != 6) return;

    setState(() => _isLoading = true);

    try {
      final snapshot = await _firestore
          .collection('Spaces')
          .where('verificationCode', isEqualTo: verificationCode)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final spaceId = snapshot.docs.first.id;
        final codeTimestamp = snapshot.docs.first['codeTimestamp']?.toDate();

        if (codeTimestamp != null) {
          final now = DateTime.now();
          final difference = now.difference(codeTimestamp).inMinutes;
          if (difference > 10) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Verification code has expired')),
              );
            }
            return;
          }
        }

        await _firestore.collection('Spaces').doc(spaceId).update({
          'members': FieldValue.arrayUnion([user.uid]),
        });

        await _chatService.addMemberToSpaceChatRoom(spaceId, user.uid);

        if (mounted) {
          Navigator.pop(context, true); // Return success
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid verification code')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining space: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('join_space'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'enter_invite_code'.tr(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  width: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        _focusNodes[index + 1].requestFocus();
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _joinSpace,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text('join'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
