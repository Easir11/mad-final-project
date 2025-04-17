import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/database_service.dart';
import 'package:myapp/models/users.dart';
import 'package:myapp/utils/dialog_utils.dart';

class FollowersPage extends StatefulWidget {
  const FollowersPage({super.key});

  @override
  State<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late TabController _tabController;
  List<UserProfile> _followers = [];
  List<UserProfile> _following = [];
  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;
  final Map<String, bool> _userFollows = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Check if we have arguments for tab index
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arguments =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (arguments != null && arguments.containsKey('tabIndex')) {
        _tabController.animateTo(arguments['tabIndex']);
      }
    });

    _loadFollowersAndFollowing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowersAndFollowing() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Load followers
      setState(() {
        _isLoadingFollowers = true;
      });

      final followerIds = await _dbService.getFollowersList(user.uid);
      _followers = await _fetchUserProfiles(followerIds);

      setState(() {
        _isLoadingFollowers = false;
      });

      // Load following
      setState(() {
        _isLoadingFollowing = true;
      });

      final followingIds = await _dbService.getFollowingList(user.uid);
      _following = await _fetchUserProfiles(followingIds);

      // Initialize user follows map
      for (var followedUser in _following) {
        _userFollows[followedUser.uid] = true;
      }

      setState(() {
        _isLoadingFollowing = false;
      });
    } catch (e) {
      print("Error loading followers/following: $e");
      setState(() {
        _isLoadingFollowers = false;
        _isLoadingFollowing = false;
      });
    }
  }

  Future<List<UserProfile>> _fetchUserProfiles(List<String> userIds) async {
    List<UserProfile> profiles = [];

    for (String userId in userIds) {
      try {
        final profile = await _dbService.getUserFromFirebase(userId);
        if (profile != null) {
          profiles.add(profile);
        }
      } catch (e) {
        print("Error fetching user profile for $userId: $e");
      }
    }

    return profiles;
  }

  Future<void> _toggleFollow(String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Optimistic UI update
    bool wasFollowing = _userFollows[userId] ?? false;
    setState(() {
      _userFollows[userId] = !wasFollowing;
    });

    try {
      if (wasFollowing) {
        await _dbService.unfollowUser(currentUser.uid, userId);
      } else {
        await _dbService.followUser(currentUser.uid, userId);
      }
    } catch (e) {
      // Revert if there was an error
      setState(() {
        _userFollows[userId] = wasFollowing;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update follow status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Followers & Following',
          style: TextStyle(color: colorScheme.onPrimary),
        ),
        backgroundColor: colorScheme.primary,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.onPrimary,
          unselectedLabelColor: colorScheme.onPrimary.withOpacity(0.6),
          indicatorColor: colorScheme.onPrimary,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Followers tab
          _isLoadingFollowers
              ? const Center(child: CircularProgressIndicator())
              : _followers.isEmpty
                  ? _buildEmptyState('No followers yet')
                  : ListView.builder(
                      itemCount: _followers.length,
                      itemBuilder: (context, index) {
                        final follower = _followers[index];
                        return _buildUserListItem(follower);
                      },
                    ),

          // Following tab
          _isLoadingFollowing
              ? const Center(child: CircularProgressIndicator())
              : _following.isEmpty
                  ? _buildEmptyState('You\'re not following anyone yet')
                  : ListView.builder(
                      itemCount: _following.length,
                      itemBuilder: (context, index) {
                        final following = _following[index];
                        return _buildUserListItem(
                          following,
                          showFollowButton: true,
                          isFollowing: _userFollows[following.uid] ?? false,
                          onFollowToggle: () => _toggleFollow(following.uid),
                        );
                      },
                    ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListItem(
    UserProfile user, {
    bool showFollowButton = false,
    bool isFollowing = false,
    VoidCallback? onFollowToggle,
  }) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE0E0FF),
        child: Icon(Icons.person, color: Color(0xFF6A5ACD)),
      ),
      title: Text(
        user.name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text('@${user.username}'),
      trailing: showFollowButton
          ? ElevatedButton(
              onPressed: onFollowToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isFollowing ? Colors.grey[200] : const Color(0xFF6A5ACD),
                foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                minimumSize: const Size(100, 36),
              ),
              child: Text(isFollowing ? 'Unfollow' : 'Follow'),
            )
          : null,
    );
  }
}
