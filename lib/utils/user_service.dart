import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/users.dart';
import 'package:myapp/utils/firebase_service.dart';
import 'dart:io';

class UserService {
  // Singleton pattern
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();

  // Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final String? userId = _firebaseService.currentUserId;
    if (userId == null) {
      return null;
    }
    return await _firebaseService.getUserProfile(userId);
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? name,
    String? bio,
    File? profileImage,
  }) async {
    try {
      final String? userId = _firebaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (bio != null) updateData['bio'] = bio;

      if (profileImage != null) {
        // Upload profile image and get URL
        final String imageUrl = await _firebaseService.uploadProfileImage(
          userId,
          profileImage,
        );
        updateData['profileImageUrl'] = imageUrl;
      }

      await _firebaseService.updateUserProfile(userId, updateData);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Follow a user
  Future<void> followUser(String targetUserId) async {
    try {
      final String? currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      if (currentUserId == targetUserId) {
        throw Exception('You cannot follow yourself');
      }

      // Create a unique ID for the follow relationship
      final String followId = '$currentUserId-$targetUserId';

      // Check if already following
      final followDoc =
          await _firestore.collection('follows').doc(followId).get();
      if (followDoc.exists) {
        return; // Already following
      }

      // Create follow document
      await _firestore.collection('follows').doc(followId).set({
        'followerId': currentUserId,
        'followedId': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error following user: $e');
      rethrow;
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String targetUserId) async {
    try {
      final String? currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Create the composite follow ID
      final String followId = '$currentUserId-$targetUserId';

      // Delete the follow document
      await _firestore.collection('follows').doc(followId).delete();
    } catch (e) {
      print('Error unfollowing user: $e');
      rethrow;
    }
  }

  // Check if current user is following another user
  Future<bool> isFollowingUser(String targetUserId) async {
    try {
      final String? currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) {
        return false;
      }

      // Create the composite follow ID
      final String followId = '$currentUserId-$targetUserId';

      // Check if the follow document exists
      final docSnapshot =
          await _firestore.collection('follows').doc(followId).get();
      return docSnapshot.exists;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  // Get followers count
  Future<int> getFollowersCount(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('follows')
          .where('followedId', isEqualTo: userId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting followers count: $e');
      return 0;
    }
  }

  // Get following count
  Future<int> getFollowingCount(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: userId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting following count: $e');
      return 0;
    }
  }

  // Get followers list with user profiles
  Future<List<UserProfile>> getFollowers(String userId) async {
    try {
      // Get followers IDs
      final querySnapshot = await _firestore
          .collection('follows')
          .where('followedId', isEqualTo: userId)
          .get();

      final List<String> followerIds = querySnapshot.docs
          .map((doc) => doc.data()['followerId'] as String)
          .toList();

      // Fetch user profiles for each follower
      final List<UserProfile> followers = [];
      for (String followerId in followerIds) {
        final userProfile = await _firebaseService.getUserProfile(followerId);
        if (userProfile != null) {
          followers.add(userProfile);
        }
      }

      return followers;
    } catch (e) {
      print('Error getting followers: $e');
      return [];
    }
  }

  // Get following list with user profiles
  Future<List<UserProfile>> getFollowing(String userId) async {
    try {
      // Get following IDs
      final querySnapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: userId)
          .get();

      final List<String> followingIds = querySnapshot.docs
          .map((doc) => doc.data()['followedId'] as String)
          .toList();

      // Fetch user profiles for each following
      final List<UserProfile> following = [];
      for (String followingId in followingIds) {
        final userProfile = await _firebaseService.getUserProfile(followingId);
        if (userProfile != null) {
          following.add(userProfile);
        }
      }

      return following;
    } catch (e) {
      print('Error getting following: $e');
      return [];
    }
  }

  // Block a user
  Future<void> blockUser(String targetUserId) async {
    try {
      final String? currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      if (currentUserId == targetUserId) {
        throw Exception('You cannot block yourself');
      }

      // Create a unique ID for the block relationship
      final String blockId = '$currentUserId-$targetUserId';

      // Check if already blocked
      final blockDoc = await _firestore.collection('blocks').doc(blockId).get();
      if (blockDoc.exists) {
        return; // Already blocked
      }

      // Start a batch write for atomic operations
      WriteBatch batch = _firestore.batch();

      // Create block document
      batch.set(_firestore.collection('blocks').doc(blockId), {
        'blockerId': currentUserId,
        'blockedId': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Check if the users were following each other
      final followId1 = '$currentUserId-$targetUserId';
      final followId2 = '$targetUserId-$currentUserId';

      final followDoc1 =
          await _firestore.collection('follows').doc(followId1).get();
      final followDoc2 =
          await _firestore.collection('follows').doc(followId2).get();

      // Remove follow relationships if they exist
      if (followDoc1.exists) {
        batch.delete(_firestore.collection('follows').doc(followId1));
      }

      if (followDoc2.exists) {
        batch.delete(_firestore.collection('follows').doc(followId2));
      }

      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error blocking user: $e');
      rethrow;
    }
  }

  // Unblock a user
  Future<void> unblockUser(String targetUserId) async {
    try {
      final String? currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Create the composite block ID
      final String blockId = '$currentUserId-$targetUserId';

      // Delete the block document
      await _firestore.collection('blocks').doc(blockId).delete();
    } catch (e) {
      print('Error unblocking user: $e');
      rethrow;
    }
  }

  // Check if current user has blocked another user
  Future<bool> hasBlockedUser(String targetUserId) async {
    try {
      final String? currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) {
        return false;
      }

      // Create the composite block ID
      final String blockId = '$currentUserId-$targetUserId';

      // Check if the block document exists
      final docSnapshot =
          await _firestore.collection('blocks').doc(blockId).get();
      return docSnapshot.exists;
    } catch (e) {
      print('Error checking block status: $e');
      return false;
    }
  }

  // Get blocked users
  Future<List<UserProfile>> getBlockedUsers() async {
    try {
      final String? currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) {
        return [];
      }

      // Get blocked user IDs
      final querySnapshot = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: currentUserId)
          .get();

      final List<String> blockedUserIds = querySnapshot.docs
          .map((doc) => doc.data()['blockedId'] as String)
          .toList();

      // Fetch user profiles for each blocked user
      final List<UserProfile> blockedUsers = [];
      for (String blockedUserId in blockedUserIds) {
        final userProfile =
            await _firebaseService.getUserProfile(blockedUserId);
        if (userProfile != null) {
          blockedUsers.add(userProfile);
        }
      }

      return blockedUsers;
    } catch (e) {
      print('Error getting blocked users: $e');
      return [];
    }
  }

  // Search for users by name or username
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      // Search for users whose name or username contains the query (case insensitive)
      final querySnapshot = await _firestore.collection('users').get();

      final String lowercaseQuery = query.toLowerCase();

      final List<UserProfile> matchingUsers = querySnapshot.docs
          .map((doc) => UserProfile.fromDocument(doc))
          .where((user) {
        final String nameLC = user.name.toLowerCase();
        final String usernameLC = user.username.toLowerCase();
        return nameLC.contains(lowercaseQuery) ||
            usernameLC.contains(lowercaseQuery);
      }).toList();

      return matchingUsers;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Listen for real-time updates to a user's profile
  Stream<UserProfile?> userProfileStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromDocument(doc) : null);
  }
}
