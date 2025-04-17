import 'dart:io';
import 'package:flutter/material.dart';
import 'package:myapp/models/users.dart';
import 'package:myapp/models/post.dart';
import 'package:myapp/utils/firebase_service.dart';
import 'package:myapp/utils/post_service.dart';
import 'package:myapp/utils/user_service.dart';

class AppState with ChangeNotifier {
  final FirebaseService _firebaseService;
  final PostService _postService;
  final UserService _userService;

  // User state
  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Post state
  List<Post> _feedPosts = [];
  bool _isLoadingPosts = false;

  AppState({
    required FirebaseService firebaseService,
    required PostService postService,
    required UserService userService,
  })  : _firebaseService = firebaseService,
        _postService = postService,
        _userService = userService {
    // Initialize the app state
    _initialize();
  }

  // Getters
  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Post> get feedPosts => _feedPosts;
  bool get isLoadingPosts => _isLoadingPosts;
  bool get isLoggedIn => _firebaseService.currentUser != null;

  // Initialize app state
  Future<void> _initialize() async {
    if (_firebaseService.currentUser != null) {
      await loadCurrentUser();
      await loadFeedPosts();
    }

    // Listen for auth state changes
    _firebaseService.authStateChanges.listen((user) async {
      if (user != null) {
        await loadCurrentUser();
        await loadFeedPosts();
      } else {
        _currentUser = null;
        _feedPosts = [];
        notifyListeners();
      }
    });
  }

  // Load current user profile
  Future<void> loadCurrentUser() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userProfile = await _userService.getCurrentUserProfile();
      _currentUser = userProfile;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load user profile: ${e.toString()}';
      notifyListeners();
    }
  }

  // Load feed posts
  Future<void> loadFeedPosts() async {
    _isLoadingPosts = true;
    notifyListeners();

    try {
      final posts = await _postService.getFeedPosts();
      _feedPosts = posts;
      _isLoadingPosts = false;
      notifyListeners();
    } catch (e) {
      _isLoadingPosts = false;
      _errorMessage = 'Failed to load posts: ${e.toString()}';
      notifyListeners();
    }
  }

  // Create a new post
  Future<void> createPost(String content, {File? imageFile}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _postService.createPost(content, imageFile: imageFile);
      _isLoading = false;
      // Reload feed posts after creating a new post
      await loadFeedPosts();
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to create post: ${e.toString()}';
      notifyListeners();
    }
  }

  // Update user profile
  Future<void> updateProfile({
    String? name,
    String? bio,
    File? profileImage,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _userService.updateUserProfile(
        name: name,
        bio: bio,
        profileImage: profileImage,
      );
      _isLoading = false;
      // Reload current user after updating profile
      await loadCurrentUser();
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to update profile: ${e.toString()}';
      notifyListeners();
    }
  }

  // Like a post
  Future<void> likePost(String postId) async {
    try {
      await _postService.likePost(postId);

      // Update the post in the feed
      final index = _feedPosts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        final updatedPost = Post(
          id: _feedPosts[index].id,
          userId: _feedPosts[index].userId,
          content: _feedPosts[index].content,
          imageUrl: _feedPosts[index].imageUrl,
          createdAt: _feedPosts[index].createdAt,
          likeCount: _feedPosts[index].likeCount + 1,
          commentCount: _feedPosts[index].commentCount,
        );

        _feedPosts[index] = updatedPost;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to like post: ${e.toString()}';
      notifyListeners();
    }
  }

  // Unlike a post
  Future<void> unlikePost(String postId) async {
    try {
      await _postService.unlikePost(postId);

      // Update the post in the feed
      final index = _feedPosts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        final updatedPost = Post(
          id: _feedPosts[index].id,
          userId: _feedPosts[index].userId,
          content: _feedPosts[index].content,
          imageUrl: _feedPosts[index].imageUrl,
          createdAt: _feedPosts[index].createdAt,
          likeCount: _feedPosts[index].likeCount - 1,
          commentCount: _feedPosts[index].commentCount,
        );

        _feedPosts[index] = updatedPost;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to unlike post: ${e.toString()}';
      notifyListeners();
    }
  }

  // Follow a user
  Future<void> followUser(String userId) async {
    try {
      await _userService.followUser(userId);
      // Refresh feed posts to include new user's posts
      await loadFeedPosts();
    } catch (e) {
      _errorMessage = 'Failed to follow user: ${e.toString()}';
      notifyListeners();
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String userId) async {
    try {
      await _userService.unfollowUser(userId);
      // Refresh feed posts to exclude unfollowed user's posts
      await loadFeedPosts();
    } catch (e) {
      _errorMessage = 'Failed to unfollow user: ${e.toString()}';
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _firebaseService.signOut();
      _currentUser = null;
      _feedPosts = [];
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to sign out: ${e.toString()}';
      notifyListeners();
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
