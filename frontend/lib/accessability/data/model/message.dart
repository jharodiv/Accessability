import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderID;
  final String senderEmail;
  final String receiverID;
  final String message;
  final Timestamp timestamp;
  final Map<String, dynamic>? metadata;
  final bool edited;
  final Timestamp? editedAt;
  final bool deleted;
  final Timestamp? deletedAt;
  final String? originalMessage;

  Message({
    required this.senderID,
    required this.senderEmail,
    required this.receiverID,
    required this.message,
    required this.timestamp,
    this.metadata,
    this.edited = false,
    this.editedAt,
    this.deleted = false,
    this.deletedAt,
    this.originalMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderID': senderID,
      'senderEmail': senderEmail,
      'receiverID': receiverID,
      'message': message,
      'timestamp': timestamp,
      'metadata': metadata,
      'edited': edited,
      'editedAt': editedAt,
      'deleted': deleted,
      'deletedAt': deletedAt,
      'originalMessage': originalMessage,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      senderID: map['senderID'] ?? '',
      senderEmail: map['senderEmail'] ?? '',
      receiverID: map['receiverID'] ?? '',
      message: map['message'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
      edited: map['edited'] ?? false,
      editedAt: map['editedAt'],
      deleted: map['deleted'] ?? false,
      deletedAt: map['deletedAt'],
      originalMessage: map['originalMessage'],
    );
  }

  // Helper method to check if message can be edited (e.g., within 30 minutes)
  bool canEdit() {
    if (deleted) return false;

    final messageTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(messageTime);
    return difference.inMinutes <= 30; // 30-minute edit window
  }

  // Helper method to check if message can be deleted
  bool canDelete() {
    return !deleted;
  }

  // Create a copy with updated fields for editing
  Message copyWith({
    String? message,
    bool? edited,
    Timestamp? editedAt,
    bool? deleted,
    Timestamp? deletedAt,
    String? originalMessage,
  }) {
    return Message(
      senderID: senderID,
      senderEmail: senderEmail,
      receiverID: receiverID,
      message: message ?? this.message,
      timestamp: timestamp,
      metadata: metadata,
      edited: edited ?? this.edited,
      editedAt: editedAt ?? this.editedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      originalMessage: originalMessage ?? this.originalMessage,
    );
  }

  // Create a deleted version of the message
  Message markAsDeleted() {
    return copyWith(
      deleted: true,
      deletedAt: Timestamp.now(),
      originalMessage: message, // Store original message before deletion
      message: 'This message was deleted',
    );
  }

  // Create an edited version of the message
  Message markAsEdited(String newMessage) {
    return copyWith(
      message: newMessage,
      edited: true,
      editedAt: Timestamp.now(),
    );
  }

  // Check if this is a system message
  bool get isSystemMessage => senderID == 'system';

  // Check if this is a verification code message
  bool get isVerificationCode =>
      metadata != null && metadata!['type'] == 'verification_code';

  @override
  String toString() {
    return 'Message{senderID: $senderID, message: $message, edited: $edited, deleted: $deleted}';
  }
}
