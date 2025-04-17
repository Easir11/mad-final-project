import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final String? userDisplayName;
  final Timestamp createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    this.userDisplayName,
    required this.createdAt,
  });

  // Factory constructor to create a Comment object from Firestore document
  factory Comment.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      userDisplayName: data['userDisplayName'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  // Convert Comment object to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'content': content,
      'userDisplayName': userDisplayName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}