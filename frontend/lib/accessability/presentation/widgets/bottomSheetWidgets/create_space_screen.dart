import 'dart:math';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';

class CreateSpaceScreen extends StatefulWidget {
  const CreateSpaceScreen({super.key});

  @override
  _CreateSpaceScreenState createState() => _CreateSpaceScreenState();
}

class _CreateSpaceScreenState extends State<CreateSpaceScreen> {
  final TextEditingController _spaceNameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  bool _isLoading = false;
  final FocusNode _nameFocusNode = FocusNode();
  bool _isDisposed = false;
  bool _navigationCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) FocusScope.of(context).requestFocus(_nameFocusNode);
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _spaceNameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _createSpace() async {
    if (_isLoading || _isDisposed || _navigationCompleted) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final spaceName = _spaceNameController.text.trim();
    if (spaceName.isEmpty) {
      _showSnackBar('space_name_required'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final verificationCode = _generateVerificationCode();
      final now = Timestamp.now();

      // Create space document
      final spaceRef = await _firestore.collection('Spaces').add({
        'name': spaceName,
        'creator': user.uid,
        'members': [user.uid],
        'verificationCode': verificationCode,
        'codeTimestamp': now,
        'createdAt': now,
      });

      // Create chat room
      await _chatService.createSpaceChatRoom(spaceRef.id, spaceName);

      _showSnackBar('space_created_successfully'.tr());

      // Mark navigation as completed
      _navigationCompleted = true;

      // Use a microtask to ensure safe navigation
      Future.microtask(() {
        if (!_isDisposed && Navigator.canPop(context)) {
          Navigator.of(context).pop({'success': true, 'spaceId': spaceRef.id});
        }
      });
    } catch (e) {
      if (!_isDisposed) {
        _showSnackBar('error_creating_space'.tr(args: [e.toString()]));
      }
    } finally {
      if (!_isDisposed && !_navigationCompleted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (_isDisposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _safePop() {
    if (_isLoading ||
        _isDisposed ||
        _navigationCompleted ||
        !Navigator.canPop(context)) return;

    // Mark navigation as completed
    _navigationCompleted = true;

    // Use a microtask to ensure safe navigation
    Future.microtask(() {
      if (!_isDisposed) {
        Navigator.of(context).pop({'success': false});
      }
    });
  }

  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Space').tr(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _safePop,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create My Space',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ).tr(),
            const SizedBox(height: 20),
            TextField(
              controller: _spaceNameController,
              focusNode: _nameFocusNode,
              decoration: InputDecoration(
                labelText: 'Space Name'.tr(),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _createSpace(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createSpace,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6750A4),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create').tr(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _safePop,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6750A4)),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Back').tr(),
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
