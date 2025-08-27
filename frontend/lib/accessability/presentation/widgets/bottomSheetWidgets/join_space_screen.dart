import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'dart:math' as math;

class JoinSpaceScreen extends StatefulWidget {
  const JoinSpaceScreen({super.key});

  @override
  _JoinSpaceScreenState createState() => _JoinSpaceScreenState();
}

class _JoinSpaceScreenState extends State<JoinSpaceScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  bool _isLoading = false;
  bool _isDisposed = false;
  bool _navigationCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) FocusScope.of(context).requestFocus(_focusNodes[0]);
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  bool get _isCodeComplete =>
      _controllers.every((c) => c.text.trim().isNotEmpty);

  Future<void> _joinSpace() async {
    if (_isLoading || _isDisposed || _navigationCompleted) return;

    final user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('login_required'.tr());
      return;
    }

    final verificationCode = _controllers.map((c) => c.text).join();
    if (verificationCode.length != 6) {
      _showSnackBar('complete_verification_code'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final snapshot = await _firestore
          .collection('Spaces')
          .where('verificationCode', isEqualTo: verificationCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _showSnackBar('invalid_verification_code'.tr());
        return;
      }

      final spaceDoc = snapshot.docs.first;
      final spaceId = spaceDoc.id;
      final codeTimestamp = spaceDoc['codeTimestamp']?.toDate();

      if (codeTimestamp != null &&
          DateTime.now().difference(codeTimestamp).inMinutes > 10) {
        _showSnackBar('verification_code_expired'.tr());
        return;
      }

      // Check if user is already a member
      final currentMembers = List<String>.from(spaceDoc['members'] ?? []);

      if (!currentMembers.contains(user.uid)) {
        // Add user to space
        await _firestore.collection('Spaces').doc(spaceId).update({
          'members': FieldValue.arrayUnion([user.uid]),
        });
      }

      // Always add to space chat room (handles re-joining case)
      await _chatService.addMemberToSpaceChatRoom(spaceId, user.uid);

      _showSnackBar('joined_space_successfully'.tr());

      _navigationCompleted = true;

      Future.microtask(() {
        if (!_isDisposed && Navigator.canPop(context)) {
          Navigator.of(context).pop({
            'success': true,
            'spaceId': spaceId,
            'spaceName': spaceDoc['name']
          });
        }
      });
    } catch (e) {
      if (!_isDisposed) {
        _showSnackBar('error_joining_space'.tr(args: [e.toString()]));
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

    _navigationCompleted = true;

    Future.microtask(() {
      if (!_isDisposed) {
        Navigator.of(context).pop({'success': false});
      }
    });
  }

  /// Build a constrained code box. We **do not** force a fixed width here —
  /// the parent Row uses Flexible so the layout can shrink on small screens.
  Widget _buildCodeBox(int index) {
    final filled = _controllers[index].text.isNotEmpty;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 40, maxWidth: 64),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          maxLength: 1,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: filled ? const Color(0xFFEDE1F9) : Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: filled ? Colors.transparent : const Color(0xFFE8E5EA),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          onChanged: (value) {
            if (_isDisposed) return;
            setState(() {}); // update fill & button enabled state
            if (value.isNotEmpty && index < 5) {
              FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
            } else if (value.isEmpty && index > 0) {
              FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar with shadow like your SettingsScreen, title left-aligned
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              // subtle shadow to match your design
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
              'Join a Space',
              style: TextStyle(
                  color: Color(0xFF2E1750), fontWeight: FontWeight.w600),
            ),
            centerTitle: false, // <-- left-align the title
            // optional: adjust title spacing if you'd like it closer/further from the leading icon
            // titleSpacing: 0,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top:
                24, // increased top gap so "Enter the invite code" sits a little lower
            bottom: math.max(16, MediaQuery.of(context).viewInsets.bottom),
          ),
          child: Column(
            children: [
              // removed the extra SizedBox here since padding.top now provides the spacing
              const Text(
                'Enter the invite code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                  color: Color(0xFF2E1750),
                ),
              ).tr(),
              const SizedBox(height: 18),
              const Text(
                'Get the code from the person setting up your family\'s Space',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8E8E93),
                ),
              ).tr(),
              const SizedBox(height: 30),

              // Flexible, constrained boxes to avoid overflow on narrow screens.
              LayoutBuilder(builder: (context, constraints) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // left three boxes
                    for (int i = 0; i < 3; i++)
                      Flexible(flex: 1, child: _buildCodeBox(i)),
                    const SizedBox(width: 8),
                    const Text('-',
                        style:
                            TextStyle(fontSize: 22, color: Color(0xFF9A8FB6))),
                    const SizedBox(width: 8),
                    // right three boxes
                    for (int i = 3; i < 6; i++)
                      Flexible(flex: 1, child: _buildCodeBox(i)),
                  ],
                );
              }),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 62,
                child: ElevatedButton(
                  onPressed:
                      (_isLoading || !_isCodeComplete) ? null : _joinSpace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    disabledBackgroundColor: const Color(0xFFF1E7F9),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF9A8FB6),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                      : const Text(
                          'Submit',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ).tr(),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                  height: 100), // keep the lower area empty like your design
            ],
          ),
        ),
      ),
    );
  }
}
