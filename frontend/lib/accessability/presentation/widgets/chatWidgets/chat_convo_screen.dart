import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:frontend/accessability/firebaseServices/auth/auth_service.dart';
import 'package:frontend/accessability/firebaseServices/chat/chat_service.dart';
import 'package:frontend/accessability/presentation/widgets/chatWidgets/chat_convo_bubble.dart';
import 'package:frontend/accessability/presentation/widgets/reusableWidgets/custom_text_field.dart';

class ChatConvoScreen extends StatefulWidget {
   ChatConvoScreen({
    super.key, 
    required this.receiverEmail,
    required this.receiverID
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
      if(focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 500), () => scrollDown());
      }
    });

    Future.delayed(const Duration(milliseconds: 500),
    () => scrollDown(),
    );
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
    super.dispose();
  }


  void scrollDown() {
    scrollController.animateTo(
      scrollController.position.maxScrollExtent, 
      duration: const Duration(seconds: 1),
      curve: Curves.fastOutSlowIn);
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.receiverEmail)),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(),
          
          ),
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
        if(snapshot.hasError) {
          return const Text('Error');
        }

        if(snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Loading...');
        }

        return ListView(
          controller: scrollController,
          children: snapshot.data!.docs.map((doc) => _buildMessageItem(doc)).toList(),
        );

    });
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
         ChatConvoBubble(isCurrentUser: isCurrentUser, message: data['message']),
        ],
      ));
  }

  Widget _buildUserInput() {
    return Row(
      children: [
        Expanded(child: CustomTextField(
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
          margin: const EdgeInsets.only(right: 25 ),
          child: IconButton(
          onPressed: sendMessage, 
          icon: const Icon(Icons.arrow_upward),
          color: Colors.white,))
      ],
    );
  }
}
