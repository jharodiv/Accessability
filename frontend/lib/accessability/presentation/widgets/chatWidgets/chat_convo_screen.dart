import 'package:accessability/accessability/presentation/widgets/chatWidgets/verification_code_bubble.dart';
import 'package:accessability/accessability/presentation/widgets/shimmer/shimmer_chat_center_empty.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:accessability/accessability/firebaseServices/auth/auth_service.dart';
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:accessability/accessability/presentation/widgets/chatWidgets/chat_convo_bubble.dart';
import 'package:accessability/accessability/presentation/widgets/reusableWidgets/custom_text_field.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ChatConvoScreen extends StatefulWidget {
  const ChatConvoScreen({
    super.key,
    required this.receiverUsername,
    required this.receiverID,
    this.isSpaceChat = false,
  });

  final String receiverUsername;
  final String receiverID;
  final bool isSpaceChat;

  @override
  State<ChatConvoScreen> createState() => _ChatConvoScreenState();
}

class _ChatConvoScreenState extends State<ChatConvoScreen> {
  final TextEditingController messageController = TextEditingController();
  final TextEditingController editController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final ChatService chatService = ChatService();
  final AuthService authService = AuthService();
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  FocusNode focusNode = FocusNode();
  bool _isRequestPending = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? editingMessageId;
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _checkChatRequest();
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) => scrollDown());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollDown());
  }

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    final snapshot =
        await FirebaseFirestore.instance.collection('Users').doc(userId).get();

    final data = snapshot.data() ?? {};
    _userCache[userId] = data;
    return data;
  }

  Future<void> _checkChatRequest() async {
    final senderID = authService.getCurrentUser()!.uid;
    final hasRequest =
        await chatService.hasChatRequest(senderID, widget.receiverID);
    setState(() {
      _isRequestPending = hasRequest;
    });
  }

  Future<void> _acceptChatRequest() async {
    await chatService.acceptChatRequest(widget.receiverID);
    setState(() {
      _isRequestPending = false;
    });
  }

  void sendMessage() async {
    // Trim the message to remove leading and trailing spaces
    final trimmedMessage = messageController.text.trim();

    // Check if the trimmed message is not empty
    if (trimmedMessage.isNotEmpty) {
      await chatService.sendMessage(
        widget.receiverID,
        trimmedMessage,
        isSpaceChat: widget.isSpaceChat,
      );
      messageController.clear();

      // Scroll to the bottom after sending a message
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollDown());
    } else {
      // Optionally, you can show a message to the user indicating that empty messages are not allowed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message cannot be empty'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _editMessage(String messageId, String currentMessage) {
    setState(() {
      editingMessageId = messageId;
      editController.text = currentMessage;
    });

    showDialog(
      context: context,
      builder: (context) {
        final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

        return Dialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Message',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: editController,
                    maxLines: 3,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Edit your message...',
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.white60 : Colors.grey[600],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          editingMessageId = null;
                        });
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6750A4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        onPressed: () async {
                          if (editController.text.trim().isNotEmpty) {
                            try {
                              final chatRoomId = chatService.getChatRoomId(
                                _auth.currentUser!.uid,
                                widget.receiverID,
                              );

                              await chatService.editMessage(
                                chatRoomId: chatRoomId,
                                messageId: messageId,
                                newMessage: editController.text.trim(),
                                isSpaceChat: widget.isSpaceChat,
                              );

                              Navigator.pop(context);
                              setState(() {
                                editingMessageId = null;
                              });
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to edit message: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'Save',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteMessage(String messageId) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.orange,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  'Delete Message',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete this message?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        onPressed: () async {
                          try {
                            final chatRoomId = chatService.getChatRoomId(
                              _auth.currentUser!.uid,
                              widget.receiverID,
                            );

                            await chatService.deleteMessage(
                              chatRoomId: chatRoomId,
                              messageId: messageId,
                              isSpaceChat: widget.isSpaceChat,
                            );

                            Navigator.pop(context);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete message: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    focusNode.dispose();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void scrollDown() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.minScrollExtent, // ✅ with reverse:true
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final bool isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    if (args == null) {
      return const Scaffold(
        body: Center(
          child: Text('Error: Missing arguments for ChatConvoScreen'),
        ),
      );
    }

    final String receiverUsername = args['receiverUsername'] as String;
    final String receiverID = args['receiverID'] as String;
    final String receiverProfilePicture = args['receiverProfilePicture']
            as String? ??
        (widget.isSpaceChat
            ? 'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.firebasestorage.app/o/profile_pictures%2Fgroup_chat_icon.jpg?alt=media&token=7604bd51-2edf-4514-b979-e3fa84dce389'
            : 'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.appspot.com/o/profile_pictures%2Fdefault_profile.png?alt=media&token=bc7a75a7-a78e-4460-b816-026a8fc341ba');

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
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
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4), // purple theme
            ),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(receiverProfilePicture),
                ),
                const SizedBox(width: 10),
                Text(
                  receiverUsername,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            centerTitle: false, // keep avatar + name aligned to left
          ),
        ),
      ),
      body: Container(
        color: isDarkMode
            ? const Color(0xFF121212)
            : const Color.fromARGB(
                255, 255, 255, 255), // Dark or light background
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildMessageList()),
              _buildUserInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder(
      stream: chatService.getMessages(
        widget.receiverID,
        isSpaceChat: widget.isSpaceChat,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading messages.'));
        }

        if (!snapshot.hasData) {
          return const ChatCenterEmpty(); // only the first time, before data arrives
        }

        final messages = snapshot.data!.docs;

        if (messages.isEmpty) {
          return const Center(child: Text('No messages yet'));
        }

        // Build list with dividers
        List<Widget> messageWidgets = [];
        DateTime? previousMessageTime;

        for (var doc in messages) {
          final data = doc.data() as Map<String, dynamic>;
          final messageTime = (data['timestamp'] as Timestamp).toDate();

          if (previousMessageTime != null &&
              messageTime.difference(previousMessageTime).inMinutes > 10) {
            messageWidgets.add(_buildTimeDivider(messageTime));
          }

          messageWidgets.add(_buildMessageItem(doc));
          previousMessageTime = messageTime;
        }

        return ListView(
          controller: scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: messageWidgets,
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isSystemMessage = data['isSystemMessage'] == true;
    bool isCurrentUser = data['senderID'] == authService.getCurrentUser()!.uid;
    bool isDeleted = data['deleted'] == true;
    bool isEdited = data['edited'] == true;

    // Get chat room ID
    final chatRoomId = widget.isSpaceChat
        ? widget.receiverID
        : chatService.getChatRoomId(
            _auth.currentUser!.uid,
            widget.receiverID,
          );

    // Handle system messages
    if (isSystemMessage) {
      return _buildSystemMessage(data['message'], data['timestamp']);
    }

    // Handle verification code messages
    if (data['metadata'] != null &&
        data['metadata']['type'] == 'verification_code') {
      return _buildVerificationCodeBubble(data);
    }

    // ✅ Use cached user lookup instead of refetching every time
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserData(data['senderID']),
      builder: (context, snapshot) {
        final userData = snapshot.data ?? {};
        final profilePicture =
            userData['profilePicture'] ?? 'https://.../default_profile.png';

        return ChatConvoBubble(
          isCurrentUser: isCurrentUser,
          message: isDeleted ? 'This message was deleted' : data['message'],
          timestamp: data['timestamp'],
          profilePicture: profilePicture,
          metadata: data['metadata'] != null
              ? Map<String, dynamic>.from(data['metadata'])
              : null,
          edited: isEdited,
          deleted: isDeleted,
          messageId: doc.id,
          chatRoomId: chatRoomId,
          isSpaceChat: widget.isSpaceChat,
          onEdit: isCurrentUser && !isDeleted
              ? () => _editMessage(doc.id, data['message'])
              : null,
          onDelete:
              isCurrentUser && !isDeleted ? () => _deleteMessage(doc.id) : null,
        );
      },
    );
  }

  Widget _buildSystemMessage(String message, Timestamp timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCodeBubble(Map<String, dynamic> data) {
    final metadata = Map<String, dynamic>.from(data['metadata']);
    final spaceId = metadata['spaceId'];
    final verificationCode = metadata['verificationCode'];
    final spaceName = metadata['spaceName'];
    final expiresAt = DateTime.parse(metadata['expiresAt']);
    final codeTimestamp = data['timestamp'].toDate();
    return FutureBuilder(
      future: chatService.isUserSpaceMember(spaceId, _auth.currentUser!.uid),
      builder: (context, membershipSnapshot) {
        if (membershipSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingBubble();
        }

        final isSpaceMember = membershipSnapshot.data ?? false;

        return VerificationCodeBubble(
          spaceId: spaceId,
          verificationCode: verificationCode,
          codeTimestamp: codeTimestamp,
          expiresAt: expiresAt,
          isSpaceMember: isSpaceMember,
        );
      },
    );
  }

  Widget _buildLoadingBubble() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey, width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Loading verification code...'),
        ],
      ),
    );
  }

  Widget _buildUserInput() {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: messageController,
              focusNode: focusNode,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
              ),
              onChanged: (_) {
                setState(() {}); // rebuild to check if text is empty or not
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF6750A4),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: messageController.text.trim().isNotEmpty
                  ? sendMessage
                  : () {
                      // Example: send a like/emoji
                      chatService.sendMessage(
                        widget.receiverID,
                        "👍",
                        isSpaceChat: widget.isSpaceChat,
                      );
                    },
              icon: Icon(
                messageController.text.trim().isNotEmpty
                    ? Icons.arrow_upward // send
                    : Icons.thumb_up_alt_outlined, // like/emoji
              ),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDivider(DateTime messageTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    String formattedTime;
    if (messageTime.isAfter(today)) {
      // Today: Use AM/PM
      formattedTime = DateFormat('h:mm a').format(messageTime);
    } else if (messageTime.isAfter(yesterday)) {
      // Yesterday: Show "Yesterday"
      formattedTime = 'Yesterday ${DateFormat('h:mm a').format(messageTime)}';
    } else if (now.difference(messageTime).inDays <= 3) {
      // Within 3 days: Show day and time
      formattedTime = DateFormat('EEE h:mm a').format(messageTime);
    } else {
      // More than 3 days: Show date and time
      formattedTime = DateFormat('MMM d, yyyy h:mm a').format(messageTime);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          formattedTime,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
