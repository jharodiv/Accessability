import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';

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
      final codeTimestamp = spaceDoc['codeTimestamp']?.toDate();

      if (codeTimestamp != null &&
          DateTime.now().difference(codeTimestamp).inMinutes > 10) {
        _showSnackBar('verification_code_expired'.tr());
        return;
      }

      await _firestore.collection('Spaces').doc(spaceDoc.id).update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      await _chatService.addMemberToSpaceChatRoom(spaceDoc.id, user.uid);

      _showSnackBar('joined_space_successfully'.tr());

      // Mark navigation as completed
      _navigationCompleted = true;

      // Use a microtask to ensure safe navigation
      Future.microtask(() {
        if (!_isDisposed && Navigator.canPop(context)) {
          Navigator.of(context).pop({
            'success': true,
            'spaceId': spaceDoc.id,
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

    // Mark navigation as completed
    _navigationCompleted = true;

    // Use a microtask to ensure safe navigation
    Future.microtask(() {
      if (!_isDisposed) {
        Navigator.of(context).pop({'success': false});
      }
    });
  }

  Widget _buildCodeBox(int index, double width) {
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          border: const OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
        ),
        onChanged: (value) {
          if (!_isDisposed) {
            if (value.isNotEmpty && index < 5) {
              FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
            } else if (value.isEmpty && index > 0) {
              FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Space').tr(),
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
              'Enter Invite Code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ).tr(),
            const SizedBox(height: 8),
            const Text(
              'Enter the 6-digit code provided by the space creator',
              style: TextStyle(fontSize: 14),
            ).tr(),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = constraints.maxWidth * 0.12;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < 3; i++) _buildCodeBox(i, fieldWidth),
                    const SizedBox(width: 8),
                    const Text('-', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    for (int i = 3; i < 6; i++) _buildCodeBox(i, fieldWidth),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _joinSpace,
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
                        : const Text('Submit').tr(),
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
