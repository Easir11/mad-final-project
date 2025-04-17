import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/database_service.dart';
import 'package:myapp/models/users.dart';
import 'package:myapp/models/post.dart';
import 'package:myapp/utils/dialog_utils.dart';

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({super.key});

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  final DatabaseService _dbService = DatabaseService();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _usernameController = TextEditingController();

  UserProfile? _userProfile;
  List<Post> _userPosts = [];
  bool _isLoading = true;
  bool _isEditing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to be logged in to view profile'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
        return;
      }

      final userProfile = await _dbService.getUserFromFirebase(user.uid);

      if (userProfile != null) {
        setState(() {
          _userProfile = userProfile;
          _nameController.text = userProfile.name;
          _bioController.text = userProfile.bio ?? '';
          _usernameController.text = userProfile.username!;
        });
      }

      // Load user posts
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _userPosts =
            querySnapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
        _postsCount = _userPosts.length;
      });

      // Get followers and following counts
      _followersCount = await _dbService.getFollowersCount(user.uid);
      _followingCount = await _dbService.getFollowingCount(user.uid);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name and username cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DialogUtils.showLoadingDialog(context, 'Updating profile...');

      // Check if username is already taken (except by current user)
      final usernameQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim())
          .get();

      bool usernameExists = false;
      for (var doc in usernameQuery.docs) {
        if (doc.id != user.uid) {
          usernameExists = true;
          break;
        }
      }

      if (usernameExists) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This username is already taken'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Update profile in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
      });

      // Update display name in Firebase Auth
      await user.updateDisplayName(_nameController.text.trim());

      Navigator.pop(context); // Dismiss loading dialog

      setState(() {
        _isEditing = false;
        _userProfile = UserProfile(
          uid: user.uid,
          name: _nameController.text.trim(),
          email: _userProfile?.email ?? user.email ?? '',
          username: _usernameController.text.trim(),
          bio: _bioController.text.trim(),
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: ${e.toString()}'),
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
          'Profile Details',
          style: TextStyle(color: colorScheme.onPrimary),
        ),
        backgroundColor: colorScheme.primary,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _updateProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Profile header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white70,
                          child: Icon(Icons.person,
                              size: 60, color: Color(0xFF6A5ACD)),
                        ),
                        const SizedBox(height: 16),
                        if (_isEditing)
                          Column(
                            children: [
                              TextField(
                                controller: _nameController,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 22),
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white54),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _usernameController,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  prefixText: '@',
                                  prefixStyle: TextStyle(color: Colors.white70),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white54),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              Text(
                                _userProfile?.name ?? 'User Name',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${_userProfile?.username ?? 'username'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (_isEditing)
                          TextField(
                            controller: _bioController,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Bio',
                              labelStyle: TextStyle(color: Colors.white70),
                              alignLabelWithHint: true,
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                          )
                        else
                          Text(
                            _userProfile?.bio?.isNotEmpty == true
                                ? _userProfile!.bio!
                                : 'No bio yet',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Stats row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('Posts', _postsCount),
                        Container(
                          height: 40,
                          width: 1,
                          color: Colors.grey.withOpacity(0.3),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/followers',
                                arguments: {'tabIndex': 0});
                          },
                          child: _buildStatColumn('Followers', _followersCount),
                        ),
                        Container(
                          height: 40,
                          width: 1,
                          color: Colors.grey.withOpacity(0.3),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/followers',
                                arguments: {'tabIndex': 1});
                          },
                          child: _buildStatColumn('Following', _followingCount),
                        ),
                      ],
                    ),
                  ),

                  // User posts
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Posts',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_userPosts.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.post_add,
                                    size: 60,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "You haven't posted anything yet",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _userPosts.length,
                            itemBuilder: (context, index) {
                              final post = _userPosts[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        post.content,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    if (post.imageUrl != null &&
                                        post.imageUrl!.isNotEmpty)
                                      Image.network(
                                        post.imageUrl!,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                          height: 100,
                                          color: Colors.grey[200],
                                          child: const Center(
                                              child: Icon(Icons.error)),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () async {
                                              bool? result =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title:
                                                      const Text('Delete Post'),
                                                  content: const Text(
                                                    'Are you sure you want to delete this post? This action cannot be undone.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(false),
                                                      child:
                                                          const Text('CANCEL'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(true),
                                                      child:
                                                          const Text('DELETE'),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (result == true) {
                                                try {
                                                  DialogUtils.showLoadingDialog(
                                                      context,
                                                      'Deleting post...');
                                                  await _dbService
                                                      .deletePost(post.id);
                                                  Navigator.pop(
                                                      context); // Dismiss loading dialog

                                                  setState(() {
                                                    _userPosts.removeAt(index);
                                                    _postsCount--;
                                                  });

                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                          'Post deleted successfully'),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                } catch (e) {
                                                  Navigator.pop(
                                                      context); // Dismiss loading dialog
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Failed to delete post: ${e.toString()}'),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            label: const Text('Delete',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
