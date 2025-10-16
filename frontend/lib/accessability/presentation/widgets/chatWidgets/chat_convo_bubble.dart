import 'package:accessability/accessability/presentation/screens/chat_system/speech_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:accessability/accessability/presentation/widgets/chatWidgets/verification_code_bubble.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ChatConvoBubble extends StatefulWidget {
  final String message;
  final String username;
  final bool isCurrentUser;
  final Timestamp timestamp;
  final String profilePicture;
  final Function()? onEdit;
  final Function()? onDelete;
  final Function(String emoji)? onReact;
  final bool isSystemMessage;
  final Map<String, dynamic>? metadata;
  final bool edited;
  final bool deleted;
  final String messageId;
  final String chatRoomId;
  final bool isSpaceChat;

  const ChatConvoBubble({
    super.key,
    required this.isCurrentUser,
    required this.username,
    required this.message,
    required this.timestamp,
    required this.profilePicture,
    this.onEdit,
    this.onDelete,
    this.onReact,
    this.isSystemMessage = false,
    this.metadata,
    this.edited = false,
    this.deleted = false,
    required this.messageId,
    required this.chatRoomId,
    this.isSpaceChat = false,
  });

  @override
  _ChatConvoBubbleState createState() => _ChatConvoBubbleState();
}

class _ChatConvoBubbleState extends State<ChatConvoBubble> {
  bool _showTimestamp = false;
  LatLng? _location;
  final SpeechService _speechService = SpeechService();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _location = _extractLatLngFromMessage(widget.message);
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    await _speechService.initializeSpeech();
  }

  Future<void> _speakMessage() async {
    if (_isSpeaking) {
      await _speechService.stopSpeaking();
      setState(() {
        _isSpeaking = false;
      });
      return;
    }

    setState(() {
      _isSpeaking = true;
    });

    await _speechService.speakText(widget.message);

    // Listen for completion (you might want to use a stream instead)
    // For simplicity, we'll use a delayed check
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        // Periodically check if speaking has stopped
        _checkSpeakingStatus();
      }
    });
  }

  void _checkSpeakingStatus() {
    if (!_speechService.isSpeaking && _isSpeaking) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    } else if (_speechService.isSpeaking) {
      // Check again after 1 second
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          _checkSpeakingStatus();
        }
      });
    }
  }

  LatLng? _extractLatLngFromMessage(String message) {
    final regex =
        RegExp(r'https://www\.google\.com/maps\?q=([\d\.]+),([\d\.]+)');
    final match = regex.firstMatch(message);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    return null;
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime messageDate = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(messageDate);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(messageDate);
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(messageDate)}';
    } else if (difference.inDays <= 2) {
      return DateFormat('EEEE, h:mm a').format(messageDate);
    } else {
      return DateFormat('MMM d, h:mm a').format(messageDate);
    }
  }

  void _showOptionsMenu(BuildContext context) {
    if (widget.isSystemMessage || widget.deleted) return;

    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // top handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (widget.isCurrentUser) ...[
                  _buildOptionTile(
                    context,
                    icon: Icons.edit_rounded,
                    label: 'Edit Message',
                    color: const Color(0xFF7C4DFF),
                    onTap: widget.onEdit,
                  ),
                  _buildOptionTile(
                    context,
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete Message',
                    color: Colors.redAccent,
                    onTap: widget.onDelete,
                  ),
                ],
                _buildOptionTile(
                  context,
                  icon: Icons.volume_up_rounded,
                  label: 'Read Aloud',
                  color: Colors.blue,
                  onTap: _speakMessage,
                ),
                _buildOptionTile(
                  context,
                  icon: Icons.content_copy_rounded,
                  label: 'Copy Message',
                  color: isDarkMode ? Colors.white70 : Colors.deepPurple,
                  onTap: () => _copyToClipboard(widget.message),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    Function()? onTap,
  }) {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withOpacity(0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap?.call();
      },
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
    );
  }

  @override
  void dispose() {
    _speechService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    final isVerificationCode = widget.metadata != null &&
        widget.metadata!['type'] == 'verification_code';

    if (isVerificationCode) {
      return _buildVerificationCodeBubble(context, isDarkMode);
    }

    if (widget.isSystemMessage) {
      return _buildSystemMessage(context, isDarkMode);
    }

    if (widget.deleted) {
      return _buildDeletedMessage(context, isDarkMode);
    }

    return _buildNormalMessage(context, isDarkMode);
  }

  Widget _buildVerificationCodeBubble(BuildContext context, bool isDarkMode) {
    final spaceId = widget.metadata!['spaceId'];
    final verificationCode = widget.metadata!['verificationCode'];
    final spaceName = widget.metadata!['spaceName'];
    final expiresAt = DateTime.parse(widget.metadata!['expiresAt']);
    final codeTimestamp = widget.timestamp.toDate();
    return VerificationCodeBubble(
      spaceId: spaceId,
      verificationCode: verificationCode,
      codeTimestamp: codeTimestamp,
      expiresAt: expiresAt,
      isSpaceMember: false,
    );
  }

  Widget _buildSystemMessage(BuildContext context, bool isDarkMode) {
    final DateTime messageDate = widget.timestamp.toDate();
    final DateTime now = DateTime.now();
    final bool isThisWeek = now.difference(messageDate).inDays <= 7;

    String formattedTime = isThisWeek
        ? DateFormat('E hh:mm a').format(messageDate)
        : DateFormat('MMM d, yyyy hh:mm a').format(messageDate);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.message,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (_showTimestamp)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletedMessage(BuildContext context, bool isDarkMode) {
    return Row(
      mainAxisAlignment: widget.isCurrentUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'This message was deleted',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey[600],
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // Helper - builds the outside mic button, vertically centered by Row's crossAxisAlignment
  Widget buildOutsideMic(bool isDarkMode) {
    const Color mainPurple = Color(0xFF6750A4); // base purple
    const Color accentPurple = Color(0xFF7C4DFF); // brighter accent

    // Background: slightly stronger when speaking, very light when idle
    final Color bgColor = _isSpeaking
        ? mainPurple.withOpacity(0.18)
        : mainPurple.withOpacity(0.10);

    // Icon color: darker purple (accent when speaking)
    final Color iconColor = _isSpeaking ? accentPurple : mainPurple;

    return GestureDetector(
      onTap: _speakMessage,
      behavior: HitTestBehavior.translucent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(10), // roomy touch target like your mock
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: mainPurple.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          _isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
          size: 20,
          color: iconColor,
        ),
      ),
    );
  }

  Widget _buildNormalMessage(BuildContext context, bool isDarkMode) {
    final bubbleWithMic = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: widget.isCurrentUser
          ? [
              buildOutsideMic(isDarkMode), // Mic on the left for current user
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showTimestamp = !_showTimestamp;
                        });
                      },
                      onLongPress: () => _showOptionsMenu(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.72,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: _bubbleDecoration(isDarkMode, true),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_location != null) ...[
                              _buildMapPreview(_location!),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              widget.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showTimestamp)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _formatTimestamp(widget.timestamp),
                          style: TextStyle(
                            color:
                                isDarkMode ? Colors.white54 : Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ]
          : [
              // Other users: avatar -> bubble -> mic
              CircleAvatar(
                backgroundImage: NetworkImage(widget.profilePicture),
                radius: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        widget.username,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showTimestamp = !_showTimestamp;
                        });
                      },
                      onLongPress: () => _showOptionsMenu(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.72,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: _bubbleDecoration(isDarkMode, false),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_location != null) ...[
                              _buildMapPreview(_location!),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              widget.message,
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showTimestamp)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _formatTimestamp(widget.timestamp),
                          style: TextStyle(
                            color:
                                isDarkMode ? Colors.white54 : Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              buildOutsideMic(isDarkMode),
            ],
    );

    return Padding(
      padding: EdgeInsets.only(
        top: widget.isCurrentUser ? 4.0 : 12.0, // more space for other users
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: widget.isCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(child: bubbleWithMic),
        ],
      ),
    );
  }

  BoxDecoration _bubbleDecoration(bool isDarkMode, bool isCurrentUser) {
    if (isCurrentUser) {
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7C4DFF),
            Color(0xFF5E35B1),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      );
    } else {
      return BoxDecoration(
        color: isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFF7F8FB),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.35 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFEAEDF0),
          width: 0.6,
        ),
      );
    }
  }

  Widget _buildMapPreview(LatLng location) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: location,
            zoom: 15,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('location'),
              position: location,
            ),
          },
          zoomControlsEnabled: false,
          scrollGesturesEnabled: false,
          tiltGesturesEnabled: false,
          rotateGesturesEnabled: false,
          zoomGesturesEnabled: false,
        ),
      ),
    );
  }
}
