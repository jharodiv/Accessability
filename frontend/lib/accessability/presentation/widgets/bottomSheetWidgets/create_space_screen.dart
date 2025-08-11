import 'dart:math';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';

class CreateSpaceScreen extends StatefulWidget {
  const CreateSpaceScreen({super.key});

  @override
  _CreateSpacePageState createState() => _CreateSpacePageState();
}

class _CreateSpacePageState extends State<CreateSpaceScreen> {
  final TextEditingController _spaceNameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  bool _isLoading = false;

  @override
  void dispose() {
    _spaceNameController.dispose();
    super.dispose();
  }

  Future<void> _createSpace() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final spaceName = _spaceNameController.text.trim();
    if (spaceName.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final verificationCode = _generateVerificationCode();
      final spaceRef = await _firestore.collection('Spaces').add({
        'name': spaceName,
        'creator': user.uid,
        'members': [user.uid],
        'verificationCode': verificationCode,
        'codeTimestamp': DateTime.now(),
        'createdAt': DateTime.now(),
      });

      await _chatService.createSpaceChatRoom(spaceRef.id, spaceName);

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating space: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Space'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _spaceNameController,
              decoration: InputDecoration(
                labelText: 'space_name'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _createSpace,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text('create'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
