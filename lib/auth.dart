import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myapp/HomePage.dart';
import 'package:myapp/LoginOrRegister.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the snapshot has user data, then they're already signed in
        if (snapshot.hasData && snapshot.data != null) {
          return const HomePage();
        }
        // Otherwise, they're not signed in - removed loading indicator
        else {
          return const LoginOrRegister();
        }
      },
    );
  }
}
