import 'dart:math';

import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  static const Color purple = Color(0xFF6750A4);
  static const Color lightPurple = Color(0xFFD8CFE8);

  @override
  void initState() {
    super.initState();

    // ensure focus opens keyboard on show
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) FocusScope.of(context).requestFocus(_nameFocusNode);
    });

    // rebuild when the space name changes so the create button updates its enabled state & color
    _spaceNameController.addListener(_onSpaceNameChanged);
  }

  void _onSpaceNameChanged() {
    if (!mounted) return;
    // call setState to update button enabled/color
    setState(() {});
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

      final spaceRef = await _firestore.collection('Spaces').add({
        'name': spaceName,
        'creator': user.uid,
        'members': [user.uid],
        'verificationCode': verificationCode,
        'codeTimestamp': now,
        'createdAt': now,
      });

      await _chatService.createSpaceChatRoom(spaceRef.id, spaceName);

      _showSnackBar('space_created_successfully'.tr());
      _navigationCompleted = true;

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
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _safePop() {
    if (_isLoading ||
        _isDisposed ||
        _navigationCompleted ||
        !Navigator.canPop(context)) return;
    _navigationCompleted = true;
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              onPressed: _safePop,
              icon: const Icon(Icons.arrow_back),
              color: purple, // Always purple arrow
            ),
            title: Text(
              'createSpace'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ).tr(),
            centerTitle: true,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'create_my_space',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ).tr(),
            const SizedBox(height: 20),
            TextField(
              controller: _spaceNameController,
              focusNode: _nameFocusNode,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'space_name'.tr(),
                labelStyle: const TextStyle(color: Color(0xFF6750A4)),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: purple),
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: purple),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: purple, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              cursorColor: purple,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _createSpace(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isLoading || _spaceNameController.text.trim().isEmpty
                            ? null
                            : _createSpace,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _spaceNameController.text.trim().isEmpty
                          ? lightPurple
                          : purple,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
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
                        : const Text('create').tr(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _safePop,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: purple),
                      foregroundColor: purple,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('back').tr(),
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
