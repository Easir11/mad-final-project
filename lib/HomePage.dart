import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/database_service.dart';
import 'package:myapp/models/post.dart';
import 'package:myapp/models/comment.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final _postController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _commentControllers = <String, TextEditingController>{};

  List<Post> _posts = [];
  bool _isLoading = false;
  final Map<String, bool> _expandedComments = {};
  final Map<String, List<Comment>> _comments = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, bool> _userLikes = {};
  final Map<String, bool> _userFollows = {};
  final Map<String, String> _userDisplayNames = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadPosts();
  }

  @override
  void dispose() {
    _postController.dispose();
    _imageUrlController.dispose();
    _commentControllers.forEach((_, controller) => controller.dispose());
    _tabController.dispose();
    super.dispose();
  }

  TextEditingController _getCommentController(String postId) {
    if (!_commentControllers.containsKey(postId)) {
      _commentControllers[postId] = TextEditingController();
    }
    return _commentControllers[postId]!;
  }

  Future<void> _loadPosts() async {
    // Set a timeout to ensure loading state doesn't get stuck
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      List<Post> posts =
          await _dbService.getPostsExcludingBlockedUsers(currentUser.uid);

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });

        for (var post in posts) {
          _loadLikesAndComments(post.id, currentUser.uid);
          _loadUserDetails(post.userId, currentUser.uid);
        }
      }
    } catch (e) {
      print("Failed to load posts: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLikesAndComments(String postId, String userId) async {
    final likeCount = await _dbService.getLikeCount(postId);
    bool hasLiked = await _dbService.hasUserLikedPost(postId, userId);

    // We no longer fetch comments from Firebase
    // Initialize empty comments array if not already present
    if (!_comments.containsKey(postId)) {
      _comments[postId] = [];
    }

    if (mounted) {
      setState(() {
        _likeCounts[postId] = likeCount;
        _userLikes[postId] = hasLiked;
      });
    }
  }

  Future<void> _loadUserDetails(String postUserId, String currentUserId) async {
    if (!_userDisplayNames.containsKey(postUserId)) {
      final displayName = await _dbService.getUserDisplayName(postUserId);

      if (mounted) {
        setState(() {
          _userDisplayNames[postUserId] = displayName;
        });
      }
    }

    if (!_userFollows.containsKey(postUserId) && postUserId != currentUserId) {
      final isFollowing = await _dbService.isFollowing(
        currentUserId,
        postUserId,
      );

      if (mounted) {
        setState(() {
          _userFollows[postUserId] = isFollowing;
        });
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Please wait..."),
            ],
          ),
        );
      },
    );
  }

  void _dismissLoadingDialog() {
    try {
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      print("Error dismissing dialog: $e");
      // The dialog might already be dismissed or the context is no longer valid
    }
  }

  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      _showLoadingDialog();

      await _dbService.createPost(
        user.uid,
        _postController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isNotEmpty
            ? _imageUrlController.text.trim()
            : null,
      );

      _dismissLoadingDialog();

      _postController.clear();
      _imageUrlController.clear();
      await _loadPosts();
    } catch (e) {
      _dismissLoadingDialog();

      print("Error posting: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create post: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleLike(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool previousLikeStatus = _userLikes[postId] ?? false;
    int previousLikeCount = _likeCounts[postId] ?? 0;

    setState(() {
      _userLikes[postId] = !previousLikeStatus;
      _likeCounts[postId] = previousLikeStatus
          ? (previousLikeCount > 0 ? previousLikeCount - 1 : 0)
          : previousLikeCount + 1;
    });

    try {
      if (previousLikeStatus) {
        await _dbService.unlikePost(postId, user.uid);
      } else {
        await _dbService.likePost(postId, user.uid);
      }
    } catch (e) {
      print("Error toggling like: $e");

      if (mounted) {
        setState(() {
          _userLikes[postId] = previousLikeStatus;
          _likeCounts[postId] = previousLikeCount;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update like: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleFollow(String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      bool isFollowing = _userFollows[userId] ?? false;

      if (isFollowing) {
        await _dbService.unfollowUser(currentUser.uid, userId);
        if (mounted) {
          setState(() {
            _userFollows[userId] = false;
          });
        }
      } else {
        await _dbService.followUser(currentUser.uid, userId);
        if (mounted) {
          setState(() {
            _userFollows[userId] = true;
          });
        }
      }
    } catch (e) {
      print("Error toggling follow: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update follow status: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _blockUser(String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      bool confirmBlock = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Block User'),
              content: const Text(
                'Are you sure you want to block this user? You will no longer see their posts or interactions.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Block'),
                ),
              ],
            ),
          ) ??
          false;

      if (confirmBlock) {
        _showLoadingDialog();

        // Block the user
        await _dbService.blockUser(currentUser.uid, userId);

        // Immediately remove posts from the blocked user
        setState(() {
          _posts = _posts.where((post) => post.userId != userId).toList();
        });

        // Also reload all posts to ensure we get a clean slate
        await _loadPosts();

        _dismissLoadingDialog();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User blocked successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _dismissLoadingDialog();

      print("Error blocking user: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to block user: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _addComment(String postId) async {
    final commentController = _getCommentController(postId);
    if (commentController.text.trim().isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Store comment text before clearing
    final commentText = commentController.text.trim();

    try {
      // Create a new Comment object locally
      final newComment = Comment(
        id: DateTime.now()
            .millisecondsSinceEpoch
            .toString(), // Generate a unique ID
        postId: postId,
        userId: user.uid,
        content: commentText,
        userDisplayName: user.displayName ?? 'Easir Arafat',
        createdAt: Timestamp.now(),
      );

      // Add the comment directly to the local comments list
      if (mounted) {
        setState(() {
          if (!_comments.containsKey(postId)) {
            _comments[postId] = [];
          }
          _comments[postId]!.add(newComment);
          _expandedComments[postId] = true;
        });
      }

      // Clear the comment controller
      commentController.clear();

      // Show a success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print("Error adding comment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleCommentSection(String postId) {
    setState(() {
      _expandedComments[postId] = !(_expandedComments[postId] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Social Feed',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
            ),
          ),
          backgroundColor: colorScheme.primary,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            labelColor: colorScheme.onPrimary,
            unselectedLabelColor: colorScheme.onPrimary.withOpacity(0.6),
            indicatorColor: colorScheme.onPrimary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'For You', icon: Icon(Icons.public)),
            ],
            onTap: (index) {
              _loadPosts();
            },
          ),
          actions: [
            IconButton(
              onPressed: () {
                _showCreatePostDialog(context);
              },
              icon: const Icon(Icons.add_box_rounded, size: 28),
              tooltip: 'Create Post',
            ),
          ],
        ),
        drawer: Drawer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primary,
                  colorScheme.primaryContainer,
                ],
              ),
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.7),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white70,
                        child: Icon(Icons.person,
                            size: 40, color: Color(0xFF6A5ACD)),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        user?.displayName ?? 'Easir Arafat',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        user?.email ?? 'user@example.com',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                _buildDrawerItem(Icons.people, 'Following/Followers', () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/followers');
                }),
                _buildDrawerItem(Icons.block, 'Blocked Users', () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/blocked-users');
                }),
                _buildDrawerItem(Icons.settings, 'Settings', () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/settings');
                }),
                const Divider(color: Colors.white30, thickness: 1),
                _buildDrawerItem(Icons.logout, 'Logout', () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                }),
              ],
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadPosts,
          child: _posts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 16),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    return FadeInUp(
                      delay: Duration(milliseconds: 100 * index),
                      duration: const Duration(milliseconds: 500),
                      child: _buildPostCard(_posts[index]),
                    );
                  },
                ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreatePostDialog(context),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 4,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 16)),
      onTap: onTap,
      dense: true,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.forum_outlined,
              size: 80,
              color: Color(0xFF6A5ACD),
            ),
            const SizedBox(height: 20),
            Text(
              "No posts available at the moment",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF555555),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Be the first to share something with the community!",
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF777777),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showCreatePostDialog(context),
              icon: const Icon(Icons.add),
              label: const Text("Create New Post"),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Post',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _postController,
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  hintText: 'Add image URL (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _createPost();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Share Post'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostCard(Post post) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE0E0FF),
                  child: Icon(Icons.person, color: Color(0xFF6A5ACD)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userDisplayNames[post.userId] ?? 'Easir Arafat',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        timeago.format(post.createdAt.toDate()),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.userId != currentUser?.uid)
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'follow') {
                        _toggleFollow(post.userId);
                      } else if (value == 'block') {
                        _blockUser(post.userId);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'follow',
                        child: Row(
                          children: [
                            Icon(
                              (_userFollows[post.userId] ?? false)
                                  ? Icons.person_remove
                                  : Icons.person_add,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              (_userFollows[post.userId] ?? false)
                                  ? 'Unfollow'
                                  : 'Follow',
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(Icons.block),
                            SizedBox(width: 8),
                            Text('Block User'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Post content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post.content,
              style: const TextStyle(fontSize: 16),
            ),
          ),

          // Post image
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ClipRRect(
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 100,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.error)),
                  ),
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),

          // Like and comment counts
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(
                  Icons.favorite,
                  size: 16,
                  color: Colors.red[400],
                ),
                const SizedBox(width: 4),
                Text(
                  '${_likeCounts[post.id] ?? 0}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.mode_comment_outlined,
                  size: 16,
                  color: Colors.blue[400],
                ),
                const SizedBox(width: 4),
                Text(
                  '${(_comments[post.id]?.length ?? 0)}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () => _toggleLike(post.id),
                icon: Icon(
                  (_userLikes[post.id] ?? false)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: (_userLikes[post.id] ?? false) ? Colors.red : null,
                ),
                label: Text(
                  'Like',
                  style: TextStyle(
                    color: (_userLikes[post.id] ?? false)
                        ? Colors.red
                        : Colors.grey[700],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _toggleCommentSection(post.id),
                icon: const Icon(Icons.comment_outlined),
                label: const Text('Comment'),
              ),
            ],
          ),

          // Comments section
          if (_expandedComments[post.id] ?? false)
            Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFFE0E0FF),
                        child: Icon(Icons.person,
                            size: 18, color: Color(0xFF6A5ACD)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _getCommentController(post.id),
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _addComment(post.id),
                        icon: const Icon(Icons.send, color: Color(0xFF6A5ACD)),
                      ),
                    ],
                  ),
                ),
                if (_comments.containsKey(post.id) &&
                    _comments[post.id]!.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _comments[post.id]!.length,
                    itemBuilder: (context, index) {
                      final comment = _comments[post.id]![index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 12,
                              backgroundColor: Color(0xFFE0E0FF),
                              child: Icon(Icons.person,
                                  size: 14, color: Color(0xFF6A5ACD)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          comment.userDisplayName ??
                                              'Easir Arafat',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          timeago.format(
                                              comment.createdAt.toDate()),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      comment.content,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No comments yet. Be the first to comment!',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
              ],
            ),
        ],
      ),
    );
  }
}
