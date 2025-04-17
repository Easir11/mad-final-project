import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/database_service.dart';
import 'package:myapp/models/users.dart';
import 'package:myapp/utils/dialog_utils.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final DatabaseService _dbService = DatabaseService();
  List<UserProfile> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get blocked user IDs
      final blockedIds = await _dbService.getBlockedUsersList(user.uid);

      // Fetch profile info for each user
      List<UserProfile> blockedProfiles = [];
      for (var userId in blockedIds) {
        final profile = await _dbService.getUserFromFirebase(userId);
        if (profile != null) {
          blockedProfiles.add(profile);
        }
      }

      setState(() {
        _blockedUsers = blockedProfiles;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading blocked users: $e");
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load blocked users: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unblockUser(UserProfile user) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      DialogUtils.showLoadingDialog(context, 'Unblocking user...');

      await _dbService.unblockUser(currentUser.uid, user.uid);

      Navigator.pop(context); // Dismiss loading dialog

      setState(() {
        _blockedUsers.removeWhere((blockedUser) => blockedUser.uid == user.uid);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} has been unblocked'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the list after unblocking to show accurate state
      _loadBlockedUsers();
    } catch (e) {
      Navigator.pop(context); // Dismiss loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unblock user: ${e.toString()}'),
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
          'Blocked Users',
          style: TextStyle(color: colorScheme.onPrimary),
        ),
        backgroundColor: colorScheme.primary,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final blockedUser = _blockedUsers[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE0E0FF),
                        child: Icon(Icons.person, color: Color(0xFF6A5ACD)),
                      ),
                      title: Text(
                        blockedUser.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text('@${blockedUser.username}'),
                      trailing: ElevatedButton(
                        onPressed: () => _unblockUser(blockedUser),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black87,
                        ),
                        child: const Text('Unblock'),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              "You haven't blocked any users",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "When you block someone, they won't be able to interact with you or see your posts.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
