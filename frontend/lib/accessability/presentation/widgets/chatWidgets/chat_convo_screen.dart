import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:frontend/accessability/firebaseServices/auth/auth_service.dart';
import 'package:frontend/accessability/firebaseServices/chat/chat_service.dart';
import 'package:frontend/accessability/presentation/widgets/reusableWidgets/custom_text_field.dart';

class ChatConvoScreen extends StatelessWidget {
   ChatConvoScreen({
    super.key, 
    required this.receiverEmail,
    required this.receiverID
    });

  final String receiverEmail;
  final String receiverID;

  final TextEditingController messageController = TextEditingController();

  final ChatService chatService = ChatService();
  final AuthService authService = AuthService();

  void sendMessage() async {
    if (messageController.text.isNotEmpty) {
      await chatService.sendMessage(receiverID, messageController.text);

      messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(receiverEmail)),
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
      stream: chatService.getMessages(receiverID, senderID), 
      builder: (context, snapshot) {
        if(snapshot.hasError) {
          return const Text('Error');
        }

        if(snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Loading...');
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) => _buildMessageItem(doc)).toList(),
        );

    });
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Text(data['message']);
  }

  Widget _buildUserInput() {
    return Row(
      children: [
        Expanded(child: CustomTextField(
          controller: messageController,
          hintText: 'Type a message...',
          obscureText: false,
        ),
        ),

        IconButton(onPressed: sendMessage, icon: const Icon(Icons.arrow_upward))
      ],
    );
  }
}
