import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
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
  final bool isSystemMessage; // Add this property

  const ChatConvoBubble({
    super.key,
    required this.isCurrentUser,
    required this.message,
    required this.timestamp,
    required this.profilePicture,
    this.onEdit,
    this.onDelete,
    this.onReact,
    this.isSystemMessage = false, // Default to false
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

  void _showOptionsMenu(BuildContext context) {
    // Don't show options menu for system messages
    if (widget.isSystemMessage) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
