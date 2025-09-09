import 'package:accessability/accessability/presentation/widgets/chatWidgets/verification_code_bubble.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ChatConvoBubble extends StatefulWidget {
  final String message;
  final bool isCurrentUser;
  final Timestamp timestamp;
  final String profilePicture;
  final Function()? onEdit;
  final Function()? onDelete;
  final Function(String emoji)? onReact;
  final bool isSystemMessage;
  final Map<String, dynamic>? metadata;
  final bool edited; // Add this
  final bool deleted; // Add this
  final String messageId; // Add this to identify the message
  final String chatRoomId; // Add this to identify the chat room
  final bool isSpaceChat; // Add this

  const ChatConvoBubble({
    super.key,
    required this.isCurrentUser,
    required this.message,
    required this.timestamp,
    required this.profilePicture,
    this.onEdit,
    this.onDelete,
    this.onReact,
    this.isSystemMessage = false,
    this.metadata,
    this.edited = false, // Initialize
    this.deleted = false, // Initialize
    required this.messageId, // Required
    required this.chatRoomId, // Required
    this.isSpaceChat = false, // Initialize
  });

  @override
  _ChatConvoBubbleState createState() => _ChatConvoBubbleState();
}

class _ChatConvoBubbleState extends State<ChatConvoBubble> {
  bool _showTimestamp = false;
  LatLng? _location;

  @override
  void initState() {
    super.initState();
    _location = _extractLatLngFromMessage(widget.message);
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
    // Don't show options menu for system messages or deleted messages
    if (widget.isSystemMessage || widget.deleted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isCurrentUser) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onEdit?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete?.call();
                },
              ),
            ],
            // Always show copy option for all messages (except system/deleted)
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                _copyToClipboard(widget.message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions),
              title: const Text('React'),
              onTap: () {
                Navigator.pop(context);
                _showEmojiPicker(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Message copied to clipboard')),
    );
  }

  void _showEmojiPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return EmojiPicker(
          onEmojiSelected: (category, emoji) {
            widget.onReact?.call(emoji.emoji);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    // Handle deleted messages
    if (widget.deleted) {
      return _buildDeletedMessage(context, isDarkMode);
    }

    final isVerificationCode = widget.metadata != null &&
        widget.metadata!['type'] == 'verification_code';

    // Handle verification code messages differently
    if (isVerificationCode) {
      return _buildVerificationCodeBubble(context, isDarkMode);
    }

    // Handle system messages differently
    if (widget.isSystemMessage) {
      return _buildSystemMessage(context, isDarkMode);
    }

    final DateTime messageDate = widget.timestamp.toDate();
    final DateTime now = DateTime.now();
    final bool isThisWeek = now.difference(messageDate).inDays <= 7;

    String formattedTime = isThisWeek
        ? DateFormat('E hh:mm a').format(messageDate)
        : DateFormat('MMM d, yyyy hh:mm a').format(messageDate);

    return Row(
      mainAxisAlignment: widget.isCurrentUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isCurrentUser)
          CircleAvatar(
            backgroundImage: NetworkImage(widget.profilePicture),
          ),
        const SizedBox(width: 8),
        Flexible(
          child: InkWell(
            onTap: () {
              setState(() {
                _showTimestamp = !_showTimestamp;
              });
            },
            onLongPress: () => _showOptionsMenu(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              decoration: BoxDecoration(
                color: widget.isCurrentUser
                    ? const Color(0xFF6750A4)
                    : (isDarkMode
                        ? const Color.fromARGB(255, 65, 63, 71)
                        : const Color.fromARGB(255, 145, 141, 141)),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_location != null) _buildMapPreview(_location!),
                  Text(
                    widget.message,
                    style: TextStyle(
                      color: widget.isCurrentUser
                          ? Colors.white
                          : (isDarkMode ? Colors.white : Colors.black),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_showTimestamp)
                    Text(
                      formattedTime,
                      style: TextStyle(
                        color: widget.isCurrentUser
                            ? Colors.white70
                            : Colors.black54,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
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

  Widget _buildNormalMessage(BuildContext context, bool isDarkMode) {
    return Row(
      mainAxisAlignment: widget.isCurrentUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isCurrentUser)
          CircleAvatar(
            backgroundImage: NetworkImage(widget.profilePicture),
          ),
        const SizedBox(width: 8),
        Flexible(
          child: InkWell(
            onTap: () {
              setState(() {
                _showTimestamp = !_showTimestamp;
              });
            },
            onLongPress: () => _showOptionsMenu(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              decoration: BoxDecoration(
                color: widget.isCurrentUser
                    ? const Color(0xFF6750A4)
                    : (isDarkMode
                        ? const Color.fromARGB(255, 65, 63, 71)
                        : const Color.fromARGB(255, 145, 141, 141)),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_location != null) _buildMapPreview(_location!),
                  Text(
                    widget.message,
                    style: TextStyle(
                      color: widget.isCurrentUser
                          ? Colors.white
                          : (isDarkMode ? Colors.white : Colors.black),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.edited)
                    Text(
                      'edited',
                      style: TextStyle(
                        color: widget.isCurrentUser
                            ? Colors.white70
                            : Colors.black54,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (_showTimestamp)
                    Text(
                      _formatTimestamp(widget.timestamp),
                      style: TextStyle(
                        color: widget.isCurrentUser
                            ? Colors.white70
                            : Colors.black54,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
      isSpaceMember:
          false, // This will be checked in the VerificationCodeBubble itself
    );
  }

  // Build system message widget
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
