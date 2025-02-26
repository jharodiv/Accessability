import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Accessability/accessability/firebaseServices/auth/auth_service.dart';
import 'package:Accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:Accessability/accessability/presentation/widgets/chatWidgets/chat_convo_bubble.dart';
import 'package:Accessability/accessability/presentation/widgets/reusableWidgets/custom_text_field.dart';
import 'package:intl/intl.dart';

class ChatConvoScreen extends StatefulWidget {
  const ChatConvoScreen({
    super.key,
    required this.receiverEmail,
    required this.receiverID,

  });

  final String receiverEmail;
  final String receiverID;

  @override
  State<ChatConvoScreen> createState() => _ChatConvoScreenState();
}

class _ChatConvoScreenState extends State<ChatConvoScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final ChatService chatService = ChatService();
  final AuthService authService = AuthService();
  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 500), () => scrollDown());
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () => scrollDown());
  }

  void sendMessage() async {
    if (messageController.text.isNotEmpty) {
      await chatService.sendMessage(widget.receiverID, messageController.text);
      messageController.clear();
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
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.receiverEmail)),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildUserInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    String senderID = authService.getCurrentUser()!.uid;
    return StreamBuilder(
      stream: chatService.getMessages(widget.receiverID, senderID),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Error');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Loading...');
        }

        List<Widget> messageWidgets = [];
        Timestamp? lastTimestamp;

        for (var doc in snapshot.data!.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          bool isCurrentUser = data['senderID'] == senderID;

          // Check if we need to add a timestamp divider
          if (lastTimestamp != null) {
            final currentTimestamp = data['timestamp'] as Timestamp;
            final difference = currentTimestamp.toDate().difference(lastTimestamp.toDate()).inMinutes;

            if (difference >= 10) {
              messageWidgets.add(
                Column(
                  children: [
                    const Divider(),
                    Text(
                      DateFormat('hh:mm a').format(currentTimestamp.toDate()),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const Divider(),
                  ],
                ),
              );
            }
          }

          // Add the message item
          messageWidgets.add(_buildMessageItem(doc));
          lastTimestamp = data['timestamp'];
        }

        // Automatically scroll down when new messages are added
        if (snapshot.hasData && messageWidgets.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollDown();
          });
        }

        return ListView(
          controller: scrollController,
          children: messageWidgets,
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isCurrentUser = data['senderID'] == authService.getCurrentUser()!.uid;
    var alignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    return Container(
      alignment: alignment,
      child: Column(
        crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChatConvoBubble(
            isCurrentUser: isCurrentUser,
            message: data['message'],
            timestamp: data['timestamp'],
          ),
        ],
      ),
    );
  }

  Widget _buildUserInput() {
    return Row(
      children: [
        Expanded(
          child: CustomTextField(
            focusNode: focusNode,
            controller: messageController,
            hintText: 'Type a message...',
            obscureText: false,
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF6750A4),
            shape: BoxShape.circle,
          ),
          margin: const EdgeInsets.only(right: 25),
          child: IconButton(
            onPressed: sendMessage,
            icon: const Icon(Icons.arrow_upward),
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}