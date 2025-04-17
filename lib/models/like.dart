import 'package:cloud_firestore/cloud_firestore.dart';

class Like {
  final String id;
  final String postId;
  final String userId;
  final Timestamp createdAt;

  Like({
    required this.id,
    required this.postId,
    required this.userId,
    required this.createdAt,
  });

  // Factory constructor to create a Like object from Firestore document
  factory Like.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Like(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  // Convert Like object to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}