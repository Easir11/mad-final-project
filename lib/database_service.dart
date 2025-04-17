import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/models/post.dart';
import 'package:myapp/models/users.dart';
import 'package:myapp/models/like.dart';
import 'package:myapp/models/comment.dart';

class DatabaseService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Save user info to Firestore
  Future<void> saveUserInfo(String name, String email) async {
    try {
      // Get current uid - Add checking to ensure currentUser isn't null
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print("No current user found when trying to save user info");
        throw Exception("No authenticated user found");
      }

      String uid = currentUser.uid;
      print("Saving data for user with UID: $uid");

      // Extract username from email
      String username = email.split('@')[0];

      // Create a user profile
      UserProfile user = UserProfile(
        uid: uid,
        name: name,
        email: email,
        username: username,
        bio: '',
      );

      final userMap = user.toMap();
      print("Attempting to save user data: $userMap");

      // Set the user document with the uid as the document ID
      await _db.collection('users').doc(uid).set(userMap);
      print("User data saved successfully to Firestore");
    } catch (e) {
      print("Error in saveUserInfo: $e");
      // Rethrow to handle in the UI
      rethrow;
    }
  }

  // Get User Info
  Future<UserProfile?> getUserFromFirebase(String uid) async {
    try {
      DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        print("No user document found with UID: $uid");
        return null;
      }

      return UserProfile.fromDocument(userDoc);
    } catch (e) {
      print("Error retrieving user from Firebase: $e");
      return null;
    }
  }

  // Get username by user ID
  Future<String> getUserDisplayName(String uid) async {
    try {
      DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        return "Easir Arafat";
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      return userData['name'] ?? "Easir Arafat";
    } catch (e) {
      print("Error retrieving username: $e");
      return "Easir Arafat";
    }
  }

  // Save a new post to Firestore
  Future<void> createPost(String userId, String content,
      {String? imageUrl}) async {
    try {
      final post = Post(
        id: '',
        userId: userId,
        content: content,
        imageUrl: imageUrl,
        createdAt: Timestamp.now(),
      );

      await _db.collection('posts').add(post.toMap());
      print("Post created successfully");
    } catch (e) {
      print("Error creating post: $e");
      rethrow;
    }
  }

  // Retrieve all posts
  Future<List<Post>> getAllPosts() async {
    try {
      final querySnapshot = await _db
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .get();
      return querySnapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
    } catch (e) {
      print("Error fetching posts: $e");
      rethrow;
    }
  }

  // Update a post's content
  Future<void> updatePost(String postId, String newContent) async {
    try {
      await _db.collection('posts').doc(postId).update({'content': newContent});
      print("Post updated successfully");
    } catch (e) {
      print("Error updating post: $e");
      rethrow;
    }
  }

  // Delete a post
  Future<void> deletePost(String postId) async {
    try {
      await _db.collection('posts').doc(postId).delete();
      print("Post deleted successfully");
    } catch (e) {
      print("Error deleting post: $e");
      rethrow;
    }
  }

  // LIKE FUNCTIONS

  // Like a post - with enhanced validation to ensure one like per user
  Future<void> likePost(String postId, String userId) async {
    try {
      // Create a unique ID for the like based on postId and userId to enforce one like per user per post
      final String likeId = '$postId-$userId';

      // Check if the user has already liked the post
      final likeDoc = await _db.collection('likes').doc(likeId).get();

      if (!likeDoc.exists) {
        // User hasn't liked the post yet, create a new like
        final like = Like(
          id: likeId, // Using the composite key as the document ID
          postId: postId,
          userId: userId,
          createdAt: Timestamp.now(),
        );

        // Save the like with the composite ID as the document ID
        await _db.collection('likes').doc(likeId).set(like.toMap());
        print("Post liked successfully");
      } else {
        print("User has already liked this post");
      }
    } catch (e) {
      print("Error liking post: $e");
      rethrow;
    }
  }

  // Unlike a post - using the composite ID
  Future<void> unlikePost(String postId, String userId) async {
    try {
      // Create the composite like ID
      final String likeId = '$postId-$userId';

      // Delete the like document directly using its ID
      await _db.collection('likes').doc(likeId).delete();
      print("Post unliked successfully");
    } catch (e) {
      print("Error unliking post: $e");
      rethrow;
    }
  }

  // Check if user liked a post - using the composite ID
  Future<bool> hasUserLikedPost(String postId, String userId) async {
    try {
      // Create the composite like ID
      final String likeId = '$postId-$userId';

      // Check if the like document exists
      final docSnapshot = await _db.collection('likes').doc(likeId).get();
      return docSnapshot.exists;
    } catch (e) {
      print("Error checking if user liked post: $e");
      return false;
    }
  }

  // Get like count for a post
  Future<int> getLikeCount(String postId) async {
    try {
      final querySnapshot = await _db
          .collection('likes')
          .where('postId', isEqualTo: postId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print("Error getting like count: $e");
      return 0;
    }
  }

  // Stream of likes for a post
  Stream<QuerySnapshot> getLikesStream(String postId) {
    return _db
        .collection('likes')
        .where('postId', isEqualTo: postId)
        .snapshots();
  }

  // COMMENT FUNCTIONS

  // Add a comment to a post
  Future<void> addComment(String postId, String userId, String content) async {
    try {
      // Get user display name
      String userDisplayName = await getUserDisplayName(userId);

      final comment = Comment(
        id: '',
        postId: postId,
        userId: userId,
        content: content,
        userDisplayName: userDisplayName,
        createdAt: Timestamp.now(),
      );

      await _db.collection('comments').add(comment.toMap());
      print("Comment added successfully");
    } catch (e) {
      print("Error adding comment: $e");
      rethrow;
    }
  }

  // Get comments for a post
  Future<List<Comment>> getCommentsForPost(String postId) async {
    try {
      final querySnapshot = await _db
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: false) // Oldest first
          .get();

      return querySnapshot.docs
          .map((doc) => Comment.fromDocument(doc))
          .toList();
    } catch (e) {
      print("Error fetching comments: $e");
      return [];
    }
  }

  // Stream of comments for a post
  Stream<QuerySnapshot> getCommentsStream(String postId) {
    return _db
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // Delete a comment
  Future<void> deleteComment(String commentId) async {
    try {
      await _db.collection('comments').doc(commentId).delete();
      print("Comment deleted successfully");
    } catch (e) {
      print("Error deleting comment: $e");
      rethrow;
    }
  }

  // Get comment count for a post
  Future<int> getCommentCount(String postId) async {
    try {
      final querySnapshot = await _db
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print("Error getting comment count: $e");
      return 0;
    }
  }

  Future<void> followUser(String followerId, String followedId) async {
    try {
      // Create a unique ID for the follow relationship
      final String followId = '$followerId-$followedId';

      // Check if already following
      final followDoc = await _db.collection('follows').doc(followId).get();

      if (!followDoc.exists) {
        // Create follow document
        await _db.collection('follows').doc(followId).set({
          'followerId': followerId,
          'followedId': followedId,
          'createdAt': Timestamp.now(),
        });
        print("User followed successfully");
      } else {
        print("Already following this user");
      }
    } catch (e) {
      print("Error following user: $e");
      rethrow;
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String followerId, String followedId) async {
    try {
      // Create the composite follow ID
      final String followId = '$followerId-$followedId';

      // Delete the follow document
      await _db.collection('follows').doc(followId).delete();
      print("User unfollowed successfully");
    } catch (e) {
      print("Error unfollowing user: $e");
      rethrow;
    }
  }

  // Check if user is following another user
  Future<bool> isFollowing(String followerId, String followedId) async {
    try {
      // Create the composite follow ID
      final String followId = '$followerId-$followedId';

      // Check if the follow document exists
      final docSnapshot = await _db.collection('follows').doc(followId).get();
      return docSnapshot.exists;
    } catch (e) {
      print("Error checking follow status: $e");
      return false;
    }
  }

  // Get followers count
  Future<int> getFollowersCount(String userId) async {
    try {
      final querySnapshot = await _db
          .collection('follows')
          .where('followedId', isEqualTo: userId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print("Error getting followers count: $e");
      return 0;
    }
  }

  // Get following count
  Future<int> getFollowingCount(String userId) async {
    try {
      final querySnapshot = await _db
          .collection('follows')
          .where('followerId', isEqualTo: userId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print("Error getting following count: $e");
      return 0;
    }
  }

  // Get followers list
  Future<List<String>> getFollowersList(String userId) async {
    try {
      final querySnapshot = await _db
          .collection('follows')
          .where('followedId', isEqualTo: userId)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data()['followerId'] as String)
          .toList();
    } catch (e) {
      print("Error getting followers list: $e");
      return [];
    }
  }

  // Get following list
  Future<List<String>> getFollowingList(String userId) async {
    try {
      final querySnapshot = await _db
          .collection('follows')
          .where('followerId', isEqualTo: userId)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data()['followedId'] as String)
          .toList();
    } catch (e) {
      print("Error getting following list: $e");
      return [];
    }
  }

  // BLOCK FUNCTIONS

  // Block a user with improved error handling
  Future<void> blockUser(String blockerId, String blockedId) async {
    if (blockerId == blockedId) {
      throw Exception("You cannot block yourself");
    }

    try {
      // Create a unique ID for the block relationship
      final String blockId = '$blockerId-$blockedId';

      // Check if already blocked
      final blockDoc = await _db.collection('blocks').doc(blockId).get();

      if (!blockDoc.exists) {
        // Start a batch write for atomic operations
        WriteBatch batch = _db.batch();

        // Create block document
        batch.set(_db.collection('blocks').doc(blockId), {
          'blockerId': blockerId,
          'blockedId': blockedId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Check if the users were following each other
        final followId1 = '$blockerId-$blockedId';
        final followId2 = '$blockedId-$blockerId';

        final followDoc1 = await _db.collection('follows').doc(followId1).get();
        final followDoc2 = await _db.collection('follows').doc(followId2).get();

        // Remove follow relationships if they exist
        if (followDoc1.exists) {
          batch.delete(_db.collection('follows').doc(followId1));
        }

        if (followDoc2.exists) {
          batch.delete(_db.collection('follows').doc(followId2));
        }

        // Commit the batch
        await batch.commit();

        print("User blocked successfully");
      } else {
        print("Already blocking this user");
      }
    } catch (e) {
      print("Error blocking user: $e");
      rethrow;
    }
  }

  // Unblock a user
  Future<void> unblockUser(String blockerId, String blockedId) async {
    try {
      // Create the composite block ID
      final String blockId = '$blockerId-$blockedId';

      // Delete the block document
      await _db.collection('blocks').doc(blockId).delete();
      print("User unblocked successfully");
    } catch (e) {
      print("Error unblocking user: $e");
      rethrow;
    }
  }

  // Check if user is blocked
  Future<bool> isUserBlocked(String blockerId, String blockedId) async {
    try {
      // Create the composite block ID
      final String blockId = '$blockerId-$blockedId';

      // Check if the block document exists
      final docSnapshot = await _db.collection('blocks').doc(blockId).get();
      return docSnapshot.exists;
    } catch (e) {
      print("Error checking block status: $e");
      return false;
    }
  }

  // Get blocked users list
  Future<List<String>> getBlockedUsersList(String userId) async {
    try {
      final querySnapshot = await _db
          .collection('blocks')
          .where('blockerId', isEqualTo: userId)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data()['blockedId'] as String)
          .toList();
    } catch (e) {
      print("Error getting blocked users list: $e");
      return [];
    }
  }

  // HELPER FUNCTIONS

  // Filter posts to exclude those from blocked users
  Future<List<Post>> getPostsExcludingBlockedUsers(String userId) async {
    try {
      // Get list of blocked users
      List<String> blockedUsers = await getBlockedUsersList(userId);

      // If no blocked users, just get all posts
      if (blockedUsers.isEmpty) {
        final querySnapshot = await _db
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .get();

        return querySnapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
      }

      // Firebase "where not-in" has a limit of 10 values
      // If more than 10 blocked users, we need to filter in memory
      if (blockedUsers.length > 10) {
        // Get all posts
        final querySnapshot = await _db
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .get();

        // Filter in memory
        return querySnapshot.docs
            .map((doc) => Post.fromDocument(doc))
            .where((post) => !blockedUsers.contains(post.userId))
            .toList();
      } else {
        // We can use "where not-in" query
        final querySnapshot = await _db
            .collection('posts')
            .where('userId', whereNotIn: blockedUsers)
            .orderBy('createdAt', descending: true)
            .get();

        return querySnapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
      }
    } catch (e) {
      print("Error fetching filtered posts: $e");
      // If there's an error, fall back to filtering in memory
      try {
        List<String> blockedUsers = await getBlockedUsersList(userId);
        final querySnapshot = await _db
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .get();

        return querySnapshot.docs
            .map((doc) => Post.fromDocument(doc))
            .where((post) => !blockedUsers.contains(post.userId))
            .toList();
      } catch (fallbackError) {
        print("Error in fallback filtering: $fallbackError");
        rethrow;
      }
    }
  }

  // Get only posts from followed users
  Future<List<Post>> getPostsFromFollowedUsers(String userId) async {
    try {
      // Get list of followed users
      List<String> followedUsers = await getFollowingList(userId);

      // Include the user's own ID to see their posts too
      followedUsers.add(userId);

      // Get posts for these users
      final querySnapshot = await _db
          .collection('posts')
          .where('userId', whereIn: followedUsers)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
    } catch (e) {
      print("Error fetching posts from followed users: $e");
      return [];
    }
  }
}
