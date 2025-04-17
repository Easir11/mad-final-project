import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/post.dart';
import 'package:myapp/models/comment.dart';
import 'package:myapp/models/like.dart';
import 'package:myapp/utils/firebase_service.dart';
import 'dart:io';

class PostService {
  // Singleton pattern
  static final PostService _instance = PostService._internal();
  factory PostService() => _instance;
  PostService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();

  // Create a new post
  Future<String> createPost(String content, {File? imageFile}) async {
    try {
      final String? userId = _firebaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _firebaseService.uploadPostImage(userId, imageFile);
      }

      // Create post
      final postData = {
        'userId': userId,
        'content': content,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
      };

      // Add post to Firestore
      final docRef = await _firestore.collection('posts').add(postData);
      return docRef.id;
    } catch (e) {
      print('Error creating post: $e');
      rethrow;
    }
  }

  // Get all posts
  Future<List<Post>> getAllPosts() async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
    } catch (e) {
      print('Error getting posts: $e');
      return [];
    }
  }

  // Get posts for feed (posts from users the current user follows + own posts)
  Future<List<Post>> getFeedPosts() async {
    try {
      final String? userId = _firebaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get list of users the current user follows
      final followsSnapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: userId)
          .get();

      final List<String> followedUsers = followsSnapshot.docs
          .map((doc) => doc.data()['followedId'] as String)
          .toList();

      // Add current user to the list to see their own posts
      followedUsers.add(userId);

      // If the user doesn't follow anyone, just return their own posts
      if (followedUsers.length == 1) {
        final querySnapshot = await _firestore
            .collection('posts')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();

        return querySnapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
      }

      // Get posts from followed users
      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', whereIn: followedUsers)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
    } catch (e) {
      print('Error getting feed posts: $e');
      return [];
    }
  }

  // Get posts from a specific user
  Future<List<Post>> getUserPosts(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
    } catch (e) {
      print('Error getting user posts: $e');
      return [];
    }
  }

  // Delete a post
  Future<void> deletePost(String postId) async {
    try {
      // Get current user ID
      final String? userId = _firebaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get the post
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      if (postData['userId'] != userId) {
        throw Exception('Not authorized to delete this post');
      }

      // Start a batch write
      final batch = _firestore.batch();

      // Delete the post
      batch.delete(_firestore.collection('posts').doc(postId));

      // Delete related likes
      final likesSnapshot = await _firestore
          .collection('likes')
          .where('postId', isEqualTo: postId)
          .get();
      for (var doc in likesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete related comments
      final commentsSnapshot = await _firestore
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .get();
      for (var doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error deleting post: $e');
      rethrow;
    }
  }

  // Like a post
  Future<void> likePost(String postId) async {
    try {
      final String? userId = _firebaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create a unique ID for the like
      final String likeId = '$postId-$userId';

      // Check if the user has already liked the post
      final likeDoc = await _firestore.collection('likes').doc(likeId).get();
      if (likeDoc.exists) {
        return; // User already liked the post
      }

      // Start a batch write
      final batch = _firestore.batch();

      // Create the like
      batch.set(_firestore.collection('likes').doc(likeId), {
        'postId': postId,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Increment the like count on the post
      batch.update(_firestore.collection('posts').doc(postId), {
        'likeCount': FieldValue.increment(1),
      });

      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error liking post: $e');
      rethrow;
    }
  }

  // Unlike a post
  Future<void> unlikePost(String postId) async {
    try {
      final String? userId = _firebaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create the like ID
      final String likeId = '$postId-$userId';

      // Check if the like exists
      final likeDoc = await _firestore.collection('likes').doc(likeId).get();
      if (!likeDoc.exists) {
        return; // User hasn't liked the post
      }

      // Start a batch write
      final batch = _firestore.batch();

      // Delete the like
      batch.delete(_firestore.collection('likes').doc(likeId));

      // Decrement the like count on the post
      batch.update(_firestore.collection('posts').doc(postId), {
        'likeCount': FieldValue.increment(-1),
      });

      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error unliking post: $e');
      rethrow;
    }
  }

  // Check if user has liked a post
  Future<bool> hasUserLikedPost(String postId) async {
    try {
      final String? userId = _firebaseService.currentUserId;
      if (userId == null) {
        return false;
      }

      final String likeId = '$postId-$userId';
      final likeDoc = await _firestore.collection('likes').doc(likeId).get();
      return likeDoc.exists;
    } catch (e) {
      print('Error checking if user liked post: $e');
      return false;
    }
  }

  // Add a comment to a post
  Future<String> addComment(String postId, String content) async {
    try {
      final String? userId = _firebaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get user display name
      final userProfile = await _firebaseService.getUserProfile(userId);
      final userDisplayName = userProfile?.name ?? 'Unknown User';

      // Start a batch write
      final batch = _firestore.batch();

      // Create the comment
      final commentRef = _firestore.collection('comments').doc();
      batch.set(commentRef, {
        'postId': postId,
        'userId': userId,
        'content': content,
        'userDisplayName': userDisplayName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Increment the comment count on the post
      batch.update(_firestore.collection('posts').doc(postId), {
        'commentCount': FieldValue.increment(1),
      });

      // Commit the batch
      await batch.commit();
      return commentRef.id;
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  // Get comments for a post
  Future<List<Comment>> getCommentsForPost(String postId) async {
    try {
      final querySnapshot = await _firestore
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => Comment.fromDocument(doc))
          .toList();
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  // Stream of posts for real-time updates
  Stream<List<Post>> postsStream() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Post.fromDocument(doc)).toList());
  }

  // Stream of user posts for real-time updates
  Stream<List<Post>> userPostsStream(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Post.fromDocument(doc)).toList());
  }

  // Stream of comments for real-time updates
  Stream<List<Comment>> commentsStream(String postId) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Comment.fromDocument(doc)).toList());
  }
}
