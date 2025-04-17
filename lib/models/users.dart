import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String username;
  final String? bio;
  final String? profileImageUrl;
  final Map<String, dynamic>? preferences;
  final Timestamp? createdAt;
  final Timestamp? lastActive;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.username,
    this.bio,
    this.profileImageUrl,
    this.preferences,
    this.createdAt,
    this.lastActive,
  });

  // Factory constructor to create a UserProfile from Firestore document
  factory UserProfile.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      name: data['name'] ?? 'Unknown User',
      email: data['email'] ?? '',
      username: data['username'] ?? 'username',
      bio: data['bio'],
      profileImageUrl: data['profileImageUrl'],
      preferences: data['preferences'] as Map<String, dynamic>?,
      createdAt: data['createdAt'],
      lastActive: data['lastActive'],
    );
  }

  // Convert UserProfile to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'username': username,
      'bio': bio ?? '',
      'profileImageUrl': profileImageUrl,
      'preferences': preferences ?? {},
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'lastActive': lastActive ?? FieldValue.serverTimestamp(),
    };
  }
}
