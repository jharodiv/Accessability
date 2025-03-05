import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/firebaseServices/auth/auth_service.dart';
import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:AccessAbility/accessability/presentation/widgets/chatWidgets/chat_convo_bubble.dart';
import 'package:AccessAbility/accessability/presentation/widgets/reusableWidgets/custom_text_field.dart';
import 'package:intl/intl.dart';

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
  final ScrollController scrollController = ScrollController();
  final ChatService chatService = ChatService();
  final AuthService authService = AuthService();
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  FocusNode focusNode = FocusNode();
  bool _isRequestPending = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  Future<void> _checkChatRequest() async {
    final senderID = authService.getCurrentUser()!.uid;
    final hasRequest = await chatService.hasChatRequest(senderID, widget.receiverID);
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
  if (messageController.text.isNotEmpty) {
    await chatService.sendMessage(
      widget.receiverID,
      messageController.text,
      isSpaceChat: widget.isSpaceChat,
    );
    messageController.clear();

    // Scroll to the bottom after sending a message
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollDown());
  }
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
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args == null) {
      return const Scaffold(
        body: Center(
          child: Text('Error: Missing arguments for ChatConvoScreen'),
        ),
      );
    }

    final String receiverUsername = args['receiverUsername'] as String;
    final String receiverID = args['receiverID'] as String;
    final String receiverProfilePicture = args['receiverProfilePicture'] as String? ??
        (widget.isSpaceChat
            ? 'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.firebasestorage.app/o/profile_pictures%2Fgroup_chat_icon.jpg?alt=media&token=7604bd51-2edf-4514-b979-e3fa84dce389'
            : 'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.appspot.com/o/profile_pictures%2Fdefault_profile.png?alt=media&token=bc7a75a7-a78e-4460-b816-026a8fc341ba');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(receiverProfilePicture),
            ),
            const SizedBox(width: 10),
            Text(receiverUsername),
          ],
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildUserInput(),
          ],
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

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

         // Extract messages from the snapshot
      final messages = snapshot.data!.docs;

      // Scroll to the bottom after messages are loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

         // Build message widgets
      List<Widget> messageWidgets = [];
      for (var doc in messages) {
        messageWidgets.add(_buildMessageItem(doc));
      }

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: messageWidgets,
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isCurrentUser = data['senderID'] == authService.getCurrentUser()!.uid;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Users')
          .doc(data['senderID'])
          .get(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return ChatConvoBubble(
            isCurrentUser: isCurrentUser,
            message: data['message'],
            timestamp: data['timestamp'],
            profilePicture: 'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.appspot.com/o/profile_pictures%2Fdefault_profile.png?alt=media&token=bc7a75a7-a78e-4460-b816-026a8fc341ba',
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final profilePicture = userData['profilePicture'] ?? 'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.appspot.com/o/profile_pictures%2Fdefault_profile.png?alt=media&token=bc7a75a7-a78e-4460-b816-026a8fc341ba';

        return ChatConvoBubble(
          isCurrentUser: isCurrentUser,
          message: data['message'],
          timestamp: data['timestamp'],
          profilePicture: profilePicture,
        );
      },
    );
  }

  Widget _buildUserInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: CustomTextField(
              focusNode: focusNode,
              controller: messageController,
              hintText: 'Type a message...',
              obscureText: false,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF6750A4),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: sendMessage,
              icon: const Icon(Icons.arrow_upward),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}