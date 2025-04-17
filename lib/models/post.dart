import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id; // Unique identifier for the post
  final String userId; // ID of the user who created the post
  final String content; // Main content of the post
  final String? imageUrl; // Optional image URL
  final Timestamp createdAt; // Timestamp for when the post was created
  final int likeCount; // Number of likes
  final int commentCount; // Number of comments

  Post({
    required this.id,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  // Factory constructor to create a Post object from Firestore document
  factory Post.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
    );
  }

  // Convert Post object to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': likeCount,
      'commentCount': commentCount,
    };
  }
}
