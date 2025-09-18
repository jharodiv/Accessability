// verification_code_screen.dart
import 'dart:math';

import 'package:accessability/accessability/backgroundServices/deep_link_service.dart';
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:accessability/accessability/presentation/widgets/reusableWidgets/send_code_dialog_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

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

    // Clear pending deep link/session to avoid re-navigation issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService().clearPendingData();
    });
  }

  Future<void> _clearClipboard() async {
    try {
      await Clipboard.setData(const ClipboardData(text: ""));
      debugPrint("🧹 Clipboard cleared after successful join navigation.");
    } catch (e) {
      debugPrint("⚠️ Failed to clear clipboard: $e");
    }
  }

  Future<void> _ensureCode() async {
    setState(() => _isLoading = true);

    try {
      final docSnap =
          await _firestore.collection('Spaces').doc(widget.spaceId).get();
      if (!docSnap.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('spaceNotFound'.tr())),
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

      // ✅ CLEAR CLIPBOARD AFTER SUCCESSFUL CODE FETCH
      await _clearClipboard();
    } catch (e) {
      debugPrint('Error ensuring code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'errorOccurred'.tr(namedArgs: {'detail': e.toString()}),
            ),
          ),
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
      // Use tr for singular/plural if you later add plurals; for now return plain text
      return '$days ${days == 1 ? "day" : "days"}';
    } else {
      return '$hrs ${hrs == 1 ? "hour" : "hours"}';
    }
  }

  Future<String?> _showEmailInputDialog() async {
    // show our styled dialog which returns the entered email (or null)
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => const SendCodeDialogWidget(),
    );
    return result;
  }

  Future<void> _shareCode() async {
    if (_verificationCode == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final email = await _showEmailInputDialog();
    if (email == null || email.trim().isEmpty) return;

    if (email.trim() == user.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('cannotSendToSelf'.tr())),
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
          SnackBar(content: Text('userNotFound'.tr())),
        );
        return;
      }

      final receiverId = receiverSnapshot.docs.first.id;

      // Use the unified ChatService method
      await _chatService.sendVerificationCode(
          receiverId, widget.spaceId, widget.spaceName ?? 'Unnamed Space');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF6750A4), // Purple
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.zero, // full width, no margin
          content: Text(
            'verificationSent'.tr(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('errorOccurred'.tr(namedArgs: {'detail': e.toString()}))),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildBody() {
    final displayName = (widget.spaceName?.trim().isNotEmpty ?? false)
        ? widget.spaceName!.trim()
        : 'Space';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),

        /// Title
        Text(
          'inviteMembers'.tr(namedArgs: {'space': displayName}),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E1750),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        /// Subtitle
        Text(
          'shareCodeInstruction'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF7A6E9A),
                height: 1.4,
              ),
        ),
        const SizedBox(height: 28),

        /// Code Card
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          color: const Color(0xFFF7F3FF),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            child: Column(
              children: [
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      )
                    : Column(
                        children: [
                          /// Code
                          Text(
                            _displayFormattedCode(_verificationCode),
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  color: const Color(0xFF5B3DC4),
                                ),
                          ),
                          const SizedBox(height: 12),

                          /// Validity Text
                          Text(
                            'codeActiveFor'.tr(
                                namedArgs: {'duration': _formatValidityText()}),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.black87,
                                ),
                          ),
                          const SizedBox(height: 24),

                          /// Share Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.send, size: 20),
                              label: Text('shareCode'.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6750A4),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: _isLoading ? null : _shareCode,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),

        /// OR Divider
        Row(
          children: [
            const Expanded(
                child: Divider(color: Color(0xFFCCC2DC), thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7A6E9A),
                    ),
              ),
            ),
            const Expanded(
                child: Divider(color: Color(0xFFCCC2DC), thickness: 1)),
          ],
        ),

        const SizedBox(height: 28),

        /// QR Section
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          color: const Color(0xFFF5F0FF),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'scanToEnter'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2E1750),
                      ),
                ),
                const SizedBox(height: 16),
                QrImageView(
                  data:
                      "https://3-y2-aapwd-8vze.vercel.app/?code=${_verificationCode ?? ""}",
                  version: QrVersions.auto,
                  size: 180,
                ),
                const SizedBox(height: 8),
                Text(
                  'Point your camera to join',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
              ],
            ),
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
            title: Text(
              'inviteCode'.tr(),
              style: const TextStyle(
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
