import 'package:flutter/material.dart';

class ChatUsersTile extends StatelessWidget {
  const ChatUsersTile({
    super.key,
    required this.text,
    required this.onTap,
  });

  final String text;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 25),
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.person),
              Text(text),
            ],
          )),
    );
  }
}
